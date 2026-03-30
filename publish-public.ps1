param(
  [string]$ApiBaseUrl = "https://pagedrop.dev/api/v1/sites"
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$publicRoot = Join-Path $projectRoot "published"
$runtimeRoot = Join-Path $projectRoot ".runtime"
$zipPath = Join-Path $runtimeRoot "public-site.zip"
$deployResponsePath = Join-Path $runtimeRoot "pagedrop-deploy.json"
$publicUrlPath = Join-Path $runtimeRoot "public-url.txt"
$deleteTokenPath = Join-Path $runtimeRoot "public-delete-token.txt"
$siteIdPath = Join-Path $runtimeRoot "public-site-id.txt"

function Sync-PublicSite {
  if (Test-Path $publicRoot) {
    Remove-Item $publicRoot -Recurse -Force
  }

  New-Item -ItemType Directory -Force -Path (Join-Path $publicRoot "assets\\logos") | Out-Null

  Copy-Item (Join-Path $projectRoot "index.html") $publicRoot
  Copy-Item (Join-Path $projectRoot "styles.css") $publicRoot
  Copy-Item (Join-Path $projectRoot "script.js") $publicRoot
  Copy-Item (Join-Path $projectRoot "photo.jpg") $publicRoot
  Copy-Item (Join-Path $projectRoot "assets\\logos\\*.svg") (Join-Path $publicRoot "assets\\logos")
}

New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
Sync-PublicSite

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Compress-Archive -Path (Join-Path $publicRoot "*") -DestinationPath $zipPath -Force

Add-Type -AssemblyName System.Net.Http

$client = [System.Net.Http.HttpClient]::new()
$form = [System.Net.Http.MultipartFormDataContent]::new()
$fileBytes = [System.IO.File]::ReadAllBytes($zipPath)
$fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
$form.Add($fileContent, "file", [System.IO.Path]::GetFileName($zipPath))

$httpResponse = $client.PostAsync($ApiBaseUrl, $form).Result
$responseJson = $httpResponse.Content.ReadAsStringAsync().Result

if (-not $httpResponse.IsSuccessStatusCode) {
  throw ("The hosting API returned HTTP {0}: {1}" -f [int]$httpResponse.StatusCode, $responseJson)
}

if ([string]::IsNullOrWhiteSpace($responseJson)) {
  throw "The hosting API returned an empty response."
}

$responseJson | Set-Content $deployResponsePath
$response = $responseJson | ConvertFrom-Json

if ($response.status -ne "success" -or -not $response.data.url) {
  throw "The hosting API did not return a public URL."
}

$response.data.url | Set-Content $publicUrlPath
$response.data.deleteToken | Set-Content $deleteTokenPath
$response.data.siteId | Set-Content $siteIdPath

Write-Output $response.data.url
