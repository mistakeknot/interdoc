#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      jq -n --arg error "unknown argument: $arg" '{error: $error}'
      exit 1
      ;;
  esac
done

for required_cmd in git jq awk sed flock mktemp cmp dirname basename sort find realpath grep; do
  if ! command -v "$required_cmd" >/dev/null 2>&1; then
    jq -n --arg error "missing required command: $required_cmd" '{error: $error}'
    exit 1
  fi
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  jq -n --arg error "not a git repository" '{error: $error}'
  exit 1
}
cd "$REPO_ROOT"

mapfile -t AGENTS_FILES < <(find . -type f -name "AGENTS.md" -not -path "*/node_modules/*" -not -path "*/.git/*" | sort)

json_array_from_lines() {
  if [ "$#" -eq 0 ]; then
    jq -n '[]'
    return
  fi
  printf '%s\n' "$@" | jq -Rsc 'split("\n") | map(select(length > 0))'
}

json_renames() {
  if [ "$#" -eq 0 ]; then
    jq -n '[]'
    return
  fi

  local pair
  for pair in "$@"; do
    printf '%s\n' "$pair"
  done | jq -Rsc '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({old: .[0], new: .[1]})
  '
}

build_summary() {
  local renames_json="$1"
  local deletions_json="$2"
  local additions_json="$3"
  local links_fixed_json="$4"
  local files_modified_json="$5"

  jq -n \
    --argjson renames "$renames_json" \
    --argjson deletions "$deletions_json" \
    --argjson new_files "$additions_json" \
    --argjson links_fixed "$links_fixed_json" \
    --argjson files_modified "$files_modified_json" \
    '{
      renames: $renames,
      deletions: $deletions,
      new_files: $new_files,
      links_fixed: $links_fixed,
      files_modified: $files_modified
    }'
}

if [ "${#AGENTS_FILES[@]}" -eq 0 ]; then
  EMPTY_JSON="$(jq -n '[]')"
  build_summary "$EMPTY_JSON" "$EMPTY_JSON" "$EMPTY_JSON" "$EMPTY_JSON" "$EMPTY_JSON"
  exit 0
fi

OLDEST_AGENTS_COMMIT=""
for agents_file in "${AGENTS_FILES[@]}"; do
  commit="$(git log -1 --format=%H -- "$agents_file" 2>/dev/null || true)"
  if [ -z "$commit" ]; then
    continue
  fi

  if [ -z "$OLDEST_AGENTS_COMMIT" ]; then
    OLDEST_AGENTS_COMMIT="$commit"
    continue
  fi

  if git merge-base --is-ancestor "$commit" "$OLDEST_AGENTS_COMMIT" >/dev/null 2>&1; then
    OLDEST_AGENTS_COMMIT="$commit"
  fi
done

if [ -z "$OLDEST_AGENTS_COMMIT" ]; then
  EMPTY_JSON="$(jq -n '[]')"
  build_summary "$EMPTY_JSON" "$EMPTY_JSON" "$EMPTY_JSON" "$EMPTY_JSON" "$EMPTY_JSON"
  exit 0
fi

RANGE="${OLDEST_AGENTS_COMMIT}..HEAD"

RENAME_PAIRS=()
DIR_RENAME_PAIRS=()
declare -A SEEN_RENAME=()
declare -A SEEN_DIR_RENAME=()
while IFS=$'\t' read -r status old_path new_path; do
  if [ -z "${status:-}" ] || [ -z "${old_path:-}" ] || [ -z "${new_path:-}" ]; then
    continue
  fi

  if [[ ! "$status" =~ ^R[0-9]+$ ]]; then
    continue
  fi

  key="${old_path}"$'\t'"${new_path}"
  if [ -n "${SEEN_RENAME[$key]:-}" ]; then
    continue
  fi
  SEEN_RENAME[$key]=1
  RENAME_PAIRS+=("$key")

  old_dir="$(dirname "$old_path")"
  new_dir="$(dirname "$new_path")"
  if [ "$old_dir" != "$new_dir" ]; then
    dir_key="${old_dir}"$'\t'"${new_dir}"
    if [ -z "${SEEN_DIR_RENAME[$dir_key]:-}" ]; then
      SEEN_DIR_RENAME[$dir_key]=1
      DIR_RENAME_PAIRS+=("$dir_key")
    fi
  fi
done < <(git log --reverse --diff-filter=R -M --name-status --format= "$RANGE" -- . ':!*.md')

