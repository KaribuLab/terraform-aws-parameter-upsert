variable "binary_version" {
  type    = string
  default = "v0.3.1"
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
