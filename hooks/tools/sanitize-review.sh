#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "sanitize-review.sh: jq is required but not installed" >&2
  exit 1
fi

if [[ -t 0 ]]; then
  echo "Usage: sanitize-review.sh < review-output.txt" >&2
  exit 1
fi

extract_json_object() {
  local input="$1"
  local len="${#input}"
  local depth=0
  local in_string=0
  local escaped=0
  local start=-1
  local i
  local ch
  local candidate

  for ((i = 0; i < len; i++)); do
    ch="${input:i:1}"

    if [[ "$escaped" -eq 1 ]]; then
      escaped=0
      continue
    fi

    if [[ "$in_string" -eq 1 ]]; then
      if [[ "$ch" == "\\" ]]; then
        escaped=1
      elif [[ "$ch" == "\"" ]]; then
        in_string=0
      fi
      continue
    fi

    if [[ "$ch" == "\"" ]]; then
      in_string=1
      continue
    fi

    if [[ "$ch" == "{" ]]; then
      if [[ "$depth" -eq 0 ]]; then
        start="$i"
      fi
      depth=$((depth + 1))
      continue
    fi

    if [[ "$ch" == "}" && "$depth" -gt 0 ]]; then
      depth=$((depth - 1))
      if [[ "$depth" -eq 0 && "$start" -ge 0 ]]; then
        candidate="${input:start:i-start+1}"
        if printf '%s' "$candidate" | jq -e 'type == "object"' >/dev/null 2>&1; then
          printf '%s\n' "$candidate"
          return 0
        fi
        start=-1
      fi
    fi
  done

  return 1
}

raw_input="$(cat)"
if [[ -z "${raw_input//[[:space:]]/}" ]]; then
  echo "sanitize-review.sh: no input provided on stdin" >&2
  exit 1
fi

cleaned_input="$(printf '%s' "$raw_input" \
  | sed -E '/^[[:space:]]*```([[:alnum:]_-]+)?[[:space:]]*$/d' \
  | sed -E 's/:contentReference\[oaicite:[0-9]+\]\{index=[0-9]+\}//g')"

json_payload=""
if json_payload="$(printf '%s' "$cleaned_input" | jq -e -c 'select(type == "object")' 2>/dev/null)"; then
  :
else
  if ! json_payload="$(extract_json_object "$cleaned_input")"; then
    echo "sanitize-review.sh: unable to find a valid JSON object in input" >&2
    exit 1
  fi
fi

printf '%s' "$json_payload" | jq -e '
  def clean_refs:
    gsub(":contentReference\\[oaicite:[0-9]+\\]\\{index=[0-9]+\\}"; "");
  def clean_opt:
    if type == "string" then clean_refs else . end;

  if (.suggestions | type) != "array" then
    error(".suggestions must be an array")
  elif (.summary | type) != "string" then
    error(".summary must be a string")
  else
    .
    | .summary |= clean_opt
    | .suggestions |= map(
        if type == "object" then
          (if has("suggestion") then .suggestion |= clean_opt else . end)
          | (if has("evidence") then .evidence |= clean_opt else . end)
          | (if has("section") then .section |= clean_opt else . end)
        else
          .
        end
      )
  end
'
