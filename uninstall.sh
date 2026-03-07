#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH=""
REMOVE_ENTRY=0
REMOVE_DEFAULT_TMUXP=0
NON_INTERACTIVE=0

TMUX_PROJECT_LIST="${TMUX_PROJECT_LIST_FILE:-$HOME/.tmuxp-projects}"

usage() {
  cat <<'EOF'
Usage:
  bash uninstall.sh [options]

Options:
  --project-path <dir>      project directory to remove from manifest
  --remove-entry            remove --project-path entry from manifest
  --remove-default-tmuxp    remove <project-path>/.tmuxp if it exists
  --non-interactive         fail instead of prompting on missing values
  -h, --help                show this help
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

normalize_abs_path() {
  local path="$1"
  if [[ "$path" == "~/"* ]]; then
    path="${HOME}${path#\~}"
  fi
  if [[ "$path" != /* ]]; then
    path="$(pwd -P)/$path"
  fi
  (cd "$path" && pwd -P)
}

choose_install_dir() {
  if [[ -n "${TMUX_LAUNCH_INSTALL_DIR:-}" ]]; then
    printf '%s\n' "$TMUX_LAUNCH_INSTALL_DIR"
    return 0
  fi

  if [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
    printf '%s\n' "$HOME/bin"
    return 0
  fi

  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    printf '%s\n' "$HOME/.local/bin"
    return 0
  fi

  printf '%s\n' "$HOME/bin"
}

prompt_if_needed() {
  local prompt="$1"
  local var_name="$2"
  local current="${!var_name:-}"
  [[ -n "$current" ]] && return 0
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt" current
  printf -v "$var_name" '%s' "$current"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-path)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --project-path"
        PROJECT_PATH="$1"
        ;;
      --remove-entry) REMOVE_ENTRY=1 ;;
      --remove-default-tmuxp) REMOVE_DEFAULT_TMUXP=1 ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done
}

remove_manifest_entry() {
  local manifest="$1"
  local entry="$2"
  local tmp

  [[ -f "$manifest" ]] || {
    printf 'Manifest not found, skipping entry removal: %s\n' "$manifest"
    return 0
  }

  tmp="$(mktemp "${TMPDIR:-/tmp}/tmux-projects.XXXXXX")"
  awk -v needle="$entry" '
    {
      line=$0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == needle) next
      print $0
    }
  ' "$manifest" >"$tmp"
  mv "$tmp" "$manifest"
  printf 'Removed manifest entry if present: %s\n' "$entry"
}

main() {
  local install_dir
  local install_path
  local resolved_project_path=""
  local tmuxp_path=""

  parse_args "$@"

  install_dir="$(choose_install_dir)"
  install_path="$install_dir/tmux-launch"

  if [[ -f "$install_path" ]]; then
    rm -f "$install_path"
    printf 'Removed binary: %s\n' "$install_path"
  else
    printf 'Binary not found, skipping: %s\n' "$install_path"
  fi

  if [[ "$REMOVE_ENTRY" -eq 1 || "$REMOVE_DEFAULT_TMUXP" -eq 1 ]]; then
    prompt_if_needed "Project path: " PROJECT_PATH
    [[ -n "$PROJECT_PATH" ]] || die "--project-path is required for project cleanup flags"
    [[ -d "$PROJECT_PATH" ]] || die "Project directory not found: $PROJECT_PATH"
    resolved_project_path="$(normalize_abs_path "$PROJECT_PATH")"
    tmuxp_path="$resolved_project_path/.tmuxp"
  fi

  if [[ "$REMOVE_ENTRY" -eq 1 ]]; then
    remove_manifest_entry "$TMUX_PROJECT_LIST" "$resolved_project_path"
  fi

  if [[ "$REMOVE_DEFAULT_TMUXP" -eq 1 ]]; then
    if [[ -f "$tmuxp_path" ]]; then
      rm -f "$tmuxp_path"
      printf 'Removed project manifest: %s\n' "$tmuxp_path"
    else
      printf 'Project manifest not found, skipping: %s\n' "$tmuxp_path"
    fi
  fi

  printf 'tmux-launch uninstall complete.\n'
}

main "$@"
