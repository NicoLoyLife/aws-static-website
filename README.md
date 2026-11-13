# Statische Webseite auf AWS

Dieses Repository stellt eine einfache Unternehmenswebseite hochverfügbar und weltweit schnell auf Amazon Web Services bereit. Die Infrastruktur wird vollständig mit Terraform beschrieben und lässt sich damit jederzeit reproduzieren. Das Projekt entsteht als Portfolio im Kurs Cloud Programming an der IU Internationale Hochschule.

Die Seite liegt in einem privaten S3-Bucket und wird über das Content Delivery Network CloudFront ausgeliefert.

## Projektstruktur

```
site/        Inhalt der Webseite
terraform/   Infrastruktur als Code
```

## Voraussetzungen

- Terraform ab Version 1.11
- AWS CLI v2 mit einem Profil, das Rechte für S3, CloudFront, CloudWatch, SNS und AWS Budgets hat, dazu IAM-Rechte für Rollen mit dem Präfix `cloud-programming-` und für den OIDC-Provider von GitHub
- GitHub CLI (`gh`) für die Repository-Variablen und IDs
- Ein AWS-Konto, die Beispiele nutzen das Profil `cloud-programming`

## Einrichtung

### 1. Bucket für den Terraform-State anlegen

Der State liegt verschlüsselt und versioniert in einem eigenen S3-Bucket. Terraform kann diesen Bucket nicht selbst anlegen, weil es ihn schon beim Start braucht. Er entsteht deshalb einmalig über die AWS CLI. Der Name enthält die Konto-ID, damit er weltweit eindeutig ist.

```bash
export AWS_PROFILE=cloud-programming AWS_REGION=eu-central-1
BUCKET=cloud-programming-tfstate-$(aws sts get-caller-identity --query Account --output text)

aws s3api create-bucket --bucket $BUCKET --create-bucket-configuration LocationConstraint=eu-central-1
aws s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-tagging --bucket $BUCKET --tagging 'TagSet=[{Key=Project,Value=cloud-programming},{Key=Purpose,Value=terraform-state}]'
```

### 2. Terraform initialisieren

```bash
cd terraform
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

In `backend.hcl` den Bucket-Namen eintragen, in `terraform.tfvars` das eigene GitHub-Repository und dessen numerische IDs. Beide Dateien werden nicht eingecheckt. Die IDs liefert die GitHub CLI:

```bash
gh api users/<besitzer> --jq .id
gh api repos/<besitzer>/<name> --jq .id
```

Das Profil muss auch hier gesetzt sein, sonst nutzt Terraform die Standard-Zugangsdaten und womöglich ein anderes Konto.

```bash
export AWS_PROFILE=cloud-programming
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 3. Webseite hochladen

Terraform legt nur die Infrastruktur an. Die Dateien aus `site/` kommen per AWS CLI in den Bucket. Bucket-Name und Adresse gibt Terraform als Output aus.

```bash
aws s3 sync ../site/ s3://$(terraform output -raw site_bucket_name)/ --delete
aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"
terraform output website_url
```

### 4. Automatisches Deployment einrichten

Bei jedem Push auf `main`, der `site/` oder den Workflow selbst ändert, und bei manuellem Start lädt der Workflow `.github/workflows/deploy.yml` die Seite hoch und leert den Cache. Er meldet sich über OpenID Connect bei AWS an und nimmt die Rolle `cloud-programming-github-deploy` an. In GitHub liegen dafür keine Zugangsschlüssel, nur drei Repository-Variablen:

```bash
gh variable set AWS_DEPLOY_ROLE_ARN --body "$(terraform output -raw github_deploy_role_arn)"
gh variable set SITE_BUCKET_NAME --body "$(terraform output -raw site_bucket_name)"
gh variable set CLOUDFRONT_DISTRIBUTION_ID --body "$(terraform output -raw cloudfront_distribution_id)"
```

Je AWS-Konto ist nur ein OIDC-Provider für GitHub erlaubt. Gibt es ihn schon, etwa aus einem anderen Projekt, in `terraform.tfvars` `create_github_oidc_provider = false` setzen. Terraform benutzt ihn dann mit, ohne ihn zu verwalten.

### 5. Überwachung und Budget

Terraform legt einen CloudWatch-Alarm auf die Fehlerrate (5xx) von CloudFront und ein monatliches Budget an. Beide melden sich per E-Mail an die Adresse aus `alert_email`.

- Nach dem ersten `apply` schickt AWS eine Mail mit Bestätigungslink. Erst nach der Bestätigung werden Alarme zugestellt.
- Das Budget zählt nur Kosten mit dem Tag `Project` dieses Projekts, damit andere Projekte im selben Konto nicht mitzählen. Dafür den Tag einmalig in der Konsole unter Billing and Cost Management → Cost allocation tags aktivieren. Der Tag erscheint dort erst, wenn er in den Abrechnungsdaten aufgetaucht ist, das dauert bis zu 24 Stunden. Die Aktivierung gilt ab ihrem Zeitpunkt. Bis dahin zählt das Budget nichts und warnt auch nicht.
- Der Alarm löst aus, wenn in zwei von drei aufeinanderfolgenden 5-Minuten-Abschnitten mehr als 5 % der Anfragen mit einem Serverfehler enden. Einzelne Fehler bei wenig Verkehr lösen so keinen Fehlalarm aus.

Den Alarm testen, ohne echte Fehler zu erzeugen:

```bash
aws cloudwatch set-alarm-state --region us-east-1 --alarm-name cloud-programming-cloudfront-5xx --state-value ALARM --state-reason "Test"
```

Kurz danach wertet CloudWatch die echten Daten neu aus, der Alarm kehrt zu OK zurück und es folgt eine zweite Mail als Entwarnung.

## Sicherheit

- Der Bucket ist privat. Nur die eigene CloudFront-Distribution darf über Origin Access Control lesen, Anfragen ohne HTTPS lehnt die Bucket-Policy ab.
- CloudFront leitet HTTP auf HTTPS um und setzt Sicherheits-Header: HSTS, Content Security Policy, X-Frame-Options, X-Content-Type-Options, Referrer-Policy und Permissions-Policy.
- Daten im Bucket sind verschlüsselt (SSE-S3) und versioniert. Alte Versionen werden nach 30 Tagen gelöscht.
- Die Deploy-Rolle kann nur der `main`-Branch dieses Repositorys annehmen. Sie darf nur Dateien im Bucket der Webseite schreiben und löschen und den Cache der eigenen Distribution leeren. Ihre Zugangsdaten gelten höchstens eine Stunde.
- Die Actions im Workflow sind auf feste Commit-Hashes gepinnt.
- Jeder Pull Request mit Änderungen an `terraform/` durchläuft `terraform fmt`, `terraform validate`, TFLint und Checkov. Prüfungen, die für diese Seite bewusst entfallen (etwa WAF, Zugriffsprotokolle, eigener KMS-Schlüssel, eigenes Zertifikat), sind direkt an der Ressource mit `#checkov:skip` und Begründung markiert. Die meisten scheitern am Budget oder an der fehlenden eigenen Domain.

## Abbau

Der Bucket ist versioniert und wird von Terraform nicht gelöscht, solange er Dateien enthält. Das schützt vor versehentlichem Datenverlust. Vor `terraform destroy` deshalb alle Versionen in der S3-Konsole über „Leeren“ entfernen.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
