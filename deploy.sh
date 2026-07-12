#!/usr/bin/env bash
# Orchestrates the full deploy: Terraform (provision) -> Ansible (configure).
# AWS CLI is used to validate credentials and report the running instance.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$ROOT/terraform"
ANSIBLE_DIR="$ROOT/ansible"

# --- Pull credentials/region from terraform.tfvars so the AWS CLI matches TF ---
TFVARS="$TF_DIR/terraform.tfvars"
if [[ ! -f "$TFVARS" ]]; then
  echo "ERROR: $TFVARS not found. Copy terraform.tfvars.example and fill it in." >&2
  exit 1
fi

# Portable across BSD (macOS) and GNU sed: \s is not supported by BSD sed,
# so use [[:space:]] and strip the key, surrounding quotes, and whitespace.
tfvar() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$TFVARS" | head -1 \
    | sed -E 's/^[^=]*=[[:space:]]*//; s/^"//; s/"[[:space:]]*$//'
}

export AWS_ACCESS_KEY_ID="$(tfvar aws_access_key)"
export AWS_SECRET_ACCESS_KEY="$(tfvar aws_secret_key)"
export AWS_DEFAULT_REGION="$(tfvar aws_region)"
: "${AWS_DEFAULT_REGION:=us-east-1}"

# --- Validate credentials via AWS CLI before doing anything ---
echo ">> Validating AWS credentials with AWS CLI..."
aws sts get-caller-identity --output table

# --- Provision with Terraform ---
echo ">> Provisioning infrastructure with Terraform..."
terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" apply -auto-approve -input=false

INSTANCE_ID="$(terraform -chdir="$TF_DIR" output -raw instance_id)"
PUBLIC_IP="$(terraform -chdir="$TF_DIR" output -raw public_ip)"

# --- Wait for the instance to be running (AWS CLI) ---
echo ">> Waiting for instance $INSTANCE_ID to reach 'running' (AWS CLI)..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,IP:PublicIpAddress}' \
  --output table

# --- Configure NGINX with Ansible ---
echo ">> Configuring NGINX with Ansible..."
ansible-playbook -i "$ANSIBLE_DIR/inventory.ini" "$ANSIBLE_DIR/playbook.yml"

echo ">> Done. NGINX is available at: http://$PUBLIC_IP"