mapfile -t DELETIONS < <(git log --diff-filter=D --name-only --format= "$RANGE" -- . ':!*.md' | sed '/^$/d' | sort -u)
mapfile -t ADDITIONS < <(git log --diff-filter=A --name-only --format= "$RANGE" -- . ':!*.md' | sed '/^$/d' | sort -u)

if [ "${#RENAME_PAIRS[@]}" -gt 0 ]; then
  RENAMES_JSON="$(json_renames "${RENAME_PAIRS[@]}")"
else
  RENAMES_JSON="$(jq -n '[]')"
fi
if [ "${#DELETIONS[@]}" -gt 0 ]; then
  DELETIONS_JSON="$(json_array_from_lines "${DELETIONS[@]}")"
else
  DELETIONS_JSON="$(jq -n '[]')"
fi
if [ "${#ADDITIONS[@]}" -gt 0 ]; then
  ADDITIONS_JSON="$(json_array_from_lines "${ADDITIONS[@]}")"
else
  ADDITIONS_JSON="$(jq -n '[]')"
fi

EMPTY_JSON="$(jq -n '[]')"

if [ "$DRY_RUN" = true ]; then
  build_summary "$RENAMES_JSON" "$DELETIONS_JSON" "$ADDITIONS_JSON" "$EMPTY_JSON" "$EMPTY_JSON"
  exit 0
fi

mkdir -p .git/interdoc
exec 9>.git/interdoc/fix.lock
if ! flock -n 9; then
  jq -n --arg error "another drift-fix instance is running" '{error: $error}'
  exit 1
fi

LINKS_FIXED_JSON="$(jq -n '[]')"
FILES_MODIFIED=()
declare -A MODIFIED_SET=()

