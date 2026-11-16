#!/usr/bin/env bash
# Certificado SSH de usuario firmado por Vault (TrustedUserCAKeys en destinos).
# Auth: token existente, AppRole (env o /vault/secrets/*) o login OIDC solo en TTY.
set -euo pipefail

: "${USER_HOME:=${HOME:-/root}}"

: "${VAULT_SSH_KEY:=${USER_HOME}/.ssh/id_ed25519}"


: "${VAULT_SSH_TTL:=8h}"
: "${VAULT_SSH_RENEW:=3600}"
: "${VAULT_SSH_CA_ENABLED:=no}"
: "${VAULT_SSH_AUTH_PATH:=oidc}"
: "${VAULT_SSH_AUTH_ROLE:=default}"

CERT="${VAULT_SSH_KEY}-cert.pub"

log() {
	if [[ "${VERBOSE_BOOT:-}" == "yes" ]]; then
        echo "ssh_vault_ca: $*" >&2
    fi
}

if [[ "${VAULT_SSH_CA_ENABLED}" == "no" ]]; then
	log "VAULT_SSH_CA_ENABLED=no, omitiendo firma SSH"
	exit 0
fi

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_SSH_ROLE:?Set VAULT_SSH_ROLE}"
: "${VAULT_SSH_PRINCIPAL:?Set VAULT_SSH_PRINCIPAL}"

vault_session_ok() {
	vault token lookup >/dev/null 2>&1
}

vault_login_approle() {
	local role_id="${VAULT_APPROLE_ROLE_ID:-}"
	local secret_id="${VAULT_APPROLE_SECRET_ID:-}"

	[[ -z "$role_id" && -f /vault/secrets/role_id ]] && role_id="$(< /vault/secrets/role_id)"
	[[ -z "$secret_id" && -f /vault/secrets/secret_id ]] && secret_id="$(< /vault/secrets/secret_id)"
	[[ -z "$role_id" || -z "$secret_id" ]] && return 1

	log "Login AppRole en Vault..."
	export VAULT_TOKEN
	VAULT_TOKEN="$(vault write -field=token auth/approle/login \
		role_id="$role_id" \
		secret_id="$secret_id")"
}

ensure_vault_session() {
	if vault_session_ok; then
		return 0
	fi
	if vault_login_approle; then
		return 0
	fi
	if [[ -t 0 && -t 1 ]]; then
		log "Sesión Vault expirada; login OIDC..."
		vault login -method=oidc -path="$VAULT_SSH_AUTH_PATH" role="$VAULT_SSH_AUTH_ROLE"
		return 0
	fi
	log "No Vault session (provide a token, AppRole credentials or an interactive login)"
	return 1
}

ensure_ssh_key() {
	mkdir -p "$(dirname "$VAULT_SSH_KEY")"
	chmod 700 "$(dirname "$VAULT_SSH_KEY")"
	if [[ ! -f "${VAULT_SSH_KEY}.pub" ]]; then
		log "Generando ${VAULT_SSH_KEY}..."
		ssh-keygen -t ed25519 -f "$VAULT_SSH_KEY" -N '' -C "${USER:-user}@$(hostname -s 2>/dev/null || echo container)"
	fi
	chmod 600 "$VAULT_SSH_KEY" "${VAULT_SSH_KEY}.pub"
}

cert_expiry_epoch() {
	local valid_line expiry
	valid_line="$(ssh-keygen -L -f "$CERT" 2>/dev/null | grep -E '^\s+Valid:' || true)"
	[[ -z "$valid_line" ]] && return 1
	expiry="$(sed -n 's/.*to \([0-9-T:.]*\).*/\1/p' <<<"$valid_line")"
	[[ -z "$expiry" ]] && return 1
	date -d "$expiry" +%s
}

cert_needs_renew() {
	[[ ! -f "$CERT" ]] && return 0
	local expiry_epoch now
	expiry_epoch="$(cert_expiry_epoch)" || return 0
	now="$(date +%s)"
	(( expiry_epoch - now < VAULT_SSH_RENEW ))
}

sign_cert() {
	log "Firmando certificado (principal=${VAULT_SSH_PRINCIPAL}, ttl=${VAULT_SSH_TTL})..."
	vault write -field=signed_key "ssh/sign/${VAULT_SSH_ROLE}" \
		public_key=@"${VAULT_SSH_KEY}.pub" \
		valid_principals="$VAULT_SSH_PRINCIPAL" \
		ttl="$VAULT_SSH_TTL" >"$CERT"
	chmod 600 "$CERT"
}

ensure_ssh_key

if cert_needs_renew; then
	ensure_vault_session || exit 1
	sign_cert
else
	log "Certificado SSH válido (${CERT})"
fi
