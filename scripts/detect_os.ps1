$ErrorActionPreference = "Stop"

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

@{ os = $os } | ConvertTo-Json -Compress
