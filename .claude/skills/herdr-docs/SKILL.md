---
name: herdr-docs
description: >-
  Answer questions about herdr — the mouse-first terminal multiplexer / AI-coding-agent
  workspace manager at herdr.dev. Use whenever the user asks how to install, launch,
  configure, use, script, or troubleshoot herdr: keybindings, panes/tabs/workspaces/sessions,
  agents & agent states, integrations, the CLI, config.toml, the socket API, plugins, or
  remote/SSH usage. Provides a cached quick-reference for common answers and a routing table
  to the exact official doc page for everything else, so answers come from the right source fast.
---

# herdr docs navigator

Herdr is a terminal multiplexer (tmux/zellij family) built for running a whole *herd* of
AI coding agents at once — each in a real terminal pane — with a sidebar that surfaces which
agents are blocked/working/done. It is **mouse-first** but keeps a classic `ctrl+b` prefix and
detach/reattach. Official docs: <https://herdr.dev/docs/>.

## How to use this skill

1. **Answer from the Cached quick-reference below** for common questions (concepts, keybindings,
   essential CLI, install). No fetch needed — it's fast and already verified.
2. **When the answer isn't cached, or precision matters** (exact flags, defaults, edge cases,
   less-common commands), `WebFetch` the **one** page from the Routing table that owns that topic.
   Don't search — go straight to the mapped URL.
3. **Always cite** the doc page(s) used as markdown links at the end of the answer.
4. **Prefer teaching mouse actions first** for newcomers (click to focus, drag borders to resize,
   right-click menus), then give the keyboard fast-path.

### Rules (from herdr's own agent guide)
- **Never invent** commands, flags, or config keys. If it's not cached and not in the mapped page,
  say so and fetch to confirm rather than guessing.
- **Never give tmux/zellij commands** as an answer to a herdr question — herdr has its own keys/CLI.
- Docs default to the **stable** channel URLs below. If the user says they're on the *preview*
  channel (`herdr channel set preview`), swap `/docs/` → `/docs/preview/` in the same path.

## Routing table — topic → authoritative page

| Ask about… | Fetch this page |
|---|---|
| Overview / what herdr is / doc index | https://herdr.dev/docs/ |
| Install, package managers, updates, channels | https://herdr.dev/docs/install/ |
| First run, launch, first agent, basic keys | https://herdr.dev/docs/quick-start/ |
| Concepts: session/workspace/tab/pane/agent/modes | https://herdr.dev/docs/concepts/ |
| Local vs SSH vs remote thin-client workflows | https://herdr.dev/docs/how-to-work/ |
| Multi-agent use, detection, agent states | https://herdr.dev/docs/agents/ |
| Agent hook integrations (claude, copilot, pi…) | https://herdr.dev/docs/integrations/ |
| **All keybindings & defaults** | https://herdr.dev/docs/keyboard/ |
| config.toml guide (themes, notifications, sidebar) | https://herdr.dev/docs/configuration/ |
| **Full config reference** (every key + default) | https://herdr.dev/docs/config-reference/ |
| **Full CLI command list** | https://herdr.dev/docs/cli-reference/ |
| Socket API (JSON over local socket) for scripting | https://herdr.dev/docs/socket-api/ |
| Detach/restart/restore, pane history replay | https://herdr.dev/docs/session-state/ |
| Persistence & remote access details | https://herdr.dev/docs/persistence-remote/ |
| Plugins (authoring/installing) | https://herdr.dev/docs/plugins/ |
| Plugin marketplace | https://herdr.dev/docs/marketplace/ |
| Troubleshooting, logs, diagnosis | https://herdr.dev/docs/troubleshooting/ |
| Windows (beta) notes | https://herdr.dev/docs/windows-beta/ |
| herdr's own SKILL.md for driving panes from an agent | https://herdr.dev/docs/agent-skill/ |

**Extra authoritative sources**
- Agent-oriented overview (great for quick fact-checks): <https://herdr.dev/agent-guide.md>
- Herdr's runtime-control skill (drive panes from *inside* herdr, guarded by `HERDR_ENV=1`):
  <https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md>
- Source & releases: <https://github.com/ogulcancelik/herdr>

## Cached quick-reference (verified from official docs)

### Concept model (nesting order)
`session` → `workspace` → `tab` → `pane` → `agent`.
- **Session** — isolated background namespace (own panes, socket, state); you usually use the default.
- **Workspace** — top-level project container; **one per repo / task / investigation**.
- **Tab** — a layout inside a workspace (agents / logs / server / review); addressable from CLI.
- **Pane** — a *real* terminal process; splittable right or down; survives client detach.
- **Agent** — a recognized process in a pane; state rolls up through tabs → workspaces in the sidebar.
- **Architecture** — a background **server** (keeps panes/agents alive) + one or more **clients** (render).
- **Modes** — terminal mode (keys go to pane), prefix mode (after `ctrl+b`), navigate mode.

### Agent states
`blocked` (needs your input/approval) · `working` (running) · `done` (finished, unseen) ·
`idle` (finished/waiting, seen) · `unknown` (unclassified). Detection is via **lifecycle hooks**
(install an integration) or **screen-manifest** reading; `blocked` matching is intentionally strict.

### Keybindings (default prefix `ctrl+b`)
Note herdr names splits by the *divider* orientation (opposite of intuition): "split right" =
`split_vertical`, "split down" = `split_horizontal`.

