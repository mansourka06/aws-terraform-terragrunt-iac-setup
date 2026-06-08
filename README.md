# 🏗️ webapp-infra — Terraform + Terragrunt Production-Ready AWS Infrastructure

Production-ready Terraform and Terragrunt infrastructure setup

A fully layered, multi-environment AWS infrastructure for a web application.  
**Terraform** owns all resource definitions; **Terragrunt** handles environment promotion, remote state, and DRY configuration.

---

## Architecture Decision: Separate App & DB Tiers

```
Internet
   │
   ▼
[ALB — public subnets, multi-AZ]
   │  HTTPS 443 (HTTP→HTTPS redirect)
   ▼
[EC2 Auto Scaling Group — private subnets, multi-AZ]
   │  port 5432 (Aurora PostgreSQL)
   ▼
[Aurora Cluster — private subnets, multi-AZ]
   Writer endpoint + N Reader endpoints
```

Rather than one monolithic server per environment, the app and database tiers are **deployed independently**:

| Concern | Why separate tiers? |
|---|---|
| **Security** | DB SG only accepts traffic from the app SG — zero direct internet access |
| **Scaling** | App ASG scales horizontally; Aurora scales read replicas independently |
| **Blast radius** | A bad app deploy cannot corrupt the DB host |
| **Cost** | Dev runs `t3.micro` + zero DB readers; Prod runs `t3.medium` + `db.r6g.large` × 3 |

---

## Environment Matrix

| | **dev** | **staging** | **prod** |
|---|---|---|---|
| App instance | `t3.micro` | `t3.small` | `t3.medium` |
| ASG desired / max | 1 / 2 | 2 / 4 | 3 / 9 |
| DB instance class | `db.t3.medium` | `db.t3.medium` | `db.r6g.large` |
| Aurora reader count | 0 | 1 | 2 |
| Deletion protection | ✗ | ✗ | ✓ |
| Final snapshot | ✗ | ✗ | ✓ |
| Backup retention | 1 day | 3 days | 14 days |
| ALB access log retention | 7 days | 14 days | 90 days |
| Multi-AZ subnets | 2 | 3 | 3 |

---

## Project Structure

```
webapp-infra/
├── terraform/                   # Reusable modules (pure HCL, no environment logic)
│   ├── app/
│   │   ├── main.tf              # ALB, ASG, Launch Template, IAM, CloudWatch alarms
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── user_data.sh.tpl    # EC2 bootstrap script
│   └── db/
│       ├── main.tf              # Aurora PostgreSQL, KMS, Secrets Manager, monitoring
│       ├── variables.tf
│       ├── outputs.tf
│       └── providers.tf
│
└── terragrunt/                  # Environment orchestration
    ├── terragrunt.hcl           # ROOT: remote state, provider, common inputs
    ├── dev/
    │   ├── environment_specific.hcl   # Dev sizing, region, account ID
    │   ├── app/terragrunt.hcl
    │   └── db/terragrunt.hcl
    ├── staging/
    │   ├── environment_specific.hcl
    │   ├── app/terragrunt.hcl
    │   └── db/terragrunt.hcl
    └── prod/
        ├── environment_specific.hcl
        ├── app/terragrunt.hcl
        └── db/terragrunt.hcl
```

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Terraform | 1.6.0 |
| Terragrunt | 0.55.0 |
| AWS CLI | 2.x |
| AWS account(s) | One per environment (recommended) |

---

## First-Time Bootstrap

### 1 — Create the Terraform state bucket & DynamoDB lock table

The S3 backend must exist before the first `apply`.  
Name pattern: `tfstate-webapp-<ACCOUNT_ID>-<REGION>`

```bash
# Example for dev
aws s3api create-bucket \
  --bucket tfstate-webapp-111111111111-eu-west-1 \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket tfstate-webapp-111111111111-eu-west-1 \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name tfstate-lock-webapp \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1
```

### 2 — Update placeholder values

Edit the files below and replace every `REPLACE-ME` token:

| File | What to replace |
|---|---|
| `terragrunt/<env>/environment_specific.hcl` | `account_id`, `ami_id`, `acm_certificate_arn` |
| `terragrunt/<env>/app/terragrunt.hcl` | `vpc_id`, `subnet-*` IDs |
| `terragrunt/<env>/db/terragrunt.hcl` | `vpc_id`, `subnet-*` IDs |

> **Tip:** use a [VPC Terraform module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) and wire its outputs via a `dependency` block instead of hardcoding IDs.

### 3 — Set the DB password

```bash
export TF_VAR_DB_MASTER_PASSWORD="$(openssl rand -base64 24)"
```

In CI/CD, store this in GitHub Actions Secrets / GitLab CI Variables / AWS Secrets Manager and inject at pipeline time.

---

## Day-to-Day Commands

### Plan a single module

```bash
cd terragrunt/dev/app
terragrunt plan
```

### Apply a single module

```bash
cd terragrunt/dev/app
terragrunt apply
```

### Apply the full environment (respects dependency order)

```bash
cd terragrunt/dev
terragrunt run-all apply
```

### Destroy (non-prod only)

```bash
cd terragrunt/dev
terragrunt run-all destroy
```

### Validate all modules

```bash
cd terragrunt
terragrunt run-all validate
```

---

## Security Highlights

- **Private subnets** — EC2 instances and Aurora are never exposed to the internet.
- **IMDSv2** enforced on all instances (no credential-stealing via SSRF).
- **ALB → HTTPS redirect** — HTTP traffic is automatically redirected; TLS 1.3 policy.
- **Security Group chaining** — ALB SG → App SG → DB SG; no wide-open CIDR rules.
- **KMS encryption at rest** — Aurora cluster and Secrets Manager secret both use a dedicated customer-managed key with automatic rotation.
- **Secrets Manager** — DB credentials are never in Terraform state; the app reads them at runtime from `/webapp/<env>/db/master-password`.
- **Deletion protection + final snapshot** — enabled in prod to prevent accidental data loss.
- **SSM Session Manager** — SSH port 22 is locked to VPC CIDR; use SSM for shell access instead of a bastion.

---

## Extending the Infrastructure

### Add a new environment (e.g. `perf`)
1. Copy `terragrunt/staging/` → `terragrunt/perf/`
2. Edit `environment_specific.hcl` with the new account ID and sizing.
3. Run `terragrunt run-all apply` inside `terragrunt/perf/`.

### Add a new module (e.g. `cache` for ElastiCache)
1. Create `terraform/cache/` with `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`.
2. Create `terragrunt/<env>/cache/terragrunt.hcl` for each environment.
3. Add a `dependency "app"` block if the cache SG needs to reference the app SG.

---

## CI/CD Integration (GitHub Actions example)

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: "1.6.0" }
      - name: Setup Terragrunt
        run: |
          curl -Lo /usr/local/bin/terragrunt \
            https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_amd64
          chmod +x /usr/local/bin/terragrunt

      - name: Plan prod
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          TF_VAR_DB_MASTER_PASSWORD: ${{ secrets.DB_MASTER_PASSWORD }}
        run: |
          cd terragrunt/prod
          terragrunt run-all plan --terragrunt-non-interactive

      - name: Apply prod
        env:
          TF_VAR_DB_MASTER_PASSWORD: ${{ secrets.DB_MASTER_PASSWORD }}
        run: |
          cd terragrunt/prod
          terragrunt run-all apply --terragrunt-non-interactive -auto-approve
```

---

## Licence

MIT — use freely, contribute back.

---

## Author

- [Mansour KA](https://github.com/mansourka06)
