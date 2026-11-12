variable "project_name" {
  description = "Kurzname des Projekts, Präfix für alle Ressourcennamen."
  type        = string
  default     = "cloud-programming"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "Nur Kleinbuchstaben, Ziffern und Bindestriche, 3 bis 30 Zeichen."
  }
}

variable "aws_region" {
  description = "Region für den Bucket mit den Inhalten der Webseite."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = startswith(var.aws_region, "eu-")
    error_message = "Die Daten sollen in der EU liegen, daher nur Regionen mit eu- erlaubt."
  }
}

variable "github_repository" {
  description = "GitHub-Repository im Format besitzer/name, aus dem bereitgestellt wird."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "Format besitzer/name, zum Beispiel NicoLoyLife/aws-static-website."
  }
}
