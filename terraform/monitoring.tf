# Das Topic liegt in us-east-1, weil ein Alarm nur an ein Topic in seiner
# eigenen Region melden kann. Ohne eigenen KMS-Schlüssel, weil CloudWatch
# nicht an ein mit aws/sns verschlüsseltes Topic melden kann und ein eigener
# Schlüssel Geld kostet. Die Nachrichten enthalten keine vertraulichen Daten.
resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:CloudWatch kann nicht an ein mit aws/sns verschlüsseltes Topic melden, ein eigener Schlüssel kostet
  provider = aws.us_east_1

  name = "${var.project_name}-alerts"
}

# AWS schickt nach dem Anlegen eine Mail mit Bestätigungslink. Erst danach
# werden Alarme zugestellt.
resource "aws_sns_topic_subscription" "alerts_email" {
  provider = aws.us_east_1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  provider = aws.us_east_1

  alarm_name        = "${var.project_name}-cloudfront-5xx"
  alarm_description = "Mehr als ${var.error_rate_threshold} % der Anfragen an die Webseite enden mit einem Serverfehler."

  namespace   = "AWS/CloudFront"
  metric_name = "5xxErrorRate"
  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.error_rate_threshold

  # Ohne Aufrufe gibt es keine Datenpunkte, das ist kein Fehler.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Das Budget zählt nur Kosten mit dem Tag Project dieses Projekts, damit andere
# Projekte im selben Konto nicht mitgerechnet werden. Der Tag muss dafür in der
# Abrechnung einmalig als Kostenzuordnungs-Tag aktiviert sein.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = format("%.2f", var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Project$%s", var.project_name)]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
