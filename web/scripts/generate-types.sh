#!/bin/sh
set -eu

output="src/lib/database.types.ts"
temporary="${output}.tmp"
trap 'rm -f "$temporary"' EXIT
npx --yes supabase@2.114.0 gen types typescript \
  --project-id jasvndjjzimqiidffwfa \
  --schema public > "$temporary"
mv "$temporary" "$output"
