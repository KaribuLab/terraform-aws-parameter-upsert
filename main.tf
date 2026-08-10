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
    bin_dir    = local.bin_dir_linux
  }

  # Crear subdir de trabajo aislado
  provisioner "local-exec" {
    when        = create
    command     = "mkdir -p ${self.triggers.bin_dir}"
    interpreter = ["/bin/sh", "-c"]
  }

  # Descargar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "curl -fsSL https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-linux-amd64.tar.gz -o ${self.triggers.bin_dir}/ssm-parameter-linux-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }

  # Extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ${self.triggers.bin_dir}/ssm-parameter-linux-amd64-${self.triggers.version}.tar.gz -C ${self.triggers.bin_dir}"
    interpreter = ["/bin/sh", "-c"]
  }

  # Renombrar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "mv -f ${self.triggers.bin_dir}/ssm-parameter-linux-amd64 ${self.triggers.bin_dir}/ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when    = create
    command = <<-EOF
cat <<FILE > ${self.triggers.bin_dir}/input.json
${self.triggers.json_input}
FILE
EOF
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "${self.triggers.bin_dir}/ssm-parameter -input-path ${self.triggers.bin_dir}/input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción (cross-platform via sh wrapper).
  # El wrapper detectara el SO del host y descargara el binario correspondiente
  # dentro de su propio bin_dir, evitando carreras con otras instancias.
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version} ${self.triggers.bin_dir}"
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
    bin_dir    = local.bin_dir_darwin
  }

  # Crear subdir de trabajo aislado
  provisioner "local-exec" {
    when    = create
    command = "mkdir -p ${self.triggers.bin_dir}"
  }

  # Descargar binario (CREATE)
  provisioner "local-exec" {
    when    = create
    command = "curl -fsSL https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-darwin-arm64.tar.gz -o ${self.triggers.bin_dir}/ssm-parameter-darwin-arm64-${self.triggers.version}.tar.gz"
  }

  # Extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ${self.triggers.bin_dir}/ssm-parameter-darwin-arm64-${self.triggers.version}.tar.gz -C ${self.triggers.bin_dir}"
    interpreter = ["/bin/sh", "-c"]
  }

  # Renombrar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "mv -f ${self.triggers.bin_dir}/ssm-parameter-darwin-arm64 ${self.triggers.bin_dir}/ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }

  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when    = create
    command = <<-EOF
cat <<FILE > ${self.triggers.bin_dir}/input.json
${self.triggers.json_input}
FILE
EOF
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "${self.triggers.bin_dir}/ssm-parameter -input-path ${self.triggers.bin_dir}/input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción (cross-platform via sh wrapper)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version} ${self.triggers.bin_dir}"
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
    bin_dir    = local.bin_dir_windows
  }

  # Crear subdir de trabajo aislado (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "New-Item -ItemType Directory -Force -Path ${self.triggers.bin_dir} | Out-Null"
    interpreter = ["PowerShell", "-Command"]
  }

  # Descargar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "Invoke-WebRequest -Uri https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-windows-amd64.zip -OutFile ${self.triggers.bin_dir}\\ssm-parameter-windows-amd64-${self.triggers.version}.zip -UseBasicParsing -Headers @{ 'User-Agent' = 'terraform-aws-parameter-upsert' }"
    interpreter = ["PowerShell", "-Command"]
  }

  # Extraer binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "Expand-Archive -Path ${self.triggers.bin_dir}\\ssm-parameter-windows-amd64-${self.triggers.version}.zip -DestinationPath ${self.triggers.bin_dir} -Force"
    interpreter = ["PowerShell", "-Command"]
  }

  # Renombrar binario (CREATE)
  provisioner "local-exec" {
    when        = create
    command     = "Move-Item -Path ${self.triggers.bin_dir}\\ssm-parameter-windows-amd64.exe -Destination ${self.triggers.bin_dir}\\ssm-parameter.exe -Force"
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
[System.IO.File]::WriteAllText("${self.triggers.bin_dir}\input.json", $json, $utf8NoBom)
EOF
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "& '${self.triggers.bin_dir}\\ssm-parameter.exe' -input-path '${self.triggers.bin_dir}\\input.json'"
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar destrucción (cross-platform via sh wrapper)
  provisioner "local-exec" {
    when    = destroy
    command = "sh scripts/provision.sh delete ${self.triggers.version} ${self.triggers.bin_dir}"
    environment = {
      JSON_INPUT = self.triggers.json_input
    }
  }
}