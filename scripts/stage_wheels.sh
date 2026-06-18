#!/usr/bin/env bash
# Laedt die Wheel-Artefakte eines build-wheels-Runs herunter und staffelt sie in
# die Token-Struktur, die gen_runtime_catalog.py erwartet:
#
#   <out>/runtime/<token>/<wheel>.whl
#
# Aufruf:  scripts/stage_wheels.sh <run-id> [out-dir]
#          scripts/stage_wheels.sh            # nimmt den letzten Run
set -euo pipefail

run_id="${1:-}"
out="${2:-./out}"
repo="murc134/senity-llama-wheels"

if [[ -z "$run_id" ]]; then
  run_id=$(gh run list --repo "$repo" --workflow build-wheels.yml \
    --limit 1 --json databaseId --jq '.[0].databaseId')
  echo "Letzter Run: $run_id"
fi

tmp=$(mktemp -d)
gh run download "$run_id" --repo "$repo" --dir "$tmp"

mkdir -p "$out/runtime"
shopt -s nullglob
for art in "$tmp"/*/; do
  token=$(basename "$art")          # Artefaktname == Token
  whl=("$art"*.whl)
  if [[ ${#whl[@]} -eq 0 ]]; then
    echo "  WARN: kein Wheel in $token" >&2
    continue
  fi
  mkdir -p "$out/runtime/$token"
  cp "${whl[@]}" "$out/runtime/$token/"
  echo "  $token <- $(basename "${whl[0]}")"
done

rm -rf "$tmp"
echo
echo "Fertig. Hochladen mit:"
echo "  scp -r $out/runtime/* user@hetzner:<MODELS_DIR>/runtime/"
