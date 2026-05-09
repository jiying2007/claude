#!/usr/bin/env bash
# Fix codex DNS resolution failures caused by musl binary + systemd-resolved incompatibility.
# Fetches current IPs from Google DoH and updates /etc/hosts.

set -euo pipefail

DOMAINS=(
  "auth.openai.com"
  "chatgpt.com"
)

fetch_ip() {
  local domain="$1"
  curl -sf "https://dns.google/resolve?name=${domain}&type=A" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
answers = [r['data'] for r in d.get('Answer', []) if r['type'] == 1]
print(answers[0] if answers else '')
"
}

need_sudo=false
for domain in "${DOMAINS[@]}"; do
  current=$(grep -E "[[:space:]]${domain}$" /etc/hosts | awk '{print $1}' || true)
  new_ip=$(fetch_ip "$domain")

  if [[ -z "$new_ip" ]]; then
    echo "WARN: could not resolve $domain via Google DNS, skipping"
    continue
  fi

  if [[ "$current" == "$new_ip" ]]; then
    echo "OK:   $domain -> $new_ip (already up to date)"
  else
    need_sudo=true
    if [[ -z "$current" ]]; then
      echo "ADD:  $domain -> $new_ip"
    else
      echo "UPD:  $domain $current -> $new_ip"
    fi
  fi
done

if ! $need_sudo; then
  echo "All entries up to date."
  exit 0
fi

echo ""
echo "Applying changes (requires sudo)..."

for domain in "${DOMAINS[@]}"; do
  new_ip=$(fetch_ip "$domain")
  [[ -z "$new_ip" ]] && continue

  sudo sed -i "/[[:space:]]${domain}$/d" /etc/hosts
  echo "$new_ip $domain" | sudo tee -a /etc/hosts > /dev/null
  echo "DONE: $new_ip $domain"
done

echo ""
echo "Done. Restart codex to apply."
