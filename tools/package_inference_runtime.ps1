param(
  [string]$OutputDir = "build/windows/x64/runner/Release/inference_runtime"
)

$ErrorActionPreference = 'Stop'
$PythonVersion = '3.12.10'
$EmbedUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeSource = Join-Path $RepoRoot 'inference_runtime'
$Work = Join-Path $RepoRoot 'build/inference-runtime-staging'
$Zip = Join-Path $Work 'python-embed.zip'
$Runtime = Join-Path $Work 'runtime'
$ResolvedOutput = if ([IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $RepoRoot $OutputDir }

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
New-Item $Runtime -ItemType Directory -Force | Out-Null

Write-Host "Downloading Python $PythonVersion embeddable runtime..."
Invoke-WebRequest -Uri $EmbedUrl -OutFile $Zip
Expand-Archive -Path $Zip -DestinationPath $Runtime -Force

$SitePackages = Join-Path $Runtime 'Lib/site-packages'
New-Item $SitePackages -ItemType Directory -Force | Out-Null

Write-Host 'Installing pinned PyTorch / Ultralytics runtime...'
python -m pip install --upgrade pip
python -m pip install --only-binary=:all: --target $SitePackages -r (Join-Path $RuntimeSource 'requirements.lock')

Copy-Item (Join-Path $RuntimeSource 'chino_inference') (Join-Path $Runtime 'chino_inference') -Recurse -Force

$Pth = Join-Path $Runtime 'python312._pth'
$Lines = Get-Content $Pth | Where-Object { $_ -notmatch '^#?import site$' -and $_ -ne 'Lib/site-packages' }
$Lines += 'Lib/site-packages'
$Lines += 'import site'
Set-Content -Path $Pth -Value $Lines -Encoding ASCII

Write-Host 'Running embedded worker self-test...'
$PingInput = '{"protocol":1,"request_id":"self-test","action":"ping"}'
$PingOutput = $PingInput | & (Join-Path $Runtime 'python.exe') -m chino_inference
$Ping = $PingOutput | ConvertFrom-Json
if (-not $Ping.ok -or $Ping.request_id -ne 'self-test') {
  throw "Inference runtime self-test failed: $PingOutput"
}

Remove-Item $ResolvedOutput -Recurse -Force -ErrorAction SilentlyContinue
New-Item (Split-Path -Parent $ResolvedOutput) -ItemType Directory -Force | Out-Null
Copy-Item $Runtime $ResolvedOutput -Recurse -Force
Write-Host "Inference runtime packaged at $ResolvedOutput"
