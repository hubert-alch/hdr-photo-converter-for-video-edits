#!/bin/zsh
set -euo pipefail

mode="$1"
harness="$2"
worker="$3"
source="$4"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

mkdir -p "$workspace/sources" "$workspace/output"
for index in {1..10}; do
    ln -s "$source" "$workspace/sources/photo_${index}.jpg"
done

if [[ "$mode" == "worker" ]]; then
    ULTRAHDR_WORKER_PATH="$worker" "$harness" "$workspace/sources" "$workspace/output" 0.2 &
else
    env -u ULTRAHDR_WORKER_PATH "$harness" "$workspace/sources" "$workspace/output" 0.2 &
fi
pid=$!
peak_rss=0
while kill -0 "$pid" 2>/dev/null; do
    parent_rss=$(ps -o rss= -p "$pid" | tr -d ' ')
    worker_rss=$(ps -axo rss=,command= | awk '/HDR_Photo_Converter_for_Video_Editors_Converter/ { total += $1 } END { print total + 0 }')
    current_rss=$((parent_rss + worker_rss))
    (( current_rss > peak_rss )) && peak_rss=$current_rss
    sleep 0.1
done
wait "$pid"

echo "peak_rss_kb=$peak_rss"
if (( peak_rss > 400000 )); then
    echo "batch conversion exceeded 400 MB RSS" >&2
    exit 1
fi
