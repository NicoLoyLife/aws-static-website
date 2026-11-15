resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-site"
  description                       = "Signierter Zugriff von CloudFront auf den privaten Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project_name}-security-headers"
  comment = "Sicherheits-Header für alle Antworten"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Die Seite lädt nur eigene Bilder, Stylesheets und Schriften, Skripte gibt es nicht.
    content_security_policy {
      content_security_policy = "default-src 'none'; font-src 'self'; img-src 'self'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
      override                = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  #checkov:skip=CKV_AWS_68:WAF kostet ab etwa 6 USD im Monat, mehr als die Hälfte des Budgets, und die Seite nimmt keine Eingaben an
  #checkov:skip=CKV2_AWS_47:Folgt aus CKV_AWS_68, ohne WAF keine WAF-Regeln
  #checkov:skip=CKV_AWS_86:Zugriffsprotokolle enthalten IP-Adressen und damit personenbezogene Daten, Fehlerraten überwacht der CloudWatch-Alarm
  #checkov:skip=CKV2_AWS_42:Ohne eigene Domain gibt es kein eigenes Zertifikat
  #checkov:skip=CKV_AWS_174:Mit dem Standardzertifikat lässt sich die TLS-Mindestversion nicht setzen, folgt aus CKV2_AWS_42
  #checkov:skip=CKV_AWS_310:Nur ein Ursprung, S3 ist regional hochverfügbar
  #checkov:skip=CKV_AWS_374:Kunden weltweit, eine Ländersperre wäre fachlich falsch
  enabled             = true
  comment             = "Webseite ${var.project_name}"
  default_root_object = "index.html"
  is_ipv6_enabled     = true
  http_version        = "http2and3"

  # Alle Edge-Standorte, weil ein Teil der Kundschaft in Nordamerika und Australien sitzt.
  price_class = "PriceClass_All"

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # Ohne Leserecht auf die Objektliste meldet S3 bei fehlenden Dateien 403 statt 404.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
