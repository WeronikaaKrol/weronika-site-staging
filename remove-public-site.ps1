$ErrorActionPreference = "Stop"

$runtimeRoot = Join-Path $PSScriptRoot ".runtime"
$deployResponsePath = Join-Path $runtimeRoot "pagedrop-deploy.json"
$deleteTokenPath = Join-Path $runtimeRoot "public-delete-token.txt"
$siteIdPath = Join-Path $runtimeRoot "public-site-id.txt"
$apiBaseUrl = "https://pagedrop.dev/api/v1/sites"

if (-not (Test-Path $siteIdPath) -or -not (Test-Path $deleteTokenPath)) {
  throw "No deployed public site details were found in .runtime."
}

$siteId = (Get-Content $siteIdPath | Select-Object -First 1).Trim()
$deleteToken = (Get-Content $deleteTokenPath | Select-Object -First 1).Trim()
Add-Type -AssemblyName System.Net.Http

$client = [System.Net.Http.HttpClient]::new()
$request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Delete, ("{0}/{1}" -f $apiBaseUrl, $siteId))
$request.Headers.Add("X-Delete-Token", $deleteToken)
$httpResponse = $client.SendAsync($request).Result
$responseJson = $httpResponse.Content.ReadAsStringAsync().Result

if (-not $httpResponse.IsSuccessStatusCode) {
  throw ("The hosting API returned HTTP {0} while deleting the site: {1}" -f [int]$httpResponse.StatusCode, $responseJson)
}

if ([string]::IsNullOrWhiteSpace($responseJson)) {
  throw "The hosting API returned an empty response while deleting the site."
}

$responseJson | Set-Content $deployResponsePath
Write-Output $responseJson
