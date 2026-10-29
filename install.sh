#!/usr/bin/env bash
# Adds (or removes) the lazygit-hunk keybindings in your lazygit config.
# Safe to re-run: the managed block is replaced in place.

set -euo pipefail

START_MARKER="# >>> lazygit-hunk >>>"
END_MARKER="# <<< lazygit-hunk <<<"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--key <key>] [--config <path>] [--uninstall]

  --key <key>      key that opens the hunk menu (default: X)
  --config <path>  lazygit config file to edit (default: the one lazygit loads)
  --uninstall      remove the lazygit-hunk block from the config
EOF
}

die() {
  echo "install.sh: $*" >&2
  exit 1
}

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
bin="$repo_dir/bin/lazygit-hunk"
template="$repo_dir/lazygit-hunk.yml"

key="X"
config=""
uninstall=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) key=${2:?--key needs a value}; shift 2 ;;
    --config) config=${2:?--config needs a value}; shift 2 ;;
    --uninstall) uninstall=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

default_config() {
  if [[ -n "${LG_CONFIG_FILE:-}" ]]; then
    echo "${LG_CONFIG_FILE%%,*}"
  elif command -v lazygit >/dev/null; then
    echo "$(lazygit --print-config-dir)/config.yml"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "$HOME/Library/Application Support/lazygit/config.yml"
  else
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"
  fi
}

without_block() {
  awk -v start="$START_MARKER" -v end="$END_MARKER" '
    { trimmed = $0; sub(/^[ \t]+/, "", trimmed) }
    trimmed == start { skipping = 1; next }
    trimmed == end { skipping = 0; next }
    !skipping { print }
  ' "$1"
}

# Prints the template with placeholders filled in and every line prefixed by $1.
render_block() {
  local indent=$1 line
  printf '%s%s\n' "$indent" "$START_MARKER"
  while IFS= read -r line; do
    [[ "$line" == \#* ]] && continue
    line=${line//__KEY__/$key}
    line=${line//__BIN__/\'$bin\'}
    if [[ -z "$line" ]]; then
      echo
    else
      printf '%s%s\n' "$indent" "$line"
    fi
  done <"$template"
  printf '%s%s\n' "$indent" "$END_MARKER"
}

# Width of the indentation of the first list item under the top-level customCommands key.
item_indent_width() {
  awk '
    found && /^[ \t]*(#|$)/ { next }
    found {
      if (match($0, /^ *- /)) { print RLENGTH - 2 } else { print 2 }
      exit
    }
    /^customCommands:/ { found = 1 }
  ' "$1"
}

validate() {
  command -v ruby >/dev/null || return 0
  ruby -ryaml -e '
    doc = YAML.safe_load(File.read(ARGV[0])) || {}
    abort "customCommands is not a list" unless doc["customCommands"].is_a?(Array)
  ' "$1"
}

[[ "$bin" != *\'* ]] || die "the repo path can't contain a single quote: $repo_dir"
[[ "$key" != *\"* ]] || die "the key can't contain a double quote"

config=${config:-$(default_config)}
mkdir -p "$(dirname "$config")"
touch "$config"

tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp.new"' EXIT
without_block "$config" >"$tmp"

if [[ -n "$uninstall" ]]; then
  cp "$tmp" "$config"
  echo "Removed lazygit-hunk from $config"
  exit 0
fi

if grep -qE '^customCommands:[[:space:]]*(#.*)?$' "$tmp"; then
  indent=$(printf '%*s' "$(item_indent_width "$tmp")" "")
  BLOCK=$(render_block "$indent") awk '
    { print }
    /^customCommands:/ && !done { print ENVIRON["BLOCK"]; done = 1 }
  ' "$tmp" >"$tmp.new"
elif grep -qE '^customCommands:[[:space:]]*\[[[:space:]]*\][[:space:]]*$' "$tmp"; then
  BLOCK=$(render_block "  ") awk '
    /^customCommands:/ && !done { print "customCommands:"; print ENVIRON["BLOCK"]; done = 1; next }
    { print }
  ' "$tmp" >"$tmp.new"
elif grep -qE '^customCommands:' "$tmp"; then
  die "customCommands in $config uses inline [...] syntax; convert it to a block list (one '- key:' per line) and re-run"
else
  {
    cat "$tmp"
    [[ ! -s "$tmp" || -z "$(tail -c 1 "$tmp")" ]] || echo
    echo "$START_MARKER"
    echo "customCommands:"
    render_block "  " | sed '1d;$d'
    echo "$END_MARKER"
  } >"$tmp.new"
fi

validate "$tmp.new" || die "the result didn't parse as valid YAML, so $config was left unchanged"

cp "$config" "$config.bak"
cp "$tmp.new" "$config"

echo "Installed lazygit-hunk into $config (backup: $config.bak)"
echo "Press '$key' in lazygit to open the hunk menu."

command -v hunk >/dev/null || echo "Warning: hunk isn't on your PATH (brew install hunk)."
command -v gh >/dev/null || echo "Note: without the gh CLI, PRs only work for the checked-out branch."
