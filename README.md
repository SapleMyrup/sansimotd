# Scrolling MOTD

Scrolling MOTD delivers classic ANSI art as a streaming login banner. The main `scrolling-motd.sh` script picks a random art file, converts it from DOS codepage 437 to UTF-8, and throttles output so the art appears to scroll instead of dumping instantly. It is safe for PuTTY, respects tmux panes, and can draw inside any terminal that understands ANSI escape sequences.

## Features
- Streams ANSI or ANS art at 80 columns with optional tmux pop-up support.
- Converts legacy codepage 437 art to UTF-8 on the fly via `iconv`.
- Uses `pv` to rate-limit output for a readable scroll effect.
- Chooses a random art file from a directory, or renders a specific file.
- Provides rendering modes tuned for PuTTY (`DECCOLM`), modern terminals that honor dynamic margins (`DECLRMM`), and tmux pop-ups.

## Requirements
- POSIX-like system with `bash` (the script uses Bash-specific features).
- Run-time utilities: `tput`, `find`, `awk`, `iconv`, `pv`, `wc`, `mktemp`, and optionally `tmux` when using `--mode tmux`.
- Installer-only utilities: `install`, `cat`, `cp`; `rsync` is used when available.
- ANSI/ANS artwork stored in a directory, typically encoded in CP437.

## Quick Start
```bash
chmod +x ./install-motd.sh
sudo ./install-motd.sh
```

After installation, login shells sourcing `/etc/profile.d/scrolling-motd.sh` will execute the script and show a random ANSI art banner. Existing shells can test the installation with:

```bash
ANSI_ART_DIR=/usr/local/share/scrolling-motd/ansiart /usr/local/bin/scrolling-motd
```

Restart your shell (or open a fresh tmux window) to pick up the profile hook. If you prefer to run the script without installing, you can execute it directly:

```bash
ANSI_ART_DIR="$PWD/ansiart" ./scrolling-motd.sh
```

## Configuration

### Command-line flags (`scrolling-motd.sh`)
- `--ansipath PATH` / `-f PATH` - Render a specific file or pick randomly from a directory (default: `/usr/local/share/scrolling-motd/ansiart`).
- `--rate-limit N` - Set the byte-per-second throttle for `pv` (default: `RATE_LIMIT` env or `7000`).
- `--no-clear` - Skip clearing the terminal before rendering.
- `--mode auto|putty|margins|tmux` - Choose the rendering strategy. `auto` uses `tmux` mode when `$TMUX` is set, otherwise `putty`.
- `-h`, `--help` - Display usage information.

### Environment variables
- `ANSI_ART_DIR` - Directory containing ANSI/ANS art files; overrides the default art path.
- `RATE_LIMIT` - Default scroll speed in bytes per second when `--rate-limit` is not supplied.
- `TMUX_POPUP_DELAY` - Seconds to delay before a tmux pop-up closes; only used in `--mode tmux`.

### Installer variables (`install-motd.sh`)
You can override destinations by exporting variables before running the installer:

- `INSTALL_BIN` - Path for the executable script (default: `/usr/local/bin/scrolling-motd`).
- `INSTALL_SHARE` - Base share directory (default: `/usr/local/share/scrolling-motd`).
- `INSTALL_ART_DIR` - Final art directory (default: `$INSTALL_SHARE/ansiart`).
- `ART_SRC` - Relative path to the source art directory in the project (default: `ansiart`).
- `INSTALL_PROFILE` - Target profile script path (default: `/etc/profile.d/scrolling-motd.sh`).

Example:
```bash
sudo INSTALL_BIN=/opt/bin/scrolling-motd \
     INSTALL_SHARE=/opt/share/scrolling-motd \
     INSTALL_PROFILE=/etc/profile.d/scrolling-motd.sh \
     ./install-motd.sh
```

## Modes at a Glance
- **putty** - Forces 80-column mode (`DECCOLM`) and uses `tput clear` for safety in terminals that do not support dynamic margins.
- **margins** - Enables `DECLRMM` when the terminal supports dynamic left/right margins.
- **tmux** - Renders inside a tmux pop-up sized to the pane; waits for a keypress (or `TMUX_POPUP_DELAY`) before closing.
- **auto** - Chooses `tmux` when `$TMUX` is set, otherwise `putty`.

## Adding or Curating Art
Place `.ans` or `.ansi` files in your art directory. Files are chosen randomly while ignoring dotfiles. If your art is already UTF-8, you can still store it in the same directory; `iconv` falls back gracefully when conversion fails.

## Art Credits
The bundled ANSI artwork comes from the 16colo.rs archive. Please visit [16colo.rs](https://16colo.rs/) to find the original packs, artist credits, and licensing notes for each piece.

## Troubleshooting
- No output: ensure `ANSI_ART_DIR` points to readable files and `pv` is installed.
- Corrupted characters: confirm the source art is CP437; otherwise store UTF-8 art or remove the conversion step manually.
- tmux pop-up closes immediately: set `TMUX_POPUP_DELAY` to a positive integer to keep the pop-up open briefly.
