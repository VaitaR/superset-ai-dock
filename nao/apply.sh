#!/usr/bin/env bash
# Clone upstream nao at the pinned commit into .work/nao and apply patches/*.patch on top.
# Idempotent: an existing checkout is reset to the pin and re-patched.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="${NAO_DIR:-$ROOT/.work/nao}"
UPSTREAM="${NAO_UPSTREAM:-https://github.com/getnao/nao.git}"
PIN="$(tr -d '[:space:]' <"$HERE/NAO_COMMIT")"

if [[ ! -d "$DEST/.git" ]]; then
	mkdir -p "$(dirname "$DEST")"
	git init -q "$DEST"
	git -C "$DEST" remote add origin "$UPSTREAM"
fi
if ! git -C "$DEST" cat-file -e "$PIN^{commit}" 2>/dev/null; then
	git -C "$DEST" fetch -q --depth 1 origin "$PIN"
fi
git -C "$DEST" checkout -q -f --detach "$PIN"
git -C "$DEST" clean -fdq -e node_modules -e .env
patches=("$HERE"/patches/*.patch)
git -C "$DEST" -c user.name=demo -c user.email=demo@example.invalid am -q --3way "${patches[@]}"
echo "nao at $PIN + ${#patches[@]} patches in $DEST"
