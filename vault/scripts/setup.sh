#!/usr/bin/env bash
set -euo pipefail

COMPOSE_BIN="${COMPOSE_BIN:-docker compose}"
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
ROLE_ID_FILE="${ROLE_ID_FILE:-vault/agent/role_id}"
SECRET_ID_FILE="${SECRET_ID_FILE:-vault/agent/secret_id}"
SSH_KEY_FILE="${SSH_KEY_FILE:-}"
POLICY_FILE="${POLICY_FILE:-/vault/policies/api.hcl}"

vexec() {
  ${COMPOSE_BIN} exec -e "VAULT_ADDR=${VAULT_ADDR}" "$@"
}

echo "== Vault setup start =="

status_output="$(${COMPOSE_BIN} exec vault vault status 2>/dev/null || true)"
if [[ -z "${status_output}" ]]; then
  echo "Vault status not available. Is the vault container running?"
  exit 1
fi

if echo "${status_output}" | grep -Eq "Initialized[[:space:]]+false"; then
  echo "Vault not initialized. Initializing now..."
  init_out="$(${COMPOSE_BIN} exec vault vault operator init -key-shares=1 -key-threshold=1)"
  echo "${init_out}"
  echo
  echo "IMPORTANT:"
  echo "1) Save Unseal Key and Initial Root Token securely."
  echo "2) Export them to rerun this script:"
  echo "   export UNSEAL_KEY=<Unseal Key 1>"
  echo "   export VAULT_TOKEN=<Initial Root Token>"
  echo "Then run this script again."
  exit 0
fi

if echo "${status_output}" | grep -Eq "Sealed[[:space:]]+true"; then
  if [[ -z "${UNSEAL_KEY:-}" ]]; then
    echo "Vault is sealed. Set UNSEAL_KEY and rerun."
    exit 1
  fi
  echo "Unsealing Vault..."
  vexec vault vault operator unseal "${UNSEAL_KEY}"
fi

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  echo "VAULT_TOKEN is required for setup steps. Export VAULT_TOKEN and rerun."
  exit 1
fi

echo "Enabling KV (if not enabled)..."
vexec -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault secrets enable -path=secret kv-v2 || true

echo "Writing policy..."
vexec -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault policy write api "${POLICY_FILE}"

echo "Enabling AppRole (if not enabled)..."
vexec -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault auth enable approle || true

echo "Creating/Updating AppRole..."
vexec -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault write auth/approle/role/api policies=api token_ttl=1h token_max_ttl=4h

echo "Writing role_id..."
vexec -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault read -field=role_id auth/approle/role/api/role-id > "${ROLE_ID_FILE}"

echo "Writing secret_id..."
vexec -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault write -field=secret_id -f auth/approle/role/api/secret-id > "${SECRET_ID_FILE}"

if [[ -n "${SSH_KEY_FILE}" ]]; then
  if [[ ! -f "${SSH_KEY_FILE}" ]]; then
    echo "SSH_KEY_FILE not found: ${SSH_KEY_FILE}"
    exit 1
  fi
  echo "Uploading SSH key to Vault..."
  cat "${SSH_KEY_FILE}" | ${COMPOSE_BIN} exec -T -e "VAULT_ADDR=${VAULT_ADDR}" -e "VAULT_TOKEN=${VAULT_TOKEN}" vault vault kv put secret/aws/ssh private_key=-
fi

echo "Restarting vault-agent..."
${COMPOSE_BIN} restart vault-agent

echo "Verifying rendered key file..."
${COMPOSE_BIN} exec vault-agent ls -l /vault/secrets || true

echo "== Vault setup complete =="
