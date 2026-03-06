#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH=""
TMP_FILE=""

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

main() {
  local install_dir
  local install_path
  local manifest_dir

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
}

main "$@"
