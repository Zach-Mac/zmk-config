# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **personal ZMK firmware configuration**, forked from [urob/zmk-config](https://github.com/urob/zmk-config). It retains the core "timeless homerow mods" architecture and helper modules from the upstream repo, but has been customized with personal keymaps, combos, and layer configurations.

**Important notes:**
- `readme.md` is the **unchanged original from urob's repo** - serves as excellent reference documentation for understanding the design philosophy and techniques used
- The actual configuration (keymap, combos, layers) has diverged from urob's original
- urob's repo and documentation remain the authoritative reference for the underlying architecture

## Quick Start Commands

### Build & Development
```bash
just init              # Initialize west workspace (one-time setup)
just build all         # Build all targets from build.yaml
just build zen         # Build specific target (zen_left + zen_right)
just build planck      # Build specific board
just clean             # Clear build artifacts
just clean-all         # Remove build directory entirely
just draw              # Generate keymap visualization (draw/base.svg)
just list              # List all available build targets
just update            # Update ZMK/Zephyr dependencies
just upgrade-sdk       # Upgrade Nix packages (use cautiously)
```

### Testing
```bash
just test zmk/app/tests/conditional-layer/  # Run single test
just test zmk/app/tests/conditional-layer/ --verbose
just test zmk/app/tests/conditional-layer/ --auto-accept  # Update snapshots
```

### Development Environment
```bash
direnv allow           # Automatically load Nix environment (first time)
# Environment auto-loads on cd after initial direnv allow
```

## Architecture Overview

This is a sophisticated ZMK (Zephyr Mechanical Keyboard) firmware configuration workspace with three main layers:

### 1. **Firmware Layer** (ZMK v0.2 + Zephyr v3.5.0+zmk-fixes)
- Located in `zmk/` (git submodule)
- Written in C with devicetree bindings
- Implements keyboard behavior, layer management, combos, Bluetooth, USB
- Key components: `zmk/app/src/behaviors/`, `zmk/app/src/keymap.c`, `zmk/app/src/combo.c`
- Tests run via native_posix_64 emulation (compiles to Linux binary)

### 2. **Custom Modules Layer**
- `modules/zmk-helpers/` - Macro syntax for simplified keymap definitions
- `modules/zmk-auto-layer/` - Smart layer auto-deactivation (Numword)
- `modules/zmk-leader-key/` - Leader key sequences with Unicode support
- `modules/zmk-adaptive-key/` - Context-aware key behaviors
- `modules/zmk-tri-state/` - Alt-Tab window switcher

All modules are git submodules pinned in `config/west.yml`.

### 3. **User Configuration Layer** (`config/`)
- **Keymap**: `config/base.keymap` (843 lines, 14 layers)
- **Combos**: `config/combos.dtsi` (50+ key combinations)
- **Other configs**: `leader.dtsi`, `mouse.dtsi`, `corne.conf`
- **Visualization**: `draw/config.yaml` + `keymap-drawer` tool

## Build System

**Primary tools**: West (manifest-based source management) + Ninja/CMake + Just (recipes)

**Build flow**:
1. Keymap files (`*.keymap`, `*.dtsi`) → parsed by ZMK app
2. `_parse_combos` task auto-configures `CONFIG_ZMK_COMBO_MAX_*` from combos.dtsi
3. West invokes CMake/Ninja with Zephyr as build system
4. ARM compiler targets nRF52840 (Nice Nano v2)
5. Artifacts: `.uf2` or `.bin` files in `firmware/`

**Build matrix** (`build.yaml`): Currently configured for Corne split (left/right halves)

**Key files**:
- `Justfile` - 163 lines, all build recipes
- `config/west.yml` - Manifest pinning ZMK v0.2, Zephyr, and modules
- `flake.nix` - Nix environment with Zephyr SDK, Python, build tools
- `.envrc` - direnv hook for automatic environment setup

## Configuration & Customization

### Keymap Architecture (`config/base.keymap`)
14 layers with homerow mods and combos:
- **DEF, QWERTY, SHFTMIRROR, MIRROR** - Layout variants
- **NUM, FN, NAV, SYS** - Function layers
- **MOUSE, MOUSE_BTNS** - Pointing device
- **ONESHOT, SNAKE, NOIDLE, SENTENCE** - Special behaviors

### Key ZMK Configuration (`config/corne.conf`)
```kconfig
CONFIG_ZMK_SLEEP=y                              # Sleep mode
CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=1800000           # 30 minutes idle
CONFIG_ZMK_POINTING=y                           # Mouse support
CONFIG_ZMK_COMBO_MAX_COMBOS_PER_KEY=14          # Auto-adjusted by build
CONFIG_ZMK_BLE_EXPERIMENTAL_CONN=y              # BLE features
CONFIG_BT_CTLR_TX_PWR_PLUS_8=y                  # Stronger Bluetooth
```

### Homerow Mods (Key Innovation)
- "Timeless" implementation using balanced flavor, require-prior-idle, positional hold-tap
- Tapping term: 280ms (tuned for combo avoidance + same-hand mod combinations)
- See `readme.md` (from upstream urob/zmk-config) for detailed explanation of the technique

### Keymap Visualization
```bash
just draw  # Generates draw/base.svg showing all layers
```
Uses `keymap-drawer` (v0.21.0) with config from `draw/config.yaml`

## Testing Infrastructure

**Platform**: Native POSIX emulation (`native_posix_64` - Linux x86_64 binary)

