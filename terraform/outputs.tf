output "aws_account_id" {
  description = "Konto, in dem Terraform die Ressourcen anlegt."
  value       = data.aws_caller_identity.current.account_id
}

output "site_bucket_name" {
  description = "Privater Bucket mit den Dateien der Webseite."
  value       = aws_s3_bucket.site.id
}

output "cloudfront_distribution_id" {
  description = "ID der Distribution, gebraucht für Cache-Invalidierungen."
  value       = aws_cloudfront_distribution.site.id
}

output "website_url" {
  description = "Adresse, unter der die Webseite erreichbar ist."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}
