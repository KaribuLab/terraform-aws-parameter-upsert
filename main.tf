locals {
  version = var.binary_version
  json_input = jsonencode({
    base_path  = var.base_path
    parameters = var.parameters
  })

  # Solo elige que script de deteccion ejecutar (ruta con unidad C: vs Unix).
  root_path            = lower(abspath(path.root))
  use_windows_detector = length(regexall("^[a-z]:", local.root_path)) > 0
}

data "external" "os" {
  count = var.platform == "" ? 1 : 0

  program = local.use_windows_detector ? [
    "powershell",
    "-NoProfile",
    "-NonInteractive",
    "-File",
    "${path.module}/scripts/detect_os.ps1",
    ] : [
    "sh",
    "${path.module}/scripts/detect_os.sh",
  ]
}

locals {
  platform   = var.platform != "" ? var.platform : try(data.external.os[0].result.os, "linux")
  is_windows = local.platform == "windows"
  is_darwin  = local.platform == "darwin"
  is_linux   = local.platform == "linux"
}

resource "null_resource" "ssm_parameter_linux_amd64" {
  count = local.is_linux ? 1 : 0
  triggers = {
    json_input = local.json_input
    version    = local.version
  }

  # Descargar y extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "curl -L https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-linux-amd64.tar.gz -o ssm-parameter-linux-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ssm-parameter-linux-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = create
    command     = "mv ssm-parameter-linux-amd64 ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when    = create
    command = <<-EOF
cat <<FILE > input.json
${self.triggers.json_input}
FILE
EOF
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "./ssm-parameter -input-path input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción (binario según SO del host que ejecuta Terraform)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version} || scripts\\destroy.cmd ${self.triggers.version}"
    environment = {
      JSON_INPUT = self.triggers.json_input
    }
  }
}

resource "null_resource" "ssm_parameter_darwin_arm64" {
  count = local.is_darwin ? 1 : 0
  triggers = {
    json_input = local.json_input
    version    = local.version
  }

  # Descargar y extraer binario (CREATE)
  provisioner "local-exec" {
    when    = create
    command = "curl -L https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-darwin-arm64.tar.gz -o ssm-parameter-darwin-arm64-${self.triggers.version}.tar.gz"
  }
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ssm-parameter-darwin-arm64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = create
    command     = "mv ssm-parameter-darwin-arm64 ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when    = create
    command = <<-EOF
cat <<FILE > input.json
${self.triggers.json_input}
FILE
EOF
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "./ssm-parameter -input-path input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción (binario según SO del host que ejecuta Terraform)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version} || scripts\\destroy.cmd ${self.triggers.version}"
    environment = {
      JSON_INPUT = self.triggers.json_input
    }
  }
}

resource "null_resource" "ssm_parameter_windows_amd64" {
  count = local.is_windows ? 1 : 0
  triggers = {
    json_input = local.json_input
    version    = local.version
  }

  # Descargar y extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "wget https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-windows-amd64.zip -OutFile ssm-parameter-windows-amd64-${self.triggers.version}.zip"
    interpreter = ["PowerShell", "-Command"]
  }
  provisioner "local-exec" {
    when        = create
    command     = "Expand-Archive -Path ssm-parameter-windows-amd64-${self.triggers.version}.zip -DestinationPath . -Force"
    interpreter = ["PowerShell", "-Command"]
  }
  provisioner "local-exec" {
    when        = create
    command     = "Move-Item -Path ssm-parameter-windows-amd64.exe -Destination ssm-parameter.exe -Force"
    interpreter = ["PowerShell", "-Command"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = <<-EOF
$json = @"
${self.triggers.json_input}
"@
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("input.json", $json, $utf8NoBom)
EOF
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = ".\\ssm-parameter.exe -input-path input.json"
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar destrucción (binario según SO del host que ejecuta Terraform)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version} || scripts\\destroy.cmd ${self.triggers.version}"
    environment = {
      JSON_INPUT = self.triggers.json_input
    }
  }
}
