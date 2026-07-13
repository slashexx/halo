# Halo

A fast, glassy **pie / radial menu and automation tool for macOS**. Summon a menu
with a gesture and launch apps, run scripts, insert text, simulate shortcuts,
manage windows, and chain multi-step workflows — everything at your cursor.

Native **Swift + SwiftUI**, targeting **macOS 26 (Tahoe)** so it can use the real
Liquid Glass materials. Built with the Swift Package Manager — **no Xcode
required** to develop.

> Status: early development. See the roadmap below.

## Requirements

- macOS 26+
- Swift 6.0+ toolchain (`swift --version`) — Xcode _or_ Command Line Tools

## Build & run

```bash
# Build, assemble Halo.app, and run it with logs in this terminal:
./scripts/run.sh

# Or just build the .app bundle:
./scripts/bundle.sh          # debug
./scripts/bundle.sh release  # optimized
```

Halo runs as a **menu-bar agent** (no Dock icon). **Press ⌥Tab** (Option+Tab) to
open the menu; press it again, hit Esc, or click outside to dismiss. Quit from the
menu-bar icon or with `Ctrl-C` in the terminal.

### Permissions

The ⌥Tab trigger is a Carbon hot key and needs **no permissions**. Later phases
add actions that inject keystrokes or move windows; those will request
**Accessibility** the first time they're used. (Because the dev build is ad-hoc
signed, its signature changes each build, so macOS may re-ask for Accessibility
after a rebuild.)

## Architecture (target)

- **Overlay** — borderless transparent floating `NSPanel` summoned at the cursor
  or screen center, hosting a SwiftUI radial menu with Liquid Glass materials.
- **Trigger** — global hot key (⌥Tab).
- **Model** — `Codable` menus; an item is either an *action* or a *sub-menu*.
  Persisted as JSON; presets are shareable JSON files.
- **Actions** — 16 building blocks behind an `Action` protocol (`execute()`):
  launch app, open URL/file, keyboard shortcut, insert text, run script,
  window management, system actions, chain, …
- **Context** — picks a per-app menu based on the frontmost application.
- **Editor** — SwiftUI window to build menus visually.

## Roadmap

- [x] **Phase 0** — project scaffold (SwiftPM, bundle script, menu-bar agent)
- [x] **Phase 1** — glass radial overlay + global trigger
- [ ] **Phase 2** — action engine + core actions
- [ ] **Phase 3** — menu model, persistence, sub-menus, chaining
- [ ] **Phase 4** — context-aware menus
- [ ] **Phase 5** — remaining actions (window mgmt, system, app switcher)
- [ ] **Phase 6** — visual editor UI
- [ ] **Phase 7** — preset import/export, polish, docs

## License

MIT — see [LICENSE](LICENSE).
