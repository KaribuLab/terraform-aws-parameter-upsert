locals {
  version = var.binary_version
  json_input = jsonencode({
    base_path  = var.base_path
    parameters = var.parameters
  })

  # Solo elige que script de deteccion ejecutar (ruta con unidad C: vs Unix).
  root_path            = lower(abspath(path.root))
  use_windows_detector = length(regexall("^[a-z]:", local.root_path)) > 0

  # Subdirectorios de trabajo unicos por (recurso, version). Cada null_resource
  # descarga y ejecuta su binario dentro de su propio bin_dir, lo que elimina la
  # carrera cuando hay multiples instancias del modulo o cuando varios
  # workspaces corren en paralelo sobre la misma raiz de Terraform.
  bin_dir_linux   = "bin/${local.version}/ssm_parameter_linux_amd64"
  bin_dir_darwin  = "bin/${local.version}/ssm_parameter_darwin_arm64"
  bin_dir_windows = "bin/${local.version}/ssm_parameter_windows_amd64"
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

  # Crear subdir de trabajo aislado
  provisioner "local-exec" {
    when        = create
    command     = "mkdir -p ${local.bin_dir_linux}"
    interpreter = ["/bin/sh", "-c"]
  }

  # Descargar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "curl -fsSL https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${local.version}/ssm-parameter-linux-amd64.tar.gz -o ${local.bin_dir_linux}/ssm-parameter-linux-amd64-${local.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }

  # Extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ${local.bin_dir_linux}/ssm-parameter-linux-amd64-${local.version}.tar.gz -C ${local.bin_dir_linux}"
    interpreter = ["/bin/sh", "-c"]
  }

  # Renombrar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "mv -f ${local.bin_dir_linux}/ssm-parameter-linux-amd64 ${local.bin_dir_linux}/ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when    = create
    command = <<-EOF
cat <<FILE > ${local.bin_dir_linux}/input.json
${self.triggers.json_input}
FILE
EOF
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "${local.bin_dir_linux}/ssm-parameter -input-path ${local.bin_dir_linux}/input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción (cross-platform via sh wrapper).
  # El wrapper detectara el SO del host y descargara el binario correspondiente
  # dentro de su propio bin_dir (mismo path que uso CREATE), evitando carreras
  # con otras instancias. NO pasamos bin_dir desde Terraform: local.* no es
  # valido en destroy provisioners, asi que provision.sh lo deriva de la version
  # y el SO detectado.
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version}"
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

  # Crear subdir de trabajo aislado
  provisioner "local-exec" {
    when    = create
    command = "mkdir -p ${local.bin_dir_darwin}"
  }

  # Descargar binario (CREATE)
  provisioner "local-exec" {
    when    = create
    command = "curl -fsSL https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${local.version}/ssm-parameter-darwin-arm64.tar.gz -o ${local.bin_dir_darwin}/ssm-parameter-darwin-arm64-${local.version}.tar.gz"
  }

  # Extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ${local.bin_dir_darwin}/ssm-parameter-darwin-arm64-${local.version}.tar.gz -C ${local.bin_dir_darwin}"
    interpreter = ["/bin/sh", "-c"]
  }

  # Renombrar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "mv -f ${local.bin_dir_darwin}/ssm-parameter-darwin-arm64 ${local.bin_dir_darwin}/ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when    = create
    command = <<-EOF
cat <<FILE > ${local.bin_dir_darwin}/input.json
${self.triggers.json_input}
FILE
EOF
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "${local.bin_dir_darwin}/ssm-parameter -input-path ${local.bin_dir_darwin}/input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción (cross-platform via sh wrapper)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version}"
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

  # Crear subdir de trabajo aislado (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "New-Item -ItemType Directory -Force -Path ${local.bin_dir_windows} | Out-Null"
    interpreter = ["PowerShell", "-Command"]
  }

  # Descargar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "Invoke-WebRequest -Uri https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${local.version}/ssm-parameter-windows-amd64.zip -OutFile ${local.bin_dir_windows}\\ssm-parameter-windows-amd64-${local.version}.zip -UseBasicParsing -Headers @{ 'User-Agent' = 'terraform-aws-parameter-upsert' }"
    interpreter = ["PowerShell", "-Command"]
  }

  # Extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "Expand-Archive -Path ${local.bin_dir_windows}\\ssm-parameter-windows-amd64-${local.version}.zip -DestinationPath ${local.bin_dir_windows} -Force"
    interpreter = ["PowerShell", "-Command"]
  }

  # Renombrar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "Move-Item -Path ${local.bin_dir_windows}\\ssm-parameter-windows-amd64.exe -Destination ${local.bin_dir_windows}\\ssm-parameter.exe -Force"
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
[System.IO.File]::WriteAllText("${local.bin_dir_windows}\input.json", $json, $utf8NoBom)
EOF
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "& '${local.bin_dir_windows}\\ssm-parameter.exe' -input-path '${local.bin_dir_windows}\\input.json'"
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar destrucción (cross-platform via sh wrapper)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version}"
    environment = {
      JSON_INPUT = self.triggers.json_input
    }
  }
}