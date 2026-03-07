#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH=""
TMP_FILE=""
PROJECT_PATH=""
ENSURE_ENTRY=0
WRITE_DEFAULT_TMUXP=0
NON_INTERACTIVE=0

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  case "${BASH_SOURCE[0]}" in
    /dev/fd/*|/proc/self/fd/*)
      ;;
    *)
      if [[ -f "${BASH_SOURCE[0]}" ]]; then
        SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
      fi
      ;;
  esac
fi

cleanup() {
  if [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]]; then
    rm -f "$TMP_FILE"
  fi
  case "$SCRIPT_PATH" in
    "${TMPDIR:-/tmp}"/*|/tmp/*)
      if [[ -f "$SCRIPT_PATH" ]]; then
        rm -f "$SCRIPT_PATH"
      fi
      ;;
  esac
}

trap cleanup EXIT

REPO_OWNER="${TMUX_LAUNCH_REPO_OWNER:-ngwnos}"
REPO_NAME="${TMUX_LAUNCH_REPO_NAME:-tmux-launch}"
REPO_REF="${TMUX_LAUNCH_REPO_REF:-main}"
TMUX_LAUNCH_URL="${TMUX_LAUNCH_URL:-https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REPO_REF/tmux-launch}"
TMUX_PROJECT_LIST="${TMUX_PROJECT_LIST_FILE:-$HOME/.tmuxp-projects}"

usage() {
  cat <<'EOF'
Usage:
  bash install.sh [options]

Options:
  --project-path <dir>    project directory to add to manifest
  --ensure-entry          ensure --project-path exists once in manifest
  --write-default-tmuxp   create <project-path>/.tmuxp if missing
  --non-interactive       fail instead of prompting on missing values
  -h, --help              show this help
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

project_basename() {
  local path="$1"
  basename "$path"
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

choose_install_dir() {
  if [[ -n "${TMUX_LAUNCH_INSTALL_DIR:-}" ]]; then
    printf '%s\n' "$TMUX_LAUNCH_INSTALL_DIR"
    return 0
  fi

  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    printf '%s\n' "$HOME/.local/bin"
    return 0
  fi

  if [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
    printf '%s\n' "$HOME/bin"
    return 0
  fi

  printf '%s\n' "$HOME/.local/bin"
}

fetch_launcher() {
  local source_url="$1"
  local output_path="$2"

  case "$source_url" in
    file://*)
      cp "${source_url#file://}" "$output_path"
      ;;
    *)
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$source_url" -o "$output_path"
      elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output_path" "$source_url"
      else
        echo "curl or wget is required to download tmux-launch" >&2
        return 1
      fi
      ;;
  esac
}

ensure_manifest_entry() {
  local manifest="$1"
  local entry="$2"
  local tmp

  touch "$manifest"
  if sed -E 's/[[:space:]]+$//; s/^[[:space:]]+//' "$manifest" | grep -Fxq "$entry"; then
    printf 'Manifest already contains: %s\n' "$entry"
    return 0
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/tmux-projects.XXXXXX")"
  cp "$manifest" "$tmp"
  if [[ -s "$tmp" ]]; then
    printf '\n' >>"$tmp"
  fi
  printf '%s\n' "$entry" >>"$tmp"
  mv "$tmp" "$manifest"
  printf 'Added manifest entry: %s\n' "$entry"
}

write_default_tmuxp_manifest() {
  local project_dir="$1"
  local tmuxp_path="$project_dir/.tmuxp"
  local session_name="$2"

  if [[ -f "$tmuxp_path" ]]; then
    printf 'Project manifest already exists: %s\n' "$tmuxp_path"
    return 0
  fi

  cat >"$tmuxp_path" <<EOF
{
  "session": "$session_name",
  "root": "$project_dir",
  "status_action": "vite-bun",
  "windows": [
    {
      "name": "$session_name",
      "layout": "vertical",
      "panes": [
        { "name": "start", "percent": 10, "command": "bun run dev", "cwd": "." },
        { "name": "codex", "percent": 90, "command": "codex resume", "cwd": "." }
      ]
    }
  ]
}
EOF
  printf 'Wrote default project manifest: %s\n' "$tmuxp_path"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-path)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --project-path"
        PROJECT_PATH="$1"
        ;;
      --ensure-entry) ENSURE_ENTRY=1 ;;
      --write-default-tmuxp) WRITE_DEFAULT_TMUXP=1 ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done
}

main() {
  local install_dir
  local install_path
  local manifest_dir
  local resolved_project_path=""
  local session_name=""

  parse_args "$@"

  install_dir="$(choose_install_dir)"
  install_path="$install_dir/tmux-launch"
  manifest_dir="$(dirname "$TMUX_PROJECT_LIST")"

  mkdir -p "$install_dir"
  mkdir -p "$manifest_dir"

  TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/tmux-launch.XXXXXX")"
  fetch_launcher "$TMUX_LAUNCH_URL" "$TMP_FILE"
  chmod +x "$TMP_FILE"
  mv "$TMP_FILE" "$install_path"
  TMP_FILE=""

  touch "$TMUX_PROJECT_LIST"

  printf 'Installed tmux-launch to %s\n' "$install_path"
  printf 'Manifest file is %s\n' "$TMUX_PROJECT_LIST"

  if [[ ":$PATH:" != *":$install_dir:"* ]]; then
    printf 'Add %s to PATH to run tmux-launch directly.\n' "$install_dir"
  fi

  printf 'Runtime requirements: tmux and jq\n'

  if [[ "$ENSURE_ENTRY" -eq 1 || "$WRITE_DEFAULT_TMUXP" -eq 1 ]]; then
    prompt_if_needed "Project path: " PROJECT_PATH
    [[ -n "$PROJECT_PATH" ]] || die "--project-path is required for project setup flags"
    [[ -d "$PROJECT_PATH" ]] || die "Project directory not found: $PROJECT_PATH"
    resolved_project_path="$(normalize_abs_path "$PROJECT_PATH")"
    session_name="$(project_basename "$resolved_project_path")"
  fi

  if [[ "$ENSURE_ENTRY" -eq 1 ]]; then
    ensure_manifest_entry "$TMUX_PROJECT_LIST" "$resolved_project_path"
  fi

  if [[ "$WRITE_DEFAULT_TMUXP" -eq 1 ]]; then
    write_default_tmuxp_manifest "$resolved_project_path" "$session_name"
  fi
}

main "$@"
