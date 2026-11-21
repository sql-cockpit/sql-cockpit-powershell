# A tiny HTTP server on 127.0.0.1 for the transport tests. Runs in a background runspace.
# Routes are keyed 'METHOD /path' and hold Status, Body, Headers, and optionally
# BodyBytes (a byte count of filler to send), Chunked and EchoAuth.

function Start-TestServer {
    [CmdletBinding()]
    param()

    $probe = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), 0
    $probe.Start()
    $port = $probe.LocalEndpoint.Port
    $probe.Stop()

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://127.0.0.1:$port/")
    $listener.Start()

    $state = [hashtable]::Synchronized(@{
            Routes   = [hashtable]::Synchronized(@{})
            Requests = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        })

    $serverScript = {
        param($listener, $state)
        while ($listener.IsListening) {
            try { $context = $listener.GetContext() } catch { break }
            try {
                $request = $context.Request
                $body = ''
                if ($request.HasEntityBody) {
                    $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
                    $body = $reader.ReadToEnd()
                }
                $null = $state.Requests.Add([pscustomobject]@{
                        Method        = $request.HttpMethod
                        Path          = $request.Url.AbsolutePath
                        Query         = $request.Url.Query
                        Authorization = $request.Headers['Authorization']
                        UserAgent     = $request.Headers['User-Agent']
                        Accept        = $request.Headers['Accept']
                        ContentType   = $request.Headers['Content-Type']
                        Body          = $body
                    })
                $route = $state.Routes[$request.HttpMethod + ' ' + $request.Url.AbsolutePath]
                if (-not $route) {
                    $route = @{ Status = 404; Body = '{"ok":false,"error":{"code":"not_found","message":"No such route."}}' }
                }
                $response = $context.Response
                $response.StatusCode = $route.Status
                $response.ContentType = 'application/json'
                if ($route.Headers) {
                    foreach ($name in $route.Headers.Keys) { $response.Headers[$name] = $route.Headers[$name] }
                }
                if ($route.BodyBytes) {
                    $bytes = New-Object byte[] $route.BodyBytes
                    for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = 32 }
                }
                else {
                    $text = [string] $route.Body
                    if ($route.EchoAuth) { $text = $text.Replace('{{auth}}', [string] $request.Headers['Authorization']) }
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
                }
                if ($route.Chunked) { $response.SendChunked = $true } else { $response.ContentLength64 = $bytes.Length }
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.OutputStream.Close()
            }
            catch {
                $null = $_
            }
            finally {
                try { $context.Response.Close() } catch { $null = $_ }
            }
        }
    }

    $powershell = [powershell]::Create()
    $null = $powershell.AddScript($serverScript.ToString()).AddArgument($listener).AddArgument($state)
    $handle = $powershell.BeginInvoke()

    [pscustomobject]@{
        Url        = "http://127.0.0.1:$port"
        Port       = $port
        Listener   = $listener
        State      = $state
        Routes     = $state.Routes
        Requests   = $state.Requests
        PowerShell = $powershell
        Handle     = $handle
    }
}

function Stop-TestServer {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Server)

    try { $Server.Listener.Stop() } catch { $null = $_ }
    try { $Server.Listener.Close() } catch { $null = $_ }
    try { $null = $Server.PowerShell.EndInvoke($Server.Handle) } catch { $null = $_ }
    $Server.PowerShell.Dispose()
}
