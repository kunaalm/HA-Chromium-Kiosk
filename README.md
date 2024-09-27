# HA Chromium Kiosk Setup

This script sets up a light Chromium-based kiosk mode on a Debian server specifically for Home Assistant dashboards, without using a display manager. It configures a touch-friendly kiosk environment and provides options for hiding the mouse pointer.

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

1. **Download the script:**
   ```bash
   wget -O ha-chromium-kiosk-setup.sh https://raw.githubusercontent.com/kunaalm/ha-chromium-kiosk/main/ha-chromium-kiosk-setup.sh
   ```

2. **Make the script executable:**
   ```bash
   chmod +x ha-chromium-kiosk/ha-chromium-kiosk-setup.sh
   ```
3. **Run the script using** sudo **with** install **or** uninstall **option**:
   ```bash
   sudo ./ha-chromium-kiosk/ha-chromium-kiosk-setup.sh install
   ```
   ***To Install:***
   Installation will prompt you to:
   * Enter the IP address of your Home Assistant instance (required)
   * Confirm the port for Home Assistant (defaults to 8123)
   * Enter the path to your Home Assistant dashboard (defaults to lovelace/default_view)
   * Choose whether to enable kiosk mode (?kiosk=true will be added to the URL if enabled)

   ***To Uninstall:***
   ```bash
   sudo ./ha-chromium-kiosk/ha-chromium-kiosk-setup.sh uninstall
   ```

5.	**Reboot the System:**
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
### Author
**Kunaal Mahanti**

If you encounter any problems or have suggestions, feel free to open an issue on the GitHub repository.
