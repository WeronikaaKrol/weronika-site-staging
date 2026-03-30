param(
  [int]$Port = 8080,
  [string]$Root = $PSScriptRoot
)

$contentTypes = @{
  ".css"  = "text/css; charset=utf-8"
  ".gif"  = "image/gif"
  ".htm"  = "text/html; charset=utf-8"
  ".html" = "text/html; charset=utf-8"
  ".ico"  = "image/x-icon"
  ".jpeg" = "image/jpeg"
  ".jpg"  = "image/jpeg"
  ".js"   = "application/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".png"  = "image/png"
  ".svg"  = "image/svg+xml"
  ".txt"  = "text/plain; charset=utf-8"
}

function Get-ContentType {
  param([string]$Path)

  $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($contentTypes.ContainsKey($extension)) {
    return $contentTypes[$extension]
  }

  return "application/octet-stream"
}

function Resolve-RequestedPath {
  param(
    [string]$BasePath,
    [string]$RequestPath
  )

  $cleanPath = [Uri]::UnescapeDataString($RequestPath.Split("?")[0].TrimStart("/"))
  if ([string]::IsNullOrWhiteSpace($cleanPath)) {
    $cleanPath = "index.html"
  }

  $candidate = [System.IO.Path]::GetFullPath((Join-Path $BasePath $cleanPath))
  $resolvedBase = [System.IO.Path]::GetFullPath($BasePath)

  if (-not $candidate.StartsWith($resolvedBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }

  if ((Test-Path $candidate) -and (Get-Item $candidate).PSIsContainer) {
    $candidate = Join-Path $candidate "index.html"
  }

  return $candidate
}

$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Serving $Root at $prefix"

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response

    try {
      $requestedFile = Resolve-RequestedPath -BasePath $Root -RequestPath $context.Request.Url.AbsolutePath

      if (-not $requestedFile -or -not (Test-Path $requestedFile) -or (Get-Item $requestedFile).PSIsContainer) {
        $response.StatusCode = 404
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("404 - File not found")
        $response.ContentType = "text/plain; charset=utf-8"
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        continue
      }

      $bytes = [System.IO.File]::ReadAllBytes($requestedFile)
      $response.StatusCode = 200
      $response.ContentType = Get-ContentType -Path $requestedFile
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    catch {
      $response.StatusCode = 500
      $buffer = [System.Text.Encoding]::UTF8.GetBytes("500 - Internal server error")
      $response.ContentType = "text/plain; charset=utf-8"
      $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    finally {
      $response.OutputStream.Close()
      $response.Close()
    }
  }
}
finally {
  $listener.Stop()
  $listener.Close()
}
