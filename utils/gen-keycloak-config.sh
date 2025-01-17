#!/bin/sh

# Get named arguments
. utils/parse-args.sh "$@"

# Check required args
if [ ! "$studies" ] || [ ! "$template" ] || [ ! "$out" ]; then
  echo "Missing required args. Usage: sh ./scripts/gen-keycloak-config.sh --studies='study_1 study_2 study_3' --template=/path/to/keycloak-config-template.json --out=/path/to/generated-keycloak-config.json"
  exit 1
else
  template=$(eval echo "$template")
  out=$(eval echo "$out")
fi

STUDIES_JSON_ARRAY=$(echo "$studies" | tr ' ' '\n' | jq -R . | jq -s .)
STUDIES_JSON_OBJECT=$(echo "$STUDIES_JSON_ARRAY" | jq '[.[] | {name: .}]')
jq --argjson json_object "$STUDIES_JSON_OBJECT" --argjson json_array "$STUDIES_JSON_ARRAY" '.roles.client.cbioportal = $json_object | .groups[] |= if .name == "PUBLIC_STUDIES" then .clientRoles.cbioportal = $json_array | . else . end' "$template" > "$out"