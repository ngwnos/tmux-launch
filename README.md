# tmux-launch

Minimal tmux project launcher.

## Install

This installs `tmux-launch`, creates `~/.tmuxp-projects` if it does not exist,
and removes the downloaded installer when it exits.

```bash
tmp="$(mktemp)" && wget -qO "$tmp" https://raw.githubusercontent.com/ngwnos/tmux-launch/main/install.sh && bash "$tmp"
```

The installer picks `~/.local/bin` if it is already on `PATH`, otherwise `~/bin`
if it is on `PATH`, otherwise it falls back to `~/.local/bin`.

Runtime requirements: `tmux` and `jq`

## Usage

```bash
tmux-launch
tmux-launch <project-name|project-path|session-name>
```

## Manifest

- Default manifest file: `~/.tmuxp-projects`
- One entry per line
- Each entry is either:
- absolute path to a `.tmuxp` file
- project directory containing `.tmuxp`

## Minimal `.tmuxp` example

```json
{
  "session": "my-project",
  "root": "/absolute/path/to/my-project",
  "windows": [
    {
      "name": "my-project",
      "layout": "vertical",
      "panes": [
        { "name": "start", "percent": 10, "command": "bun run dev", "cwd": "." },
        { "name": "codex", "percent": 90, "command": "codex resume", "cwd": "." }
      ]
    }
  ]
}
```
