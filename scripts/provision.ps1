param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("upsert", "delete")]
  [string]$Action,

  [Parameter(Mandatory = $true)]
  [string]$Version
)

$ErrorActionPreference = "Stop"

if (-not $env:JSON_INPUT) {
  throw "JSON_INPUT environment variable is required"
}

if ($env:OS -eq "Windows_NT") {
  $os = "windows"
} else {
  try {
    switch -Regex ((uname -s).Trim()) {
      "^Darwin$" { $os = "darwin" }
      "^Linux$" { $os = "linux" }
      default { $os = "linux" }
    }
  } catch {
    $os = "linux"
  }
}

$baseUrl = "https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/$Version"

switch ($os) {
  "windows" {
    $archive = "ssm-parameter-windows-amd64-$Version.zip"
    Invoke-WebRequest -Uri "$baseUrl/ssm-parameter-windows-amd64.zip" -OutFile $archive
    Expand-Archive -Path $archive -DestinationPath . -Force
    Move-Item -Path ssm-parameter-windows-amd64.exe -Destination ssm-parameter.exe -Force
    $bin = ".\ssm-parameter.exe"
  }
  "darwin" {
    $archive = "ssm-parameter-darwin-arm64-$Version.tar.gz"
    Invoke-WebRequest -Uri "$baseUrl/ssm-parameter-darwin-arm64.tar.gz" -OutFile $archive
    tar -xzf $archive
    Move-Item -Path ssm-parameter-darwin-arm64 -Destination ssm-parameter -Force
    $bin = ".\ssm-parameter"
  }
  default {
    $archive = "ssm-parameter-linux-amd64-$Version.tar.gz"
    Invoke-WebRequest -Uri "$baseUrl/ssm-parameter-linux-amd64.tar.gz" -OutFile $archive
    tar -xzf $archive
    Move-Item -Path ssm-parameter-linux-amd64 -Destination ssm-parameter -Force
    $bin = ".\ssm-parameter"
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("input.json", $env:JSON_INPUT, $utf8NoBom)

$args = @("-input-path", "input.json")
if ($Action -eq "delete") {
  $args += "-delete"
}

& $bin @args
