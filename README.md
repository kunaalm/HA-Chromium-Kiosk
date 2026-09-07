# HA Chromium Kiosk Setup

This script sets up a light Chromium-based kiosk mode on a Debian server specifically for Home Assistant dashboards, without using a display manager. It configures a touch-friendly kiosk environment and provides options for hiding the mouse pointer.

## Latest Release

**Current Stable Release**: [v0.10.1](https://github.com/kunaalm/ha-chromium-kiosk/releases/tag/v0.10.1)

We recommend using the latest stable release for the best experience. The release page includes installation instructions and a summary of features.

**Release Notes**:
- v0.10.1: Added an upfront check for the `sudo` binary (some minimal Debian images don't ship it by default, causing a confusing failure deep into installation); added a Prerequisites section to this README.
- v0.10.0: HTTPS support, display rotation, pinch-zoom/scale-factor options, color-coded UI with progress spinners, a working `help` command, an install/uninstall confirmation summary, and a fixed silent bug where the installed kiosk's network-reachability check never actually ran. Full test plan and CI integration tests added. See the [release notes](https://github.com/kunaalm/ha-chromium-kiosk/releases/tag/v0.10.0) for the complete list.
- v0.9.1: Fixed IP address validation bug that incorrectly rejected valid IP addresses
- v0.9: ⚠️ DEPRECATED - Contains IP validation bug, please use v0.9.1 or later instead

## Repository

GitHub: [https://github.com/kunaalm/ha-chromium-kiosk](https://github.com/kunaalm/ha-chromium-kiosk)

## Summary

The `ha-chromium-kiosk-setup.sh` script performs the following tasks:
- Updates and upgrades the Debian system packages.
- Creates a dedicated `kiosk` user for the kiosk environment.
- Installs necessary packages, including X server, Chromium, Openbox, and utilities.
- Configures auto-login for the `kiosk` user without a display manager.
- Sets up Openbox to manage the Chromium kiosk session for Home Assistant.
- Provides an option to hide the mouse cursor on touchscreens.
- Configures and enables a systemd service to start the kiosk environment on system boot.

This setup is ideal for creating a dedicated, full-screen Home Assistant web kiosk with touch functionality.

## Prerequisites

- **A Debian-based Linux system** (Debian, Raspberry Pi OS, etc.) — the script uses `apt-get` directly and is not tested against other package managers/distros.
- **Root/sudo access** — the script refuses to run unless invoked as root (`sudo ./ha-chromium-kiosk-setup.sh ...`).
- **The `sudo` binary itself installed**, even though you invoke the script with `sudo` — the script internally runs a few steps as the `kiosk` user via `sudo -u kiosk ...`. Minimal Debian images (and some containers) don't ship `sudo` by default; install it first if needed: `apt-get update && apt-get install -y sudo`. The script checks for this up front (since v0.10.1) and exits with a clear error if missing, rather than failing deep into the install.
- **Internet access** for `apt-get update`/`install` — the script installs its own dependencies automatically (`xorg`, `openbox`, `chromium`, `xserver-xorg`, `xinit`, `unclutter`, `curl`, `netcat-openbsd`). Nothing needs to be pre-installed manually beyond `sudo` itself.
- **A reachable Home Assistant instance** — you'll be prompted for its IP/hostname, port, and dashboard path during installation. No default IP is provided.
- **No display manager should be running** — the script's whole approach (auto-login + Openbox + a systemd service) is designed to replace one, not coexist with an existing GDM/LightDM/SDDM setup.

## Features

- Automatically logs in a `kiosk` user on system boot
- Configures Openbox to run Chromium in full-screen kiosk mode for Home Assistant
- HTTP or HTTPS Home Assistant instances
- Optional display rotation (normal/left/right/inverted) for Pi + touchscreen setups
- Optional pinch-to-zoom disable and a configurable default zoom level
- Optionally hides the mouse pointer
- Starts and manages the kiosk session using a systemd service
- Tailored for touchscreen displays with pull-to-refresh support
- Color-coded, spinner-animated install/uninstall UI with a pre-action summary and confirmation
- Working `help` command

## Usage

1. **Download the script**:

   **Option 1 (Recommended)**: Download from the latest stable release (v0.10.1)
   ```bash
   wget -O ha-chromium-kiosk-setup.sh https://raw.githubusercontent.com/kunaalm/ha-chromium-kiosk/v0.10.1/ha-chromium-kiosk-setup.sh
   ```

   **Verify the download** before running it as root (recommended, since this script requires sudo):
   ```bash
   echo "f461326b6bf6b6042372a01811f14964dc5cc2d8df40efdc7af3730980def763  ha-chromium-kiosk-setup.sh" | sha256sum -c -
   ```
   This checksum matches the v0.10.1 tag. If you download a different version, verify against that release's own commit/tag content instead (`git show <tag>:ha-chromium-kiosk-setup.sh | sha256sum`), not this value.

   **Option 2**: Download from the main branch (development version)
   ```bash
   wget -O ha-chromium-kiosk-setup.sh https://raw.githubusercontent.com/kunaalm/ha-chromium-kiosk/main/ha-chromium-kiosk-setup.sh
   ```

2. **Make the script executable:**
   ```bash
   chmod +x ha-chromium-kiosk-setup.sh
   ```
3. **Run the script using** sudo **with** install **or** uninstall **option**:
   ```bash
   sudo ./ha-chromium-kiosk-setup.sh install
   ```
   ***To Install:***
   Installation will prompt you to:
   * Enter the IP address of your Home Assistant instance (required)
   * Confirm the port for Home Assistant (defaults to 8123)
   * Enter the path to your Home Assistant dashboard (defaults to lovelace/default_view)
   * Choose whether to enable kiosk mode (?kiosk=true will be added to the URL if enabled)
   * Choose whether to hide the mouse cursor (recommended for touchscreens)

   ***To Uninstall:***
   ```bash
   sudo ./ha-chromium-kiosk-setup.sh uninstall
   ```

4. **Reboot the System:**
After the script completes, you will be prompted to reboot. You can either reboot immediately or do so manually later to activate the kiosk environment.

### Important Information

**Disclaimer**
This script is provided “as is,” without warranty of any kind, express or implied. By using this script, you assume all risks. It is intended for educational and personal use only and is not recommended for commercial deployments.

**License**
This project is licensed under the Apache License, Version 2.0. See the LICENSE file for more details.

**Additional Notes**
The script will prompt you for optional settings, such as hiding the mouse cursor.
   * You will be given the option to reboot your system after the setup is complete to activate the kiosk environment.
   * If you need to make adjustments or customize the script further, feel free to edit the ha-chromium-kiosk.sh file in the repository.

**Troubleshooting**
   * Ensure you run the script with sudo since it requires root privileges to modify system settings and configurations.
   * For any issues with network connectivity, verify that the device is connected to the network and that the specified URL is reachable.
   * If the kiosk does not start as expected, check the status of the systemd service:
   ```bash
   sudo systemctl status ha-chromium-kiosk.service
   ```
### Versioning

- **v0.10.1** - Patch release: added an upfront `sudo`-binary check and a Prerequisites section
- **v0.10.0** - Feature release: HTTPS support, display rotation, pinch-zoom/scale-factor options, color-coded UI, spinner animations, `help` command, install/uninstall summary+confirmation, and a fix for a silent kiosk network-check bug
- **v0.9.1** - Bug fix release: Fixed IP address validation
- **v0.9** - ⚠️ DEPRECATED - Initial release with IP validation bug
- Releases follow semantic versioning (MAJOR.MINOR.PATCH)
- For a detailed list of changes in each version, see the [Releases page](https://github.com/kunaalm/ha-chromium-kiosk/releases)

### Testing

See [TESTING.md](TESTING.md) for the full test plan (static analysis, function-level dry runs, generated-artifact verification, and real systemd integration tests) before contributing a change or cutting a release.

### Author
**Kunaal Mahanti**

If you encounter any problems or have suggestions, feel free to open an issue on the GitHub repository.