**Test structure**:
```
zmk/app/tests/<test-name>/
├── native_posix_64.keymap           # Test keymap definition
├── events.patterns                  # Regex filter for event log
└── keycode_events.snapshot          # Expected output (snapshot testing)
```

**Test process**:
1. Compile with native_posix_64 board
2. Execute binary (zmk.exe) → generates keycode events
3. Filter with regex patterns → compare with snapshot
4. Full log: `build/tests/<testcase>/keycode_events.full.log`

**Current coverage**: ~20+ tests for layers, combos, behaviors

**Snapshot updates**: Use `--auto-accept` flag when intentionally changing behavior

## Development Workflow

### Local Development
```bash
# 1. Edit keymap/config
vim config/base.keymap
vim config/combos.dtsi

# 2. Build and visualize
just build all
just draw

# 3. Commit and push
git add config/
git commit -m "feat: ..."
git push
```

### Hacking ZMK Core
```bash
# Edit ZMK source (e.g., behavior implementation)
vim zmk/app/src/behaviors/behavior_hold_tap.c

# Rebuild (west auto-handles CMake/Ninja)
just build all -p  # -p for pristine rebuild if needed
```

### Updating Dependencies
```bash
just update           # Pull latest from west.yml pins
just upgrade-sdk      # Update Nix packages (careful! can break)
```

## CI/CD Pipeline

**Primary**: GitHub Actions with Nix (`build-nix.yml`)
- Triggers on: push to `config/` or `build.yaml`, manual dispatch
- Runs on Linux with Zephyr SDK
- Build time: ~3 minutes (Nix caching)

**Secondary**: `test-build-env.yml` - Tests Nix environment on macOS/Linux/ARM

**Fallback**: Official ZMK workflow via manual dispatch

## Development Dependencies

**Nix-managed** (flake.nix):
- Zephyr SDK 0.16 (ARM cross-compiler)
- Python 3 + ZMK requirements
- CMake, Ninja, device tree compiler
- `just` task runner
- `keymap-drawer` (visualization)

All pinned in `flake.lock` for reproducibility. Use `nix flake update` cautiously.

## Hardware Target

**Board**: Nice Nano v2 (nRF52840 MCU)
**Keyboard**: Corne split (left/right, dual-piece)
**Features**: Bluetooth (experimental), USB HID, mouse support

Corne pinout: 36 keys (+ optional rotary encoders)

## Important Project-Specific Features

### Combos (50+)
- Replace traditional symbol layer
- Mirrored combos for symmetry
- Idle-time gating to prevent misfires

### Smart Layers
- **Numword**: Sticky number layer auto-deactivates on non-number key
- **Auto-off**: Mouse layer auto-disables on key press
- Context-aware behaviors via zmk-adaptive-key module

### Advanced Behaviors
- Magic repeat on thumb
- Sticky shift + capsword mode switching
- Leader key for Unicode/system commands
- Arrow cluster with Home/End/Doc-begin/Doc-end on long-press

## File Structure Reference

```
config/
├── base.keymap          # Main 14-layer keymap (843 lines)
├── combos.dtsi          # 50+ combos (6KB)
├── leader.dtsi          # Leader key sequences
├── mouse.dtsi           # Mouse parameters
├── corne.keymap         # Board wrapper
├── corne.conf           # ZMK configuration flags
└── west.yml             # Dependency manifest

modules/
├── zmk-helpers/         # Keymap macro helpers
├── zmk-auto-layer/      # Numword smart layer
├── zmk-leader-key/      # Leader sequences
├── zmk-adaptive-key/    # Context-aware keys
└── zmk-tri-state/       # Window switcher

zmk/
└── app/
    ├── src/             # ZMK firmware C code
    │   ├── behaviors/   # Hold-tap, macros, combos
    │   ├── keymap.c     # Layer management
    │   └── combo.c      # Combo engine
    └── tests/           # Native POSIX tests

draw/
├── config.yaml          # Keymap-drawer config
└── base.svg             # Generated visualization

firmware/
├── corne_left.uf2       # Compiled left half
└── corne_right.uf2      # Compiled right half
```

## Key ZMK Concepts

- **Behaviors**: Actions triggered by keys (hold-tap, macros, combos)
- **Layers**: Keyboard modes (normal, fn, num, etc.)
- **Combos**: Simultaneous key presses → different action
- **Hold-tap**: Same key behaves differently on hold vs. tap
- **Positional hold-tap**: Behavior depends on which hand presses next key
- **Flavors**: Logic for resolving hold-tap (balanced, hold-preferred, tap-preferred)

## Common Issues & Solutions

**Build fails with "unknown board"**: Check `build.yaml` and `config/west.yml` - board must be in submodules.

**Combos trigger unexpectedly**: Increase `CONFIG_ZMK_COMBO_TIMEOUT_MS` in `corne.conf`.

**Homerow mod keys slow to respond**: Check `require-prior-idle-ms` and `tapping-term-ms` in keymap.

**Tests fail after keymap change**: May need to update snapshots with `just test <path> --auto-accept`.

## References

- **ZMK Docs**: https://zmk.dev
- **Upstream Config** (this repo is forked from): https://github.com/urob/zmk-config
- **Homerow Mods Guide**: https://precondition.github.io/home-row-mods
- **Keymap Drawer**: https://github.com/caksoylar/keymap-drawer
- **ZMK Modules**: Custom feature extensions
