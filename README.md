# Deskflip

Switch monitor inputs and connect/disconnect displays on macOS with one command.

Deskflip is for desks where monitors are shared between a Mac and another computer (a work laptop, a PC). Instead of pressing the input button on every monitor, you run a preset:

```sh
deskflip work   # left + bottom go to the laptop, top stays on the Mac
deskflip mac2   # left + bottom back to the Mac, top off
deskflip mac3   # all three on the Mac
```

Everything runs on the Mac. Nothing needs to be installed on the other computer.

## How it works

A preset does two things per display:

1. **Switches the monitor's input** over DDC/CI with [m1ddc](https://github.com/waydabber/m1ddc).
2. **Connects or disconnects the display in macOS** with `deskflip-display`, a small Swift tool included in this repo. A display handed to another computer is disconnected, so macOS stops extending your desktop onto a screen you can't see.

The order is always: reconnect displays the Mac needs → switch inputs → disconnect displays that are off or handed over.

## Requirements

- Apple Silicon Mac, macOS 13 (Ventura) or later
- Monitors with DDC/CI enabled
- [m1ddc](https://github.com/waydabber/m1ddc): `brew install m1ddc`
- Xcode Command Line Tools to build: `xcode-select --install`

## Install

```sh
git clone https://github.com/Turmin/deskflip.git
cd deskflip
make install
deskflip init
```

`make install` installs into your Homebrew prefix (e.g. `/opt/homebrew/bin`). Use `make install PREFIX=~/.local` to install elsewhere.

## Setup

1. Run `deskflip ids` and copy the UUID of each display into `~/.config/deskflip/config`. Identical monitors have identical names, so use the POSITION column to tell them apart.
2. Set each monitor to the input you want by hand and run `deskflip input` to read its input code. The code for USB-C in particular differs per brand.
3. Define your presets. See [`config.example`](config.example) for the format.
4. Test disconnecting a single display first:

   ```sh
   deskflip-display off <UUID>
   deskflip-display on <UUID>
   ```

   If this exits with code 3 ("macOS ignored it"), the private API doesn't work on your macOS version. See [Limitations](#limitations).

## Commands

| Command | Description |
| --- | --- |
| `deskflip <preset>` | Apply a preset |
| `deskflip presets` | List presets |
| `deskflip ids` | Show displays, UUIDs and DDC identifiers |
| `deskflip input` | Show the current input code of each display |
| `deskflip init` | Create a config from the example |
| `deskflip-display list` | List displays with their state and position |
| `deskflip-display on\|off <UUID\|ID>` | Connect or disconnect one display |

## One-button switching

- **Shortcuts app:** create a shortcut per preset with *Run Shell Script* → `/opt/homebrew/bin/deskflip work`. Assign a keyboard shortcut or add it to the menu bar.
- **iPhone:** use *Run Script Over SSH* in Shortcuts to call `deskflip <preset>` on the Mac.
- **Stream Deck (Mobile):** trigger the Shortcuts above.

## Limitations

- `deskflip-display` uses the private API `CGSConfigureDisplayEnabled`. Apple can change or remove it in any macOS update.
- Disconnecting lasts for the current session. Logging out or restarting reconnects every display.
- Some monitors stop listening to DDC while they're set to another input. Switching back to the Mac then won't work from software; press the monitor's input button once instead.
- Deskflip refuses to disconnect the last active display.

If the private API stops working, [BetterDisplay Pro](https://betterdisplay.pro) offers the same disconnect feature, maintained across macOS updates.

## License

[MIT](LICENSE)