| Keys | Action |
|---|---|
| `ctrl+b` `v` | Split **right** (`split_vertical`) |
| `ctrl+b` `-` | Split **down** (`split_horizontal`) |
| `ctrl+b` `h` / `j` / `k` / `l` | Focus pane left / down / up / right |
| `ctrl+b` `shift`+`h`/`j`/`k`/`l` | Swap/move pane in that direction |
| `ctrl+b` `z` | Zoom (fullscreen) focused pane |
| `ctrl+b` `r` | Resize mode (then `h/j/k/l`) |
| `ctrl+b` `x` | Close pane |
| `ctrl+b` `c` | New tab |
| `ctrl+b` `n` / `p` | Next / previous tab |
| `ctrl+b` `g` | Goto / navigate mode |
| `ctrl+b` `q` | Detach client (server keeps running) |
| `ctrl+b` `?` | Show all keybindings |

Mouse-first alternatives: click to focus panes/tabs/agents; drag borders to resize; right-click for
context menus; drag-select to copy; double-click a token to copy it.

### Install & update
```bash
curl -fsSL https://herdr.dev/install.sh | sh    # Linux/macOS
brew install herdr                              # Homebrew
mise use -g herdr                               # mise
# Windows (preview beta):
#   powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
herdr update                                    # update a direct install
herdr channel set preview|stable                # switch release channel
```

### Essential CLI (see cli-reference for the full set)
```bash
herdr                          # launch / attach default session
herdr --session <name>         # named session
herdr --remote <host>          # thin client over SSH (local keybindings/clipboard)
herdr status                   # server/client status
herdr server stop              # stop server + all panes
herdr server reload-config     # apply config.toml changes live

herdr workspace list|create|focus|rename|close
herdr tab list|create|focus|rename|close
herdr pane split --direction right|down
herdr pane focus --direction left|right|up|down
herdr pane read <id> [--source visible|recent|recent-unwrapped|detection]
herdr pane run <id> "<command>"        # run a command (with Enter) without stealing focus
herdr pane send-text|send-keys <id> ...

herdr agent list                       # detected/active agents + states
herdr agent start <name> --cwd <dir> --split right -- <cmd>
herdr agent attach <target>            # detach with ctrl+b q
herdr agent wait <target> --status blocked|working|idle|unknown
herdr agent explain <target> --json    # why herdr classified this state

herdr integration install <claude|copilot|pi|...>   # hook-based state (better than screen detection)
herdr integration status
```

### Config
- File: `~/.config/herdr/config.toml` (Linux/macOS) · `%APPDATA%\herdr\config.toml` (Windows).
- Print defaults: `herdr --default-config` · reload live: `herdr server reload-config`.
- Main sections: `[terminal]`, `[keys]` (+ `[[keys.command]]` for custom popup/pane/shell/plugin
  commands), `[theme]` (built-ins + `auto_switch`), `[ui]` (toast/sound/sidebar rows), `[worktrees]`,
  `[session]`, `[experimental]`.
- Env vars: `HERDR_CONFIG_PATH`, `HERDR_SESSION`, `HERDR_LOG` (e.g. `herdr=debug`), `HERDR_DISABLE_SOUND`.
- Logs: `~/.config/herdr/herdr.log`, `herdr-server.log`, `herdr-client.log`.

### Notifications & sound (agent-finished alerts)
Verified against config-reference + live `herdr` 0.7.4.
- **Sound** (`[ui.sound]`): `enabled` (bool, default `true`) — plays on agent state change in
  *background* workspaces. `path` / `done_path` / `request_path` = optional MP3 overrides (all/done/blocked).
  Env `HERDR_DISABLE_SOUND` mutes globally.
- **Per-agent sound** (`[ui.sound.agents]`): `claude`/`codex`/`gemini`/… = `"default"|"on"|"off"`
  (e.g. `claude = "off"`; `droid` defaults `"off"`).
- **Toasts** (`[ui.toast]`): `delivery` (default `"off"`) = `"off"|"herdr"` (in-app frame) `|"terminal"`
  (outer terminal) `|"system"` (native OS toast — on Windows/WSL this is a **Windows toast via WSLg**).
  `delay_seconds` (int, default `1`, 0–3600). In-app position via `[ui.toast.herdr] position` (default `"bottom-right"`).
- **CLI test**: `herdr notification show <title> [--body TEXT] [--position …] [--sound none|done|request]`
  — uses the configured `[ui.toast] delivery`; `--sound` defaults to `none`. Returns `{"shown":true,"reason":"shown"}`
  or `{"shown":false,"reason":"busy"}`. `busy` = the client is *transiently* busy right after any UI-changing
  call (`reload-config`, tab create/close, or a preceding `notification show`) — NOT tied to which tab is
  focused; wait a moment and fire once more (don't double-fire, that re-arms busy). There is **no `--force`**.
- **`system` on WSL is a dead end (verified on WSLg, herdr 0.7.4)**: the *client* emits the OS toast via the
  Linux `org.freedesktop.Notifications` D-Bus interface. WSLg provides **no** notification daemon
  (`ServiceUnknown: org.freedesktop.Notifications ... not provided`) and there's no `notify-send`, so herdr
  returns `shown:true` but nothing appears. Use `delivery = "herdr"` (in-app, always renders) instead. A real
  Windows toast requires an external bridge (e.g. `wsl-notify-send.exe`, or a `powershell.exe` BurntToast call
  from an agent hook) — herdr's built-in `system` delivery will not reach Windows on its own.
- **WSL recommended combo**: WSL audio (PulseAudio/WSLg) makes the finish *sound* crackle — set
  `[ui.sound] enabled = false` and `delivery = "herdr"` for a silent, reliable in-app alert.

## Maintenance
Herdr ships frequently. If a cached fact ever conflicts with a freshly fetched page, **the fetched
page wins** — trust it and update this file. Refresh the routing table if the sitemap
(<https://herdr.dev/sitemap-0.xml>) adds/removes doc pages.
