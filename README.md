# tmux-launch

Minimal tmux project launcher.

## Install

This installs `tmux-launch`, creates `~/.tmuxp-projects` if it does not exist,
and removes the downloaded installer when it exits.

```bash
tmp="$(mktemp)" && wget -qO "$tmp" https://raw.githubusercontent.com/ngwnos/tmux-launch/main/install.sh && bash "$tmp"
```

The installer picks `~/bin` if it is already on `PATH`, otherwise `~/.local/bin`
if it is on `PATH`, otherwise it falls back to `~/bin`.

Runtime requirements: `tmux` and `jq`

## Installer Flags

`install.sh` now supports one-shot project setup:

```bash
bash install.sh \
  --project-path /absolute/path/to/project \
  --ensure-entry \
  --write-default-tmuxp \
  --non-interactive
```

Flags:

- `--project-path <dir>`: project directory for manifest/setup actions
- `--ensure-entry`: ensure project directory exists exactly once in `~/.tmuxp-projects`
- `--write-default-tmuxp`: create `<project-path>/.tmuxp` if it does not exist
- `--non-interactive`: fail instead of prompting for missing values

## Uninstall

Repeatable uninstall/reset for testing:

```bash
bash uninstall.sh \
  --project-path /absolute/path/to/project \
  --remove-entry \
  --remove-default-tmuxp \
  --non-interactive
```

This removes:

- installed `tmux-launch` binary
- project entry from `~/.tmuxp-projects` (if `--remove-entry`)
- project `.tmuxp` file (if `--remove-default-tmuxp`)

## Usage

```bash
tmux-launch
tmux-launch <project-name|project-path|session-name>
tmux-launch status [project-name|project-path|session-name]
```

## Manifest

- Default manifest file: `~/.tmuxp-projects`
- Default recency state file: `~/.tmuxp-projects.state`
- One entry per line
- Each entry is either:
- absolute path to a `.tmuxp` file
- project directory containing `.tmuxp`
- the project list is local machine state; repo-level `.tmuxp` files can stay portable
- `tmux-launch` keeps the manifest as a plain list and stores last-launched
  timestamps in the separate state file so the picker can sort projects by
  recency.

## Minimal `.tmuxp` example

```json
{
  "session": "my-project",
  "root": ".",
  "status_action": "vite-bun",
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

`"root": "."` keeps the project manifest portable. You can also omit `root`
entirely and `tmux-launch` will use the manifest's parent directory.

## Status

`tmux-launch status` with no query reports status for all running sessions in
recency order.

`tmux-launch status <project>` reports status for one project.

For common projects, prefer a built-in action in `.tmuxp`:

- `status_action: "vite-bun"`: finds the listening port owned by the session's
  `start` pane process tree and prints a local Vite URL.

`vite-bun` currently relies on `ss`, so it is most reliable on Linux. On other
systems, prefer `status_command` for project-specific status output.

For custom projects, use `status_command` instead. If both are present,
`status_command` wins.

Example custom command:

```json
{
  "status_command": "bun run tmux-status"
}
```

Custom commands receive these env vars:

- `TMUX_LAUNCH_SESSION`
- `TMUX_LAUNCH_ROOT`
- `TMUX_LAUNCH_MANIFEST`
- `TMUX_LAUNCH_PROJECT_LIST`
- `TMUX_LAUNCH_PROJECT_STATE_FILE`

Use `status_command` to print anything project-specific, such as API health,
tunnel URLs, or multi-service output.
