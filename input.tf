variable "binary_version" {
  type    = string
  default = "v0.5.6"
}

variable "platform" {
  type        = string
  default     = ""
  description = "Plataforma objetivo (linux, darwin, windows). Si es vacio, se detecta automaticamente en la maquina que ejecuta Terraform."

  validation {
    condition     = var.platform == "" || contains(["linux", "darwin", "windows"], var.platform)
    error_message = "platform debe ser linux, darwin o windows."
  }
}

variable "base_path" {
  type    = string
  default = "/app/infra"
}

variable "parameters" {
  type = list(object({
    path        = string
    value       = string
    type        = string
    tier        = string
    description = string
  }))
}
