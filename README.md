# terraform-aws-parameter-upsert

Este módulo de Terraform permite crear o actualizar parámetros en AWS SSM Parameter Store de forma sencilla y multiplataforma.

## Uso básico

```hcl
module "parameter_upsert" {
  source     = "github.com/KaribuLab/terraform-aws-parameter-upsert"
  base_path  = "/app/infra"
  parameters = [
    {
      path        = "vpc_cidr"
      value       = "10.0.0.0/16"
      type        = "String"
      tier        = "Standard"
      description = "The subnet to use for the cluster"
    },
    {
      path        = "subnet_cidr"
      value       = "10.0.1.0/24"
      type        = "String"
      tier        = "Standard"
      description = "The subnet to use for the subnet"
    }
  ]
  binary_version = "v0.1.0"
}
```

## Variables de entrada

| Nombre                                  | Descripción                                             | Valor por defecto | Requerido |
| --------------------------------------- | ------------------------------------------------------- | ----------------- | --------- |
| base_path                               | Ruta base donde se almacenarán los parámetros en SSM    | ""                | Sí        |
| [parameters](#estructura-de-parameters) | Lista de objetos con los parámetros a crear/actualizar. | n/a               | Sí        |
| binary_version                          | Versión del binario a descargar para la provisión       | "v0.1.0"          | No        |

### Estructura de `parameters`

Cada elemento de la lista `parameters` debe tener la siguiente estructura:

| Nombre      | Descripción                                    | Requerido |
| ----------- | ---------------------------------------------- | --------- |
| path        | Nombre del parámetro (relativo a base_path)    | Sí        |
| value       | Valor del parámetro                            | Sí        |
| type        | Tipo de parámetro (String, SecureString, etc.) | Sí        |
| tier        | Tier del parámetro (Standard, Advanced)        | Sí        |
| description | Descripción del parámetro                      | No        |

## Ejemplo de ejecución

```bash
terraform init
terraform apply
```

## Licencia

Este proyecto está licenciado bajo los términos de la licencia Apache 2.0. Consulta el archivo LICENSE para más detalles. 