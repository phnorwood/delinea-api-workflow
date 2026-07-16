# delinea-api-workflow

A demonstration of retrieving secrets from **Delinea Secret Server** at runtime,
shown three different ways. Everything else in this repo is supporting scaffolding that exists only to give the secret retrieval something real to do e.g. provision AWS EC2 instances using credentials that are never written to disk or source control.

The subject of the project is **secret retrieval**, not deployment.

**PRE-REQUISITES:*** These use-cases assume you are retrieving (and using) an AWS IAM credential to query and otherwise engage (via TF, ANS) with AWS EC2 instances. This credential must have the appropriate permissions to perform actions against AWS EC2 instances to complete these tasks.

## Demo Use Cases

| # | Method | How it authenticates to Secret Server | Where secrets are used |
|---|---|---|---|
| 1 | [Terraform TSS provider](#use-case-1--terraform-tss-provider) | OAuth **bearer token** (`TF_VAR_tss_token`) | Provisioning AWS resources at `terraform apply` |
| 2 | [GitHub Actions](#use-case-2--github-actions) | **Client credentials** (client ID + secret) | Inside a CI pipeline on push |
| 3 | [aws-validate.sh](#use-case-3--aws-validatesh) | OAuth **bearer token** (`BEARER_TOKEN`) | A shell script calling the Secret Server API directly |

In every case the secret is a Secret Server secret whose template exposes two
fields (slugs `access-key` and `secret-key`) holding an AWS access key and secret
key. Retrieval happens at runtime; nothing sensitive is committed to the repo.

---

## Use-Case #1 via Terraform Provider

Terraform uses the [`DelineaXPM/tss`](https://registry.terraform.io/providers/DelineaXPM/tss/latest/docs)
provider to read the AWS credentials from Secret Server at apply time via
**ephemeral** resources. Ephemeral values live in memory only for the duration of
the run — they are never written to state (`terraform.tfstate`) or to disk. This
requires **Terraform >= 1.10**.

The AWS credentials feed the `aws` provider, which then provisions a small demo
target: one EC2 instance running NGINX (see [terraform/main.tf](terraform/main.tf)).
The deployment itself is incidental — it just proves the fetched credentials work.

### Prerequisites

- Terraform >= 1.10.
- A Secret Server secret containing the AWS credentials in fields with slugs
  `access-key` and `secret-key`.
- An OAuth bearer token with **View** access to that secret, obtained out of band
  (e.g. from the Secret Server `/oauth2/token` endpoint).

### Required variables

Non-secret settings go in `terraform.tfvars`; the token is passed via the
environment so it never lands in a file.

| Variable | Where set | Required | Description |
|---|---|---|---|
| `tss_server_url` | `terraform.tfvars` | ✅ | Secret Server base URL. On-prem: `https://<host>/SecretServer`; Cloud: `https://<tenant>.secretservercloud.com` (no path). |
| `tss_secret_id` | `terraform.tfvars` | ✅ | ID of the secret holding the AWS credentials. |
| `tss_token` | `TF_VAR_tss_token` env | ✅ | OAuth bearer token. Sensitive — supplied out of band. |
| `aws_access_key_slug` | `terraform.tfvars` | ➖ | Field slug for the access key. Default `access-key`. |
| `aws_secret_key_slug` | `terraform.tfvars` | ➖ | Field slug for the secret key. Default `secret-key`. |
| `aws_region` | `terraform.tfvars` | ➖ | AWS region. Default `us-east-1`. |

If your secret template uses different field slugs (e.g. `username` / `password`),
override the two slug variables. To inspect the real slugs on a secret:

```bash
curl -sS -H "Authorization: Bearer $TF_VAR_tss_token" \
  "$TSS_SERVER_URL/api/v1/secrets/<id>" | jq '.items[].slug'
```

### Run

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform.tfvars — set tss_server_url and tss_secret_id
export TF_VAR_tss_token="<out-of-band bearer token>"

cd terraform
terraform init      # installs the tss provider
terraform apply     # fetches AWS creds from Secret Server, then provisions
```

`terraform.tfvars` and the generated `*.pem` key are gitignored.

### Optional

Terraform renders an Ansible inventory pointing at the new instance. To install
NGINX and confirm the box is reachable:

```bash
cd ../ansible
ansible-playbook -i inventory.ini playbook.yml
```

### Destroy

Tear everything down when finished:

```bash
cd terraform && terraform destroy
```

---

## Use-Case #2 via GitHub Actions

A CI pipeline that retrieves secrets during a workflow run, demonstrating the
[Delinea GitHub integration](https://docs.delinea.com/online-help/integrations/github/github-overview.htm).
See [.github/workflows/delinea-integration.yml](.github/workflows/delinea-integration.yml).

Unlike the other two use-cases, this authenticates with **client credentials**
(a client ID and secret belonging to an application account) rather than a bearer
token. The [`delineaxpm/dpss-github-action`](https://github.com/DelineaXPM/dpss-github-action)
Docker image handles the OAuth exchange, retrieves the requested fields, and
writes them to `$GITHUB_ENV` so later steps can consume them.

### Prerequisites

- An application account in Secret Server with a client ID / secret and access to
  the target secret.
- The following configured as **GitHub repository secrets** (Settings → Secrets
  and variables → Actions):

| GitHub secret | Description |
|---|---|
| `DPSS_SERVER_URL` | Secret Server base URL. |
| `DPSS_CLIENT_ID` | Client ID of the application account. |
| `DPSS_CLIENT_SECRET` | Client secret of the application account. |

### What to retrieve

Which fields to pull is defined inline in the workflow via the `DELINEA_RETRIEVE`
JSON — a list mapping each `secretId` / `secretKey` (field slug) to an
`outputVariable`:

```json
[
  {"secretId":"<id>","secretKey":"access-key","outputVariable":"AWS_ACCESS_KEY"}
]
```

### Run

The workflow triggers automatically on push to `main`. It checks out the repo,
runs the retrieval action, masks the retrieved values in the logs, and then a
final step consumes them.

---

## Use-Case #3 via API

A self-contained BASH script that calls the Secret Server REST API directly,
extracts the AWS credentials, configures the AWS CLI, and validates them with
`aws sts get-caller-identity`. See [aws-validate.sh](aws-validate.sh).

This is the lowest-level illustration: `curl` to `GET /api/v2/secrets/<id>`, then
`jq` to pull the field values out of the response `items[]` by slug.

### Prerequisites

- `curl`, `jq`, and the AWS CLI installed.
- An OAuth bearer token with View access to the secret, obtained out of band.

### Required variables

All are environment variables; only `BEARER_TOKEN` is mandatory.

| Variable | Required | Default | Description |
|---|---|---|---|
| `BEARER_TOKEN` | ✅ | — | OAuth bearer token for API authentication. |
| `SECRET_SERVER_URL` | ➖ | `https://<tenant>.secretservercloud.com` | Secret Server base URL (no trailing slash). |
| `SECRET_ID` | ➖ | example default | Numeric ID of the secret to retrieve. |
| `AWS_REGION` | ➖ | `us-east-1` | Region written to the AWS CLI config. |

The script expects the credential fields under the slugs `access-key` and
`secret-key`.

### Run

```bash
export BEARER_TOKEN="<out-of-band bearer token>"
export SECRET_SERVER_URL="https://<tenant>.secretservercloud.com"
export SECRET_ID="<id>"

./aws-validate.sh
```

---

## Repo layout

```
terraform/     provisions the demo EC2 target; fetches AWS creds via the tss provider (use-case 1)
ansible/       installs NGINX on the provisioned instance (supporting)
aws-validate.sh   API-based retrieval in BASH (use-case 3)
.github/workflows/   GitHub Actions retrieval pipeline (use-case 2)
```