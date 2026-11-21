function Get-SqlCockpitHttpClient {
    <#
    .SYNOPSIS
    One HttpClient per session. Redirects are never followed and cookies are not kept.
    #>
    [CmdletBinding()]
    [OutputType([System.Net.Http.HttpClient])]
    param()

    if (-not $script:HttpClient) {
        if ($PSVersionTable.PSEdition -ne 'Core') {
            # .NET Framework: make sure TLS 1.2 is on unless the OS default is in use.
            $protocols = [System.Net.ServicePointManager]::SecurityProtocol
            $tls12 = [System.Net.SecurityProtocolType]::Tls12
            if ([int] $protocols -ne 0 -and -not ($protocols -band $tls12)) {
                [System.Net.ServicePointManager]::SecurityProtocol = $protocols -bor $tls12
            }
        }
        $handler = New-Object -TypeName System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $handler.UseCookies = $false
        $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        $client = New-Object -TypeName System.Net.Http.HttpClient -ArgumentList $handler
        $client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
        $script:HttpClient = $client
    }
    $script:HttpClient
}

function Wait-SqlCockpitTask {
    <#
    .SYNOPSIS
    Waits for a task in short steps so Ctrl+C works, and enforces the deadline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Threading.Tasks.Task] $Task,

        [Parameter(Mandatory)]
        [System.Diagnostics.Stopwatch] $Stopwatch,

        [Parameter(Mandatory)]
        [int] $TimeoutSec,

        [Parameter(Mandatory)]
        [System.Threading.CancellationTokenSource] $Cancellation
    )

    while (-not $Task.Wait(200)) {
        if ($Stopwatch.Elapsed.TotalSeconds -ge $TimeoutSec) {
            $Cancellation.Cancel()
            throw (Get-SqlCockpitErrorRecord -Code 'timeout' -Message "The SQL Cockpit portal did not answer within $TimeoutSec seconds.")
        }
    }
    $Task.Result
}

