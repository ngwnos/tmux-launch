# tmux-launch

Minimal tmux project launcher.

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
