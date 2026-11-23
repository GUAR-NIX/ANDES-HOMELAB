#!/bin/bash
# Los mismos controles que GitHub Actions (.github/workflows/ci.yml), en adm-ans01, antes de hacer push
set -u
cd "$(dirname "$0")/.."
export PATH=~/.venvs/lint/bin:~/.local/bin:$PATH ANSIBLE_COLLECTIONS_PATH=~/.venvs/lint/collections
fallos=0
paso(){ echo; echo "=== $1"; }

paso "Workflows de GitHub Actions: YAML valido"
for wf in .github/workflows/*.yml; do
  python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$wf" && echo "$wf YAML OK" || { echo "$wf YAML INVALIDO"; fallos=$((fallos+1)); }
done
# actionlint valida ademas el esquema de GitHub Actions (claves, expresiones, shellcheck de los run)
actionlint -no-color && echo "actionlint OK" || fallos=$((fallos+1))

paso "Gitleaks: secretos en todo el historial"
gitleaks git --no-banner --redact . 2>&1 | grep -E 'leaks|commits scanned' || true
gitleaks git --no-banner --redact . >/dev/null 2>&1 || fallos=$((fallos+1))

paso "Terraform: fmt + validate"
(cd terraform && terraform fmt -check -recursive && terraform validate -no-color) || fallos=$((fallos+1))

paso "Ansible: ansible-lint (perfil production, Vault con contrasena falsa como en CI)"
vp=$(mktemp); echo ci-sin-secretos > "$vp"
(cd ansible && ANSIBLE_VAULT_PASSWORD_FILE="$vp" ansible-lint --nocolor 2>&1 | grep -vE 'Decryption|vault secrets' | tail -3; exit "${PIPESTATUS[0]}") || fallos=$((fallos+1))
rm -f "$vp"

paso "Trivy: vulnerabilidades, configuracion y secretos (HIGH/CRITICAL)"
salida=$(trivy fs --quiet --scanners vuln,misconfig,secret --severity HIGH,CRITICAL --ignore-unfixed \
  --skip-files terraform/tfplan --exit-code 1 --format table . 2>&1); rc=$?
echo "$salida" | grep -E '│|Total|CRITICAL|HIGH'
[ "$rc" -eq 0 ] || fallos=$((fallos+1))

echo; [ "$fallos" -eq 0 ] && echo "RESULTADO: CI local en verde" || echo "RESULTADO: $fallos control(es) fallido(s)"
exit "$fallos"
