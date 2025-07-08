locals {
  version    = var.binary_version
  is_windows = length(regexall("^[a-z]:", lower(abspath(path.root)))) > 0
  is_darwin  = length(regexall("^/users", lower(abspath(path.root)))) > 0
  is_linux   = !local.is_windows && !local.is_darwin
  json_input = jsonencode({
    base_path  = var.base_path
    parameters = var.parameters
  })
}

resource "null_resource" "ssm_parameter_linux_amd64" {
  count = local.is_linux ? 1 : 0
  triggers = {
    md5     = md5(local.json_input)
    version = local.version
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
  
  # Descargar y extraer binario (DESTROY) - para pipelines CI/CD
  provisioner "local-exec" {
    when        = destroy
    command     = "curl -L https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-linux-amd64.tar.gz -o ssm-parameter-linux-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "tar -xzf ssm-parameter-linux-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "mv ssm-parameter-linux-amd64 ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }
  
  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when = create
    command = <<EOF
    cat <<FILE > input.json
    ${local.json_input}
    EOF
  }
  
  # Crear archivo de entrada (DESTROY)
  provisioner "local-exec" {
    when = destroy
    command = <<EOF
    cat <<FILE > input.json
    ${local.json_input}
    EOF
  }
  
  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "./ssm-parameter -input-path input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción
  provisioner "local-exec" {
    when        = destroy
    command     = "./ssm-parameter -input-path input.json -delete"
    interpreter = ["/bin/sh", "-c"]
  }
}

resource "null_resource" "ssm_parameter_darwin_amd64" {
  count = local.is_darwin ? 1 : 0
  triggers = {
    md5     = md5(local.json_input)
    version = local.version
  }
  
  # Descargar y extraer binario (CREATE)
  provisioner "local-exec" {
    when = create
    command = "curl -L https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-darwin-amd64.tar.gz -o ssm-parameter-darwin-amd64-${self.triggers.version}.tar.gz"
  }
  provisioner "local-exec" {
    when        = create
    command     = "tar -xzf ssm-parameter-darwin-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = create
    command     = "mv ssm-parameter-darwin-amd64 ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }
  
  # Descargar y extraer binario (DESTROY) - para pipelines CI/CD
  provisioner "local-exec" {
    when = destroy
    command = "curl -L https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-darwin-amd64.tar.gz -o ssm-parameter-darwin-amd64-${self.triggers.version}.tar.gz"
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "tar -xzf ssm-parameter-darwin-amd64-${self.triggers.version}.tar.gz"
    interpreter = ["/bin/sh", "-c"]
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "mv ssm-parameter-darwin-amd64 ssm-parameter"
    interpreter = ["/bin/sh", "-c"]
  }
  
  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when = create
    command = <<EOF
    cat <<FILE > input.json
    ${local.json_input}
    EOF
  }
  
  # Crear archivo de entrada (DESTROY)
  provisioner "local-exec" {
    when = destroy
    command = <<EOF
    cat <<FILE > input.json
    ${local.json_input}
    EOF
  }
  
  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "./ssm-parameter -input-path input.json"
    interpreter = ["/bin/sh", "-c"]
  }

  # Ejecutar destrucción
  provisioner "local-exec" {
    when        = destroy
    command     = "./ssm-parameter -input-path input.json -delete"
    interpreter = ["/bin/sh", "-c"]
  }
}

resource "null_resource" "ssm_parameter_windows_amd64" {
  count = local.is_windows ? 1 : 0
  triggers = {
    md5     = md5(local.json_input)
    version = local.version
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
    command     = "Move-Item -Path ssm-parameter-windows-amd64.exe -Destination ssm-parameter.exe"
    interpreter = ["PowerShell", "-Command"]
  }
  
  # Descargar y extraer binario (DESTROY) - para pipelines CI/CD
  provisioner "local-exec" {
    when        = destroy
    command     = "wget https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${self.triggers.version}/ssm-parameter-windows-amd64.zip -OutFile ssm-parameter-windows-amd64-${self.triggers.version}.zip"
    interpreter = ["PowerShell", "-Command"]
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "Expand-Archive -Path ssm-parameter-windows-amd64-${self.triggers.version}.zip -DestinationPath . -Force"
    interpreter = ["PowerShell", "-Command"]
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "Move-Item -Path ssm-parameter-windows-amd64.exe -Destination ssm-parameter.exe"
    interpreter = ["PowerShell", "-Command"]
  }
  
  # Crear archivo de entrada (CREATE)
  provisioner "local-exec" {
    when = create
    command = <<EOF
    @"
    ${local.json_input}
    "@ | Out-File -FilePath "input.json" -Encoding utf8
    EOF
    interpreter = ["PowerShell", "-Command"]
  }
  
  # Crear archivo de entrada (DESTROY)
  provisioner "local-exec" {
    when = destroy
    command = <<EOF
    @"
    ${local.json_input}
    "@ | Out-File -FilePath "input.json" -Encoding utf8
    EOF
    interpreter = ["PowerShell", "-Command"]
  }
  
  # Ejecutar creación
  provisioner "local-exec" {
    when        = create
    command     = "ssm-parameter -input-path input.json"
    interpreter = ["PowerShell", "-Command"]
  }

  # Ejecutar destrucción
  provisioner "local-exec" {
    when        = destroy
    command     = "ssm-parameter -input-path input.json -delete"
    interpreter = ["PowerShell", "-Command"]
  }
}