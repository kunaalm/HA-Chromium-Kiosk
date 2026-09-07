# HA Chromium Kiosk Setup

> ⚠️ **IMPORTANT**: Version 0.9 contains a bug in IP address validation. Please use version 0.9.1 or later.

This script sets up a light Chromium-based kiosk mode on a Debian server specifically for Home Assistant dashboards, without using a display manager. It configures a touch-friendly kiosk environment and provides options for hiding the mouse pointer.

## Latest Release

**Current Stable Release**: [v0.9.1](https://github.com/kunaalm/ha-chromium-kiosk/releases/tag/v0.9.1)

We recommend using the latest stable release for the best experience. The release page includes installation instructions and a summary of features.

**Release Notes**:
- v0.9.1: Fixed IP address validation bug that incorrectly rejected valid IP addresses
- v0.9: ⚠️ DEPRECATED - Contains IP validation bug, please use v0.9.1 instead

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

## Features

- Automatically logs in a `kiosk` user on system boot
- Configures Openbox to run Chromium in full-screen kiosk mode for Home Assistant
- Optionally hides the mouse pointer
- Starts and manages the kiosk session using a systemd service
- Tailored for touchscreen displays with pull-to-refresh support

## Usage

1. **Download the script**:

   **Option 1 (Recommended)**: Download from the latest stable release (v0.9.1)
   ```bash
   wget -O ha-chromium-kiosk-setup.sh https://raw.githubusercontent.com/kunaalm/ha-chromium-kiosk/v0.9.1/ha-chromium-kiosk-setup.sh
   ```

   **Verify the download** before running it as root (recommended, since this script requires sudo):
   ```bash
   echo "ca1558c1844dfee3d9a6b034261776d04f934a5dbfb561ce8a5fc50f71568c77  ha-chromium-kiosk-setup.sh" | sha256sum -c -
   ```
   This checksum matches the v0.9.1 tag. If you download a different version, verify against that release's own commit/tag content instead (`git show <tag>:ha-chromium-kiosk-setup.sh | sha256sum`), not this value.

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

- **v0.9.1** - Bug fix release: Fixed IP address validation
- **v0.9** - ⚠️ DEPRECATED - Initial release with IP validation bug
- Future releases will follow semantic versioning (MAJOR.MINOR.PATCH)
- For a detailed list of changes in each version, see the [Releases page](https://github.com/kunaalm/ha-chromium-kiosk/releases)

### Author
**Kunaal Mahanti**

If you encounter any problems or have suggestions, feel free to open an issue on the GitHub repository.
