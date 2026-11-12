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
- AWS CLI v2 mit einem Profil, das Rechte für S3, CloudFront, CloudWatch, SNS und AWS Budgets hat
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
```

### 2. Terraform initialisieren

```bash
cd terraform
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

In `backend.hcl` den Bucket-Namen eintragen, in `terraform.tfvars` das eigene GitHub-Repository. Beide Dateien werden nicht eingecheckt.

Das Profil muss auch hier gesetzt sein, sonst nutzt Terraform die Standard-Zugangsdaten und womöglich ein anderes Konto.

```bash
export AWS_PROFILE=cloud-programming
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Lizenz

MIT, siehe [LICENSE](LICENSE).
