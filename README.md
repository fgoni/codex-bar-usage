# Codex Bar Usage

Small macOS menu bar companion for CodexBar. It shows the 5h reset countdowns for Claude and Codex directly in the menu bar.

The app reads data through the CodexBar CLI:

- Codex: `codexbar usage --provider codex --format json --source cli`
- Claude: `codexbar usage --provider claude --format json --source oauth`

The menu bar title is compact:

```text
[Claude icon] 2h20m   [Codex icon] 1h48m
```

## Human Guidelines

Use `make install` for local installs. It copies the app to `/Applications/CodexBarResetBar.app` and opens it.

## Agent Guidelines

After changing app behavior, resources, packaging, or menu bar rendering, run the tests and install the app so the local menu bar copy reflects the change:

```bash
make test
make install
```

## Commands

```bash
make test
make icon
make app
make install
```

`make install` copies the app to `/Applications/CodexBarResetBar.app` and opens it.
