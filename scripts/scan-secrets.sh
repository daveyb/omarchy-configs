#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
failed=0

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	mapfile -t files < <(git ls-files -c -o --exclude-standard)
else
	mapfile -t files < <(find . -type f ! -path './.git/*' ! -path './.audit/*')
fi

forbidden_names=(user_credentials.json user_configuration.json tailscale_authkey id_rsa id_ed25519)
for name in "${forbidden_names[@]}"; do
	mapfile -t hits < <(find . -name "$name" ! -path './.git/*')
	if ((${#hits[@]})); then
		echo "FORBIDDEN FILE present: $name" >&2
		printf '%s\n' "${hits[@]}" >&2
		failed=1
	fi
done

if ((${#files[@]} == 0)); then
	echo "scan-secrets: no files" >&2
	exit 1
fi

patterns=(
	'BEGIN (OPENSSH|RSA|DSA|EC) PRIVATE KEY'
	'BEGIN PRIVATE KEY'
	'\$6\$'
	'tskey-[a-z]+-[A-Za-z0-9]+'
	'ghp_[A-Za-z0-9]{20,}'
	'github_pat_[A-Za-z0-9_]{20,}'
	'AKIA[0-9A-Z]{16}'
	'-----BEGIN PGP PRIVATE KEY BLOCK-----'
	'"encryption_password"[[:space:]]*:'
	'"enc_password"[[:space:]]*:'
	'"root_enc_password"[[:space:]]*:'
)
for f in "${files[@]}"; do
	[[ -f $f ]] || continue
	case "$f" in
	scripts/scan-secrets.sh) continue ;;
	esac
	for pat in "${patterns[@]}"; do
		if grep -nEe "$pat" -- "$f" >/dev/null; then
			echo "SECRET MATCH $f  /$pat/" >&2
			grep -nEe "$pat" -- "$f" >&2 || true
			failed=1
		fi
	done
done

if ((failed)); then
	echo "scan-secrets: failed" >&2
	exit 1
fi
echo "scan-secrets: clean ${#files[@]} files"
