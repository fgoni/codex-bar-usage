# Codex Bar Usage

Small macOS menu bar companion for CodexBar. It shows the 5h reset countdowns for Claude and Codex directly in the menu bar.

The app reads data through the CodexBar CLI:

- Codex: `codexbar usage --provider codex --format json --source cli`
- Claude: `codexbar usage --provider claude --format json --source oauth`

The menu bar title is compact:

```text
Cl 2h20m | Cx 1h48m
```

## Commands

```bash
make test
make icon
make app
make install
```

`make install` copies the app to `/Applications/CodexBarResetBar.app` and opens it.