function Send-SqlCockpitHttpRequest {
    <#
    .SYNOPSIS
    Sends one HTTP request. The only place the plain API key exists.
    .DESCRIPTION
    Returns StatusCode, Headers (lower-case names), Content and ContentTooLarge. Reads at most
    MaxBytes of the body. Never follows redirects. Any copy of the key in the body is replaced
    with [redacted] before it leaves this function. Tests mock this function.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Uri,

        [Parameter(Mandatory)]
        [securestring] $ApiKey,

        [string] $Body,

        [Parameter(Mandatory)]
        [string] $UserAgent,

        [int] $TimeoutSec = 20,

        [long] $MaxBytes = 2MB
    )

    $client = Get-SqlCockpitHttpClient
    $request = New-Object -TypeName System.Net.Http.HttpRequestMessage -ArgumentList ([System.Net.Http.HttpMethod]::new($Method)), ([uri] $Uri)
    $null = $request.Headers.TryAddWithoutValidation('Accept', 'application/json')
    $null = $request.Headers.TryAddWithoutValidation('User-Agent', $UserAgent)
    if ($PSBoundParameters.ContainsKey('Body')) {
        $request.Content = New-Object -TypeName System.Net.Http.StringContent -ArgumentList $Body, ([System.Text.UTF8Encoding]::new($false)), 'application/json'
    }

    $cancellation = New-Object -TypeName System.Threading.CancellationTokenSource
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $bstr = [IntPtr]::Zero
    $plain = $null
    $response = $null
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim()
        if ($plain -notmatch '^[\x21-\x7E]{20,200}\z') {
            throw (Get-SqlCockpitErrorRecord -Code 'invalid_key' -Message 'The API key does not look like a SQL Cockpit portal API key.')
        }
        $null = $request.Headers.TryAddWithoutValidation('Authorization', 'Bearer ' + $plain)

        try {
            $sendTask = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancellation.Token)
            $response = Wait-SqlCockpitTask -Task $sendTask -Stopwatch $stopwatch -TimeoutSec $TimeoutSec -Cancellation $cancellation

            $status = [int] $response.StatusCode
            $headers = @{}
            foreach ($header in $response.Headers) { $headers[$header.Key.ToLowerInvariant()] = ($header.Value -join ', ') }
            foreach ($header in $response.Content.Headers) { $headers[$header.Key.ToLowerInvariant()] = ($header.Value -join ', ') }

            if ($status -ge 300 -and $status -lt 400) {
                return [pscustomobject]@{ StatusCode = $status; Headers = $headers; Content = ''; ContentTooLarge = $false }
            }
            $declared = $response.Content.Headers.ContentLength
            if ($null -ne $declared -and $declared -gt $MaxBytes) {
                return [pscustomobject]@{ StatusCode = $status; Headers = $headers; Content = ''; ContentTooLarge = $true }
            }

            $streamTask = $response.Content.ReadAsStreamAsync()
            $stream = Wait-SqlCockpitTask -Task $streamTask -Stopwatch $stopwatch -TimeoutSec $TimeoutSec -Cancellation $cancellation
            $memory = New-Object -TypeName System.IO.MemoryStream
            $buffer = New-Object -TypeName byte[] -ArgumentList 65536
            $tooLarge = $false
            while ($true) {
                $readTask = $stream.ReadAsync($buffer, 0, $buffer.Length, $cancellation.Token)
                $read = Wait-SqlCockpitTask -Task $readTask -Stopwatch $stopwatch -TimeoutSec $TimeoutSec -Cancellation $cancellation
                if ($read -le 0) { break }
                if ($memory.Length + $read -gt $MaxBytes) {
                    $tooLarge = $true
                    break
                }
                $memory.Write($buffer, 0, $read)
            }
            $content = ''
            if (-not $tooLarge) {
                $content = [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
                if ($content.Contains($plain)) { $content = $content.Replace($plain, '[redacted]') }
            }
            [pscustomobject]@{ StatusCode = $status; Headers = $headers; Content = $content; ContentTooLarge = $tooLarge }
        }
        catch {
            if ($_.Exception -is [SqlCockpit.Portal.PortalException]) { throw }
            if ($_.Exception -is [System.Management.Automation.PipelineStoppedException]) { throw }
            $inner = $_.Exception
            while ($inner.InnerException) { $inner = $inner.InnerException }
            if ($inner -is [System.OperationCanceledException] -or $inner -is [System.TimeoutException]) {
                throw (Get-SqlCockpitErrorRecord -Code 'timeout' -Message "The SQL Cockpit portal did not answer within $TimeoutSec seconds.")
            }
            $detail = $inner.Message
            if ($plain -and $detail -and $detail.Contains($plain)) { $detail = $detail.Replace($plain, '[redacted]') }
            throw (Get-SqlCockpitErrorRecord -Code 'connection_error' `
                    -Message "Could not reach the SQL Cockpit portal at $(([uri] $Uri).GetLeftPart([UriPartial]::Authority)). Check the portal URL and your connection. ($detail)")
        }
    }
    finally {
        $plain = $null
        if ($bstr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        if ($response) { $response.Dispose() }
        $request.Dispose()
        $cancellation.Dispose()
    }
}

function ConvertFrom-SqlCockpitRetryAfter {
    <#
    .SYNOPSIS
    Retry-After as whole seconds: a number of seconds or an HTTP date.
    #>
    [CmdletBinding()]
    [OutputType([Nullable[int]])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^\d{1,9}\z') { return [int] $trimmed }
    $date = [DateTimeOffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([DateTimeOffset]::TryParseExact($trimmed, 'r', $culture, $styles, [ref] $date) -or
        [DateTimeOffset]::TryParse($trimmed, $culture, $styles, [ref] $date)) {
        $seconds = [Math]::Ceiling(($date - [DateTimeOffset]::UtcNow).TotalSeconds)
        return [int] [Math]::Max(0, [Math]::Min($seconds, 999999999))
    }
    $null
}

function Get-SqlCockpitRetryDelay {
    <#
    .SYNOPSIS
    Milliseconds to wait before retry number Attempt+1. Retry-After wins, capped at 30 seconds.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [int] $Attempt,

        [Nullable[int]] $RetryAfter
    )

    if ($null -ne $RetryAfter) {
        return [int] [Math]::Min([long] $RetryAfter * 1000, $script:MaxRetryDelayMs)
    }
    $backoff = 500 * [Math]::Pow(2, $Attempt) + (Get-Random -Minimum 0 -Maximum 250)
    [int] [Math]::Min($backoff, $script:MaxRetryDelayMs)
}

function Get-SqlCockpitResponseResult {
    <#
    .SYNOPSIS
    Turns a response into @{ Data } or @{ Error = <ErrorRecord> }.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Response,

        [string] $Target
    )

    $status = [int] $Response.StatusCode
    if ($status -ge 300 -and $status -lt 400) {
        return @{ Error = (Get-SqlCockpitErrorRecord -Code 'unexpected_redirect' -StatusCode $status -TargetObject $Target `
                    -Message "The portal answered with a redirect (HTTP $status), which SqlCockpit.Portal does not follow. Check the portal URL.") }
    }

    $content = [string] $Response.Content
    if ($Response.ContentTooLarge -or [System.Text.Encoding]::UTF8.GetByteCount($content) -gt $script:MaxResponseBytes) {
        return @{ Error = (Get-SqlCockpitErrorRecord -Code 'response_too_large' -StatusCode $status -TargetObject $Target `
                    -Message 'The portal response was larger than 2 MiB and was not read.') }
    }

    $payload = $null
    $parsed = $false
    if (-not [string]::IsNullOrWhiteSpace($content)) {
        try {
            $payload = ConvertFrom-Json -InputObject $content -ErrorAction Stop
            $parsed = $payload -is [System.Management.Automation.PSCustomObject]
        }
        catch {
            $parsed = $false
        }
    }

    $success = $status -ge 200 -and $status -lt 300
    if ($success -and $parsed -and $payload.ok -eq $true) {
        return @{ Data = $payload.data }
    }
    if ($success) {
        return @{ Error = (Get-SqlCockpitErrorRecord -Code 'invalid_response' -StatusCode $status -TargetObject $Target `
                    -Message "The portal returned an unexpected response (HTTP $status).") }
    }

    $apiError = $null
    if ($parsed -and $payload.error -is [System.Management.Automation.PSCustomObject]) { $apiError = $payload.error }

    $code = $null
    if ($apiError -and $apiError.code -is [string] -and $apiError.code -match '^[a-z0-9_]{1,64}\z') { $code = $apiError.code }
    if (-not $code) {
        $code = switch ($status) {
            400 { 'bad_request' }
            401 { 'unauthenticated' }
            403 { 'forbidden' }
            404 { 'not_found' }
            405 { 'method_not_allowed' }
            413 { 'payload_too_large' }
            422 { 'validation_failed' }
            429 { 'rate_limited' }
            default { if ($status -ge 500) { 'server_error' } else { 'invalid_response' } }
        }
    }

    $message = "The portal request failed (HTTP $status)."
    if ($apiError -and $apiError.message -is [string] -and $apiError.message.Trim()) { $message = $apiError.message.Trim() }

    $fields = $null
    if ($apiError -and $apiError.fields -is [System.Management.Automation.PSCustomObject]) {
        $fields = [ordered]@{}
        $parts = @()
        foreach ($property in $apiError.fields.PSObject.Properties) {
            $messages = [string[]] @($property.Value | Where-Object { $_ -is [string] })
            $fields[$property.Name] = $messages
            $parts += '{0}: {1}' -f $property.Name, ($messages -join ' ')
        }
        if ($parts.Count -gt 0) { $message = '{0} {1}' -f $message.TrimEnd(), ($parts -join '; ') }
    }

    $retryAfter = $null
    if ($status -eq 429) {
        $retryAfter = ConvertFrom-SqlCockpitRetryAfter -Value $Response.Headers['retry-after']
        if ($retryAfter -eq 1) { $message = "$message Try again in 1 second." }
        elseif ($retryAfter -gt 1) { $message = "$message Try again in $retryAfter seconds." }
    }

    @{ Error = (Get-SqlCockpitErrorRecord -Message $message -Code $code -StatusCode $status -Fields $fields -RetryAfter $retryAfter -TargetObject $Target) }
}

