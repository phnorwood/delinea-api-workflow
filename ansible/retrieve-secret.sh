#!/usr/bin/env bash
# Wrapper for retrieve-secret.yml (Use-Case #4).
#
# Sets the environment that the community.general.tss lookup needs on macOS,
# then hands every argument straight through to ansible-playbook. These vars
# MUST be present before ansible-playbook forks its worker, which is exactly
# what this wrapper guarantees:
#
#   OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES  # avoids "A worker was found in a
#                                            # dead state" (Python fork safety)
#   no_proxy='*'                             # skips the macOS _scproxy call that
#                                            # trips the fork-safety abort
#
# Usage (args are forwarded verbatim to ansible-playbook):
#   export TSS_TOKEN="<bearer token>"
#   ./retrieve-secret.sh \
#     -e tss_server_url="https://<tenant>.secretservercloud.com" \
#     -e tss_secret_id=75
#
#   # or username/password auth:
#   ./retrieve-secret.sh \
#     -e tss_server_url="https://<tenant>.secretservercloud.com" \
#     -e tss_secret_id=75 \
#     -e tss_username=app_account -e tss_password='<password>'
set -euo pipefail

cd "$(dirname "$0")"

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export no_proxy='*'

exec ansible-playbook retrieve-secret.yml "$@"