mark_file_modified() {
  local file="$1"
  if [ -z "${MODIFIED_SET[$file]:-}" ]; then
    MODIFIED_SET[$file]=1
    FILES_MODIFIED+=("$file")
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

escape_sed_pattern() {
  printf '%s' "$1" | sed -e 's/[][\\/.*^$|?+(){}]/\\&/g'
}

replace_in_file() {
  local file="$1"
  local search="$2"
  local replace="$3"

  if [ "$search" = "$replace" ]; then
    return 1
  fi

  local tmp_file
  tmp_file="$(mktemp "${file}.tmp.XXXXXX")"

  local search_escaped
  local replace_escaped
  search_escaped="$(escape_sed_pattern "$search")"
  replace_escaped="$(escape_sed_replacement "$replace")"

  sed "s|${search_escaped}|${replace_escaped}|g" "$file" > "$tmp_file"

  if cmp -s "$file" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$file"
  mark_file_modified "$file"
  return 0
}

remove_deleted_entries() {
  local file="$1"
  local basename_deleted="$2"
  local tmp_file

  tmp_file="$(mktemp "${file}.tmp.XXXXXX")"

  awk -v target="$basename_deleted" '
    BEGIN {
      # Match target as whole filename: backtick-wrapped, after slash, or at line start
      bt = "`" target "`"
      sl = "/" target
    }
    {
      if ($0 ~ /^[[:space:]]*\|/ || $0 ~ /^[[:space:]]*-/) {
        if (index($0, bt) > 0 || index($0, sl) > 0) {
          next
        }
      }
      print $0
    }
  ' "$file" > "$tmp_file"

  if cmp -s "$file" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$file"
  mark_file_modified "$file"
  return 0
}

# Rename fixes: full-path replacement everywhere; basename replacement only in AGENTS.md
# under the same directory as the renamed file.
if [ "${#RENAME_PAIRS[@]}" -gt 0 ]; then
  for rename_pair in "${RENAME_PAIRS[@]}"; do
    old_path="${rename_pair%%$'\t'*}"
    new_path="${rename_pair#*$'\t'}"
    old_basename="$(basename "$old_path")"
    new_basename="$(basename "$new_path")"
    old_dir="$(dirname "$old_path")"
    new_dir="$(dirname "$new_path")"

    for agents_file in "${AGENTS_FILES[@]}"; do
      replace_in_file "$agents_file" "$old_path" "$new_path" || true

      agents_dir="$(dirname "${agents_file#./}")"
      if [ "$agents_dir" = "$old_dir" ] || [ "$agents_dir" = "$new_dir" ]; then
        replace_in_file "$agents_file" "$old_basename" "$new_basename" || true
      fi
    done
  done
fi

# Deletion fixes: only remove markdown table rows and bullet list items.
if [ "${#DELETIONS[@]}" -gt 0 ]; then
  for deleted_path in "${DELETIONS[@]}"; do
    deleted_basename="$(basename "$deleted_path")"
    for agents_file in "${AGENTS_FILES[@]}"; do
      remove_deleted_entries "$agents_file" "$deleted_basename" || true
    done
  done
fi

fix_broken_links() {
  local agents_file="$1"
  local file_dir_rel file_dir_abs grep_rc grep_output
  file_dir_rel="$(dirname "${agents_file#./}")"
  file_dir_abs="$REPO_ROOT/$file_dir_rel"

  # Strip fenced code blocks before extracting links to avoid false positives
  local filtered_content
  filtered_content="$(awk '/^```/{fence=!fence; next} !fence{print}' "$agents_file")"

  grep_rc=0
  grep_output="$(printf '%s\n' "$filtered_content" | grep -oE '\([^)]*AGENTS\.md([#?][^)]*)?\)')" || grep_rc=$?
  if [ "$grep_rc" -gt 1 ]; then
    echo "grep failed on $agents_file with exit code $grep_rc" >&2
    return 1
  fi

  local links_in_file
  mapfile -t links_in_file < <(printf '%s\n' "$grep_output" | sed -E 's/^\((.*)\)$/\1/' | sort -u)

  local link_value link_path link_suffix resolved_abs resolved_rel
  local best_old_dir best_new_dir old_dir new_dir candidate_rel new_link_path new_link_value
  for link_value in "${links_in_file[@]}"; do
    if [[ "$link_value" == /* ]] || [[ "$link_value" == *"://"* ]]; then
      continue
    fi

    link_path="$link_value"
    link_suffix=""
    if [[ "$link_value" == *"#"* ]]; then
      link_path="${link_value%%#*}"
      link_suffix="#${link_value#*#}"
    fi

    resolved_abs="$(realpath -m "$file_dir_abs/$link_path")"
    if [ -f "$resolved_abs" ]; then
      continue
    fi

    resolved_rel="$(realpath -m --relative-to="$REPO_ROOT" "$resolved_abs")"

    best_old_dir=""
    best_new_dir=""
    if [ "${#DIR_RENAME_PAIRS[@]}" -gt 0 ]; then
      for dir_pair in "${DIR_RENAME_PAIRS[@]}"; do
        old_dir="${dir_pair%%$'\t'*}"
        new_dir="${dir_pair#*$'\t'}"

        if [[ "$resolved_rel" == "$old_dir/"* ]] || [ "$resolved_rel" = "$old_dir" ]; then
          if [ "${#old_dir}" -gt "${#best_old_dir}" ]; then
            best_old_dir="$old_dir"
            best_new_dir="$new_dir"
          fi
        fi
      done
    fi

    if [ -z "$best_old_dir" ]; then
      continue
    fi

    candidate_rel="${resolved_rel/#$best_old_dir/$best_new_dir}"
    if [ ! -f "$REPO_ROOT/$candidate_rel" ]; then
      continue
    fi

    new_link_path="$(realpath -m --relative-to="$file_dir_abs" "$REPO_ROOT/$candidate_rel")"
    new_link_value="${new_link_path}${link_suffix}"

    if replace_in_file "$agents_file" "$link_value" "$new_link_value"; then
      LINKS_FIXED_JSON="$(jq -n \
        --argjson links "$LINKS_FIXED_JSON" \
        --arg file "$agents_file" \
        --arg old "$link_value" \
        --arg new "$new_link_value" \
        '$links + [{file: $file, old: $old, new: $new}]'
      )"
    fi
  done
}

# Cross-AGENTS.md link fixes for broken relative links when directories were renamed.
for agents_file in "${AGENTS_FILES[@]}"; do
  fix_broken_links "$agents_file" || true
done

if [ "${#FILES_MODIFIED[@]}" -gt 0 ]; then
  FILES_MODIFIED_JSON="$(json_array_from_lines "${FILES_MODIFIED[@]}")"
else
  FILES_MODIFIED_JSON="$(jq -n '[]')"
fi

build_summary "$RENAMES_JSON" "$DELETIONS_JSON" "$ADDITIONS_JSON" "$LINKS_FIXED_JSON" "$FILES_MODIFIED_JSON"