function Invoke-SqlCockpitRequest {
    <#
    .SYNOPSIS
    Calls the portal API and returns the unwrapped data. Retries GET on 429 and 5xx (at most twice).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Path,

        [System.Collections.IDictionary] $Query,

        [System.Collections.IDictionary] $Body,

        [object] $Connection
    )

    if ($Path -notmatch '^/[a-z0-9/_-]*\z') {
        throw (Get-SqlCockpitErrorRecord -Code 'invalid_argument' -Message 'Refusing to call an unexpected portal path.')
    }
    if (-not $Connection) { $Connection = Resolve-SqlCockpitConnection }

    try {
        $uri = $Connection.PortalUrl + $script:ApiPrefix + $Path
        if ($Query) {
            $pairs = foreach ($name in $Query.Keys) {
                $value = $Query[$name]
                if ($null -ne $value -and "$value" -ne '') {
                    '{0}={1}' -f [uri]::EscapeDataString([string] $name), [uri]::EscapeDataString([string] $value)
                }
            }
            if ($pairs) { $uri = $uri + '?' + ($pairs -join '&') }
        }

        $sendParameters = @{
            Method     = $Method
            Uri        = $uri
            ApiKey     = $Connection.ApiKey
            UserAgent  = $script:UserAgent
            TimeoutSec = $script:TimeoutSec
            MaxBytes   = $script:MaxResponseBytes
        }
        if ($PSBoundParameters.ContainsKey('Body')) {
            $sendParameters.Body = ConvertTo-Json -InputObject $Body -Depth 5 -Compress
        }

        $target = "$Method $Path"
        $retries = 0
        if ($Method -eq 'GET') { $retries = $script:MaxRetries }

        for ($attempt = 0; ; $attempt++) {
            Write-Verbose -Message "$Method $uri"
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Send-SqlCockpitHttpRequest @sendParameters
            Write-Verbose -Message ('HTTP {0} {1} {2} ({3} ms)' -f $response.StatusCode, $Method, $uri, $stopwatch.ElapsedMilliseconds)

            $result = Get-SqlCockpitResponseResult -Response $response -Target $target
            if (-not $result.ContainsKey('Error')) { return $result.Data }

            $status = [int] $response.StatusCode
            $retryable = $status -eq 429 -or $status -ge 500
            if (-not $retryable -or $attempt -ge $retries) { throw $result.Error }

            $delay = Get-SqlCockpitRetryDelay -Attempt $attempt -RetryAfter $result.Error.Exception.RetryAfter
            Write-Verbose -Message ('HTTP {0}: retrying in {1} ms (retry {2} of {3}).' -f $status, $delay, ($attempt + 1), $retries)
            Start-Sleep -Milliseconds $delay
        }
    }
    finally {
        if ($Connection.Transient) { $Connection.ApiKey.Dispose() }
    }
}
