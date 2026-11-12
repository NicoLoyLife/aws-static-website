output "aws_account_id" {
  description = "Konto, in dem Terraform die Ressourcen anlegt."
  value       = data.aws_caller_identity.current.account_id
}
