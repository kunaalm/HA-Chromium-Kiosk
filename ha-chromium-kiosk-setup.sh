#!/bin/bash
###################################################################################

# Function to handle script interruption
cleanup() {
    local exit_code=$?
    local signal_name=$1

    echo ""
    if [ $exit_code -ne 0 ]; then
        echo "Script interrupted or error occurred ($signal_name). Exit code: $exit_code"
        echo "Cleaning up temporary files and configurations..."

        # Clean up any temporary files or partial configurations here
        # This ensures the system is not left in an inconsistent state

        echo "Cleanup complete. You may need to manually check the system for any incomplete changes."
    fi

    exit $exit_code
}

# Set up signal handling
trap 'cleanup "SIGINT"' INT
trap 'cleanup "SIGTERM"' TERM
trap 'cleanup "EXIT"' EXIT

###################################################################################
# HA Chromium Kiosk Setup and Uninstall Script
# Author: Kunaal Mahanti (kunaal.mahanti@gmail.com)
# URL: https://github.com/kunaalm/ha-chromium-kiosk
#
# This script installs or uninstalls a light Chromium-based kiosk mode on a
# Debian server specifically for Home Assistant dashboards, without using
# a display manager.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Usage: sudo ./ha-chromium-kiosk-setup.sh {install|uninstall}
#               install - Installs the kiosk setup
#               uninstall - Uninstalls the kiosk setup
#
# Note: This script is provided as-is without any warranty. Use at your own risk.
###################################################################################

## GLOBAL VARIABLES AND DEFAULTS ##
KIOSK_USER="kiosk"
CONFIG_DIR="/home/$KIOSK_USER/.config"
KIOSK_CONFIG_DIR="$CONFIG_DIR/ha-chromium-kiosk"
OPENBOX_CONFIG_DIR="$CONFIG_DIR/openbox"

DEFAULT_HA_PORT="8123"
DEFAULT_HA_DASHBOARD_PATH="lovelace/default_view"

PKGS_NEEDED=(xorg openbox chromium xserver-xorg xinit unclutter curl netcat-openbsd)

## FUNCTIONS ##

# Print usage
print_usage() {
    echo "Usage: sudo $0 {install|uninstall}"
    exit 1
}

# Print banner
print_banner() {
    echo "****************************************************************************************************"
    echo "    __  _____       ________                         _                    __ __ _            __   "
    echo "   / / / /   |     / ____/ /_  _________  ____ ___  (_)_  ______ ___     / //_/(_)___  _____/ /__ "
    echo "  / /_/ / /| |    / /   / __ \/ ___/ __ \/ __ \`__ \/ / / / / __ \`__ \   / ,<  / / __ \/ ___/ //_/ "
    echo " / __  / ___ |   / /___/ / / / /  / /_/ / / / / / / / /_/ / / / / / /  / /| |/ / /_/ (__  ) ,<    "
    echo "/_/ /_/_/  |_|   \____/_/ /_/_/   \____/_/ /_/ /_/_/\__,_/_/ /_/ /_/  /_/ |_/_/\____/____/_/|_|   "
    echo "                                                                                                  "
    echo "                                                                                                 "
    echo "                        Setup and Install or Uninstall Script for HA Chromium Kiosk              "
    echo "                                                                                                 "
    echo "****************************************************************************************************"
    echo "***                               WARNING: USE AT YOUR OWN RISK                                  ***"
    echo "****************************************************************************************************"
    echo "                                                                                                 "
    echo "* This script will install or uninstall HA Chromium Kiosk setup."
    echo "* Please read the script before running it to understand what it does."
    echo "* Use at your own risk. The author is not responsible for any damage or data loss."
    echo "* Press Ctrl+C to exit or any other key to continue."
    read -n 1 -s
}

# Install a package and print dots while waiting
install_package() {
    local package=$1
    local dot_pid
    local apt_status

    # Start a background job to print dots
    while true; do
        echo -n "..."
        sleep 1
    done &

    # Capture the PID of the background job
    dot_pid=$!

    # Run apt-get update and install silently
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y "$package" > /dev/null 2>&1
    # Capture the exit status of the apt-get command
    apt_status=$?

    # Kill the background job
    kill $dot_pid 2>/dev/null || true

    # Wait for the background job to completely terminate
    wait $dot_pid 2>/dev/null || true

    # Return the exit status of the apt-get command
    return $apt_status
}

# Uninstall the installed package and print dots while waiting
uninstall_package() {
    local package=$1
    local dot_pid
    local apt_status

    # Start a background job to print dots
    while true; do
        echo -n "..."
        sleep 1
    done &

    # Capture the PID of the background job
    dot_pid=$!

    # Run apt-get remove silently
    sudo apt-get remove --purge -y "$package" > /dev/null 2>&1
    # Capture the exit status of the apt-get command
    apt_status=$?

    # Kill the background job
    kill $dot_pid 2>/dev/null || true

    # Wait for the background job to completely terminate
    wait $dot_pid 2>/dev/null || true

    # Return the exit status of the apt-get command
    return $apt_status
}

# Install the necessary packages
# Keep track of the installed packages for later removal
install_packages() {
    # Check if kiosk configuration directory already exists
    if [ -d "$KIOSK_CONFIG_DIR" ]; then
        echo "Existing kiosk configuration directory found at $KIOSK_CONFIG_DIR"
        prompt_user backup_kiosk_config "Do you want to backup the existing kiosk configuration? (Y/n)" "Y"
        if [[ $backup_kiosk_config =~ ^[Yy]$ ]]; then
            echo "Backing up existing kiosk configuration..."
            backup_dir="$KIOSK_CONFIG_DIR.backup.$(date +%Y%m%d%H%M%S)"
            cp -r "$KIOSK_CONFIG_DIR" "$backup_dir"
            echo "Backup created at $backup_dir"
        fi
    fi

    # Create the kiosk configuration directory
    sudo -u $KIOSK_USER mkdir -p "$KIOSK_CONFIG_DIR"

    # Install the necessary packages and keep track of what was installed
    missing_pkgs=()

    echo "Checking required packages..."

    # Create a list of packages that need to be checked
    pkgs_list="${PKGS_NEEDED[*]}"

    # Get the install status of all required packages at once
    dpkg_query_output=$(dpkg-query -W -f='${Package} ${Status}\n' "$pkgs_list" 2>/dev/null)

    for pkg in "${PKGS_NEEDED[@]}"; do
        if ! echo "$dpkg_query_output" | grep -q "^$pkg install ok installed$"; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        echo "Installing missing packages..."
        total_pkgs=${#missing_pkgs[@]}
        current_pkg=0

        for pkg in "${missing_pkgs[@]}"; do
            current_pkg=$((current_pkg + 1))
            echo -ne "Installing package $current_pkg of $total_pkgs: $pkg "

            # Try to install the package with retry logic
            local max_retries=3
            local retry_count=0
            local success=false

            while [ $retry_count -lt $max_retries ] && [ "$success" = "false" ]; do
                if install_package "$pkg"; then
                    success=true
                else
                    retry_count=$((retry_count + 1))
                    if [ $retry_count -lt $max_retries ]; then
                        echo "Failed to install package: $pkg (Attempt $retry_count of $max_retries)"
                        echo "Retrying in 5 seconds..."
                        sleep 5
                    else
                        echo "Failed to install package: $pkg after $max_retries attempts"
                        prompt_user continue_on_error "Do you want to continue with the installation anyway? (y/N)" "N"
                        if [[ ! $continue_on_error =~ ^[Yy]$ ]]; then
                            echo "Installation aborted due to package installation failure."
                            exit 1
                        else
                            echo "Continuing installation despite package failure. Some features may not work correctly."
                        fi
                    fi
                fi
            done

            echo " Done."
        done

        echo "All missing packages have been installed."
    else
        echo "All prerequisites are already installed."
    fi

    # Save the list of packages to remove later in a file
    echo "${missing_pkgs[*]}" > "$KIOSK_CONFIG_DIR/installed-packages"
}

# Uninstall the installed packages
uninstall_packages() {
    # Check if the installed-packages file exists
    if [ -f "$KIOSK_CONFIG_DIR/installed-packages" ]; then
        installed_packages=$(< "$KIOSK_CONFIG_DIR/installed-packages")

        if [ -n "$installed_packages" ]; then
            echo "Removing installed packages..."

            # Uninstall the packages one by one to handle errors better
            # Use read to properly handle package names with spaces
            IFS=' ' read -r -a pkg_array <<< "$installed_packages"
            for pkg in "${pkg_array[@]}"; do
                echo "Removing package: $pkg"
                if ! apt-get purge -y "$pkg"; then
                    echo "Warning: Failed to purge package: $pkg. Continuing with other packages."
                fi
            done

            # Run autoremove to clean up dependencies
            echo "Removing unnecessary dependencies..."
            if ! apt-get autoremove -y; then
                echo "Warning: Failed to autoremove some unnecessary packages."
            fi

            echo "Package removal process completed."
        else
            echo "No packages to remove."
        fi
    else
        echo "No installed packages file found."
    fi
}

# Check and create user
check_create_user() {
    # Ensure KIOSK_USER is set
    if [ -z "$KIOSK_USER" ]; then
        echo "No username provided. Please set KIOSK_USER."
        exit 1
    fi

    while id "$KIOSK_USER" &>/dev/null; do
        # Prompt to use existing user or create a new one, default to existing
            read -p "The kiosk user already exists. Do you want to use the existing user? (Y/n): " use_existing
        use_existing=${use_existing:-Y}

        if [[ $use_existing =~ ^[Yy]$ ]]; then
            echo "Using the existing user."
            return
        elif [[ $use_existing =~ ^[Nn]$ ]]; then
            read -p "Enter a different username for the kiosk user: " KIOSK_USER
            if [ -z "$KIOSK_USER" ]; then
                echo "Username cannot be empty. Please enter a valid username."
            fi
        else
            echo "Invalid input. Please enter Y or N."
        fi
    done

    echo "Creating the kiosk user..."
    if ! adduser --disabled-password --gecos "" "$KIOSK_USER" >/dev/null; then
        echo "Failed to create the kiosk user. Exiting..."
        exit 1
    fi

    echo " Done."
}

# Check and remove user if needed
check_remove_user() {
    if id "$KIOSK_USER" &>/dev/null; then
        read -p "The kiosk user exists. Do you want to remove the user? (Y/n): " remove_user
        if [[ $remove_user =~ ^[Yy]?$ ]]; then
            echo "Removing the kiosk user..."
            userdel -rf "$KIOSK_USER"
        else
            echo "The kiosk user was not removed."
        fi
    else
        echo "The kiosk user does not exist."
    fi
}

# Function to validate IP address format
validate_ip() {
    local ip=$1

    # First check if it's a valid IPv4 address
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Split the IP into octets
        IFS='.' read -r -a octets <<< "$ip"

        # Make sure we have exactly 4 octets
        if [ ${#octets[@]} -ne 4 ]; then
            return 1
        fi

        # Check if each octet is between 0 and 255
        for octet in "${octets[@]}"; do
            # Remove leading zeros which can cause issues with bash interpreting as octal
            octet=$(echo "$octet" | sed 's/^0*//')
            # If octet is empty after removing zeros, it was just "0"
            if [ -z "$octet" ]; then
                octet=0
            fi

            # Check if it's a valid number between 0-255
            if ! [[ "$octet" =~ ^[0-9]+$ ]] || [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
                return 1
            fi
        done

        # If we got here, it's a valid IPv4 address
        return 0
    fi

    # If not an IP address, check if it's a valid hostname
    if [[ $ip =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi

    # If we got here, it's neither a valid IP nor hostname
    return 1
}

# Function to validate port number
validate_port() {
    local port=$1

    # Check if the port is a number and within the valid range (1-65535)
    if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt user function
prompt_user() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3

    while true; do
        read -p "$prompt_message [$default_value]: " value
        value=${value:-$default_value}

        if [[ -z "$value" && -z "$default_value" ]]; then
            echo "Error: $var_name is required. Please enter a value."
            continue
        fi

        # Validate IP address if the variable is HA_IP
        if [[ "$var_name" == "HA_IP" ]]; then
            if ! validate_ip "$value"; then
                echo "Error: Invalid IP address or hostname format. Please enter a valid IPv4 address (e.g., 192.168.1.100) or hostname."
                continue
            fi
        fi

        # Validate port number if the variable is HA_PORT
        if [[ "$var_name" == "HA_PORT" ]]; then
            if ! validate_port "$value"; then
                echo "Error: Invalid port number. Please enter a number between 1 and 65535."
                continue
            fi
        fi

        # Basic input validation to prevent command injection for other inputs
        # This regex allows alphanumeric characters, dots, dashes, underscores, colons, and slashes
        # which should cover most legitimate inputs while blocking potentially dangerous ones
        if [[ "$var_name" != "HA_IP" && "$var_name" != "HA_PORT" && "$var_name" != "HA_DASHBOARD_PATH" ]]; then
            # For yes/no prompts and other simple inputs, we're more restrictive
            if [[ ! "$value" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
                echo "Error: Input contains invalid characters. Only alphanumeric characters, dots, dashes, and underscores are allowed."
                continue
            fi
        elif [[ "$var_name" == "HA_DASHBOARD_PATH" ]]; then
            # For paths, we need to allow more characters
            if [[ ! "$value" =~ ^[a-zA-Z0-9_.:/-]+$ ]]; then
                echo "Error: Input contains invalid characters. Only alphanumeric characters, dots, colons, slashes, dashes, and underscores are allowed."
                continue
            fi
        fi

        break
    done

    # Use declare instead of eval for secure variable assignment.
    # NOTE: this dynamically creates/sets $var_name at the caller's scope,
    # which ShellCheck cannot trace (SC2154 "referenced but not assigned"
    # at every call site that reads the resulting variable, e.g.
    # $backup_config, $enable_kiosk, $hide_cursor, $reboot_now, etc.).
    # That's expected/safe here since every read site is always preceded
    # by a prompt_user call for that same variable name in this script's
    # control flow - see issue #26.
    declare -g "$var_name"="$value"
}

# Check and backup existing configuration files
# Returns 0 (success) if the caller should proceed to write/overwrite
# $config_file, or 1 if the user declined and the caller should skip
# that one step and continue installing everything else (see issue #25 -
# this used to call `exit 0` on decline, aborting the entire install
# instead of just skipping the one file in question).
check_backup_config() {
    local config_file=$1
    local config_desc=$2

    if [ -f "$config_file" ]; then
        echo "Existing $config_desc configuration found."
        prompt_user backup_config "Do you want to backup the existing $config_desc configuration? (Y/n)" "Y"
        if [[ $backup_config =~ ^[Yy]?$ ]]; then
            echo "Backing up existing $config_desc configuration..."
            cp "$config_file" "$config_file.backup.$(date +%Y%m%d%H%M%S)"
            echo "Backup created at $config_file.backup.$(date +%Y%m%d%H%M%S)"
        fi

        prompt_user overwrite_config "Do you want to overwrite the existing $config_desc configuration? (Y/n)" "Y"
        if [[ ! $overwrite_config =~ ^[Yy]$ ]]; then
            echo "Skipping $config_desc configuration - existing file will not be modified."
            return 1
        fi
    fi

    return 0
}

# Install the kiosk setup
install_kiosk() {
    # Prompt user for necessary inputs
    prompt_user HA_IP "Enter the IP address of your Home Assistant instance" ""
    prompt_user HA_PORT "Enter the port for Home Assistant" "$DEFAULT_HA_PORT"
    prompt_user HA_DASHBOARD_PATH "Enter the path to your Home Assistant dashboard" "$DEFAULT_HA_DASHBOARD_PATH"

    # Kiosk mode and cursor settings
    prompt_user enable_kiosk "Do you want to enable kiosk mode? (Y/n)" "Y"
    prompt_user hide_cursor "Do you want to hide the mouse cursor? (Y/n)" "Y"

    KIOSK_MODE=""
    [[ $enable_kiosk =~ ^[Yy]?$ ]] && KIOSK_MODE="?kiosk=true"

    KIOSK_URL="http://$HA_IP:$HA_PORT/$HA_DASHBOARD_PATH$KIOSK_MODE"
    echo "Your Home Assistant dashboard will be displayed at: $KIOSK_URL"
    echo "Setting up Chromium Kiosk Mode for Home Assistant URL:$KIOSK_URL"

    # Check for existing auto-login configuration
    write_tty1_config=true
    if [ -f "/etc/systemd/system/getty@tty1.service.d/override.conf" ]; then
        check_backup_config "/etc/systemd/system/getty@tty1.service.d/override.conf" "auto-login" || write_tty1_config=false
    fi

    if [ "$write_tty1_config" = true ]; then
        # Configure auto login
        echo "Configuring auto-login for the kiosk user..."
        mkdir -p /etc/systemd/system/getty@tty1.service.d
        cat <<EOF >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
Type=idle
EOF

        systemctl daemon-reload
        # NOTE: intentionally NOT restarting getty@tty1.service here (see issue #20).
        # Restarting it mid-install can immediately auto-login as $KIOSK_USER on tty1,
        # killing the interactive shell running this installer, before the kiosk
        # systemd service / Openbox config / startup script even exist yet. The
        # actual kiosk session runs on tty7 via ha-chromium-kiosk.service, not tty1 -
        # the auto-login override only needs to take effect on the next boot/login,
        # which the end-of-install reboot prompt already covers.
    else
        echo "Skipping auto-login configuration for $KIOSK_USER as requested."
    fi

    # Configure Openbox
    echo "Configuring Openbox for the kiosk user..."
    sudo -u $KIOSK_USER mkdir -p $OPENBOX_CONFIG_DIR

    # Check for existing Openbox configuration
    write_openbox_autostart=true
    if [ -f "$OPENBOX_CONFIG_DIR/autostart" ]; then
        check_backup_config "$OPENBOX_CONFIG_DIR/autostart" "Openbox" || write_openbox_autostart=false
    fi

    # Check for existing kiosk startup script
    write_kiosk_script=true
    if [ -f "/usr/local/bin/ha-chromium-kiosk.sh" ]; then
        check_backup_config "/usr/local/bin/ha-chromium-kiosk.sh" "kiosk startup script" || write_kiosk_script=false
    fi

    if [ "$write_kiosk_script" = true ]; then
    # Create the kiosk startup script
    # Written to a temp file first, then moved into place atomically (mv on
    # the same filesystem) so a re-install while the kiosk service is live
    # can't truncate the script mid-read by a running process (issue #29).
    # Also best-effort stop the service first, in case it's actively running.
    KIOSK_SCRIPT_TMP=$(mktemp /usr/local/bin/.ha-chromium-kiosk.sh.XXXXXX)
    kiosk_service_was_active=false
    if systemctl is-active --quiet ha-chromium-kiosk.service 2>/dev/null; then
        kiosk_service_was_active=true
        echo "Stopping the running kiosk service before updating its script..."
        systemctl stop ha-chromium-kiosk.service
    fi

    echo "Creating the kiosk startup script..."
    cat <<EOF >"$KIOSK_SCRIPT_TMP"
#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Optionally hide the mouse cursor
EOF

    [[ $hide_cursor =~ ^[Yy]?$ ]] && echo "unclutter -idle 0 &" >>"$KIOSK_SCRIPT_TMP"

    cat <<EOF >>"$KIOSK_SCRIPT_TMP"

check_network() {
    local max_attempts=30  # Maximum number of attempts (30 * 2 seconds = 1 minute timeout)
    local attempt=0
    local success=false

    echo "Checking if Home Assistant is reachable at $HA_IP:$HA_PORT..."

    # Check if netcat is installed
    if ! command -v nc &> /dev/null; then
        echo "Warning: netcat (nc) is not installed. Cannot check network connectivity."
        echo "Installing netcat..."
        apt-get update > /dev/null 2>&1
        apt-get install -y netcat-openbsd > /dev/null 2>&1

        if ! command -v nc &> /dev/null; then
            echo "Failed to install netcat. Skipping network check."
            return 1
        fi
    fi

    while [ $attempt -lt $max_attempts ] && [ "$success" = "false" ]; do
        if nc -z -w 5 "$HA_IP" "$HA_PORT" 2>/dev/null; then
            success=true
            echo "Connection to Home Assistant established!"
        else
            attempt=$((attempt + 1))
            if [ $attempt -lt $max_attempts ]; then
                echo "Attempt $attempt of $max_attempts: Home Assistant not reachable yet. Retrying in 2 seconds..."
                sleep 2
            else
                echo "Warning: Could not connect to Home Assistant after $max_attempts attempts."
                echo "The kiosk will continue to try connecting when it starts."
                echo "Please ensure Home Assistant is running at $HA_IP:$HA_PORT"
                return 1
            fi
        fi
    done

    return 0
}

if check_network; then
    echo "Home Assistant is reachable. Starting Chromium..."
else
    echo "Starting Chromium anyway, will keep trying to connect to Home Assistant..."
fi

chromium \
    --noerrdialogs \
    --disable-infobars \
    --kiosk \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --overscroll-history-navigation=0 \
    --pull-to-refresh=2 \
    "$KIOSK_URL"
EOF

    chmod +x "$KIOSK_SCRIPT_TMP"
    mv "$KIOSK_SCRIPT_TMP" /usr/local/bin/ha-chromium-kiosk.sh

    if [ "$kiosk_service_was_active" = true ]; then
        echo "Restarting the kiosk service with the updated script..."
        systemctl start ha-chromium-kiosk.service
    fi
    else
        echo "Skipping kiosk startup script - existing file will not be modified."
    fi

    if [ "$write_openbox_autostart" = true ]; then
        echo "Configuring Openbox to start the kiosk script..."
        echo "/usr/local/bin/ha-chromium-kiosk.sh &" > $OPENBOX_CONFIG_DIR/autostart
    else
        echo "Skipping Openbox autostart configuration - existing file will not be modified."
    fi

    # Check for existing systemd service
    write_systemd_service=true
    if [ -f "/etc/systemd/system/ha-chromium-kiosk.service" ]; then
        check_backup_config "/etc/systemd/system/ha-chromium-kiosk.service" "systemd service" || write_systemd_service=false
    fi

    if [ "$write_systemd_service" = true ]; then
    # Create the systemd service
    echo "Creating the systemd service..."
    cat <<EOF >/etc/systemd/system/ha-chromium-kiosk.service
[Unit]
Description=Chromium Kiosk Mode for Home Assistant
After=systemd-user-sessions.service network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$KIOSK_USER
Group=$KIOSK_USER
PAMName=login
Environment=XDG_RUNTIME_DIR=/run/user/%U
ExecStart=/usr/bin/xinit /usr/bin/openbox-session -- :0 vt7 -nolisten tcp -nocursor -auth /var/run/kiosk.auth
Restart=always
RestartSec=5
StandardInput=tty
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable ha-chromium-kiosk.service

    echo "Adding the kiosk user to the tty group..."
    usermod -aG tty $KIOSK_USER

    # Prompt for immediate reboot
    prompt_user reboot_now "Setup is complete. Do you want to reboot now?" "Y"
    [[ $reboot_now =~ ^[Yy]?$ ]] && { echo "Rebooting the system..."; reboot; } || echo "Setup is complete. Please reboot the system manually when ready."
}

# Uninstall the kiosk setup
uninstall_kiosk() {
    echo "This script will uninstall HA Chromium Kiosk and remove all associated configurations."
    prompt_user confirm "Are you sure you want to proceed? (Y/n)" "Y"
    if [[ $confirm =~ ^[Nn]$ ]]; then
        echo "Uninstall canceled."
        exit 0
    fi

    # Stop and disable the systemd service
    echo "Stopping and disabling the ha-chromium-kiosk service..."
    systemctl stop ha-chromium-kiosk.service && systemctl disable ha-chromium-kiosk.service

    # Check if the service was stopped and disabled successfully
    if [[ $? -ne 0 ]]; then
        echo "Failed to stop or disable ha-chromium-kiosk service. Please check manually."
        exit 1
    fi

    # Function to check for backups and offer to restore them
    check_restore_backup() {
        local file_path=$1
        local desc=$2

        # Find the most recent backup
        local backup_files=( "$file_path.backup."* )

        if [ ${#backup_files[@]} -gt 0 ] && [ -f "${backup_files[-1]}" ]; then
            local latest_backup="${backup_files[-1]}"
            echo "Backup found for $desc: $latest_backup"
            prompt_user restore_backup "Do you want to restore this backup before removing the current file? (Y/n)" "Y"

            if [[ $restore_backup =~ ^[Yy]?$ ]]; then
                echo "Restoring backup for $desc..."
                cp "$latest_backup" "$file_path"
                echo "Backup restored."
                return 0
            fi
        fi

        return 1
    }

    # Remove the systemd service file
    echo "Removing the systemd service file..."
    if [[ -f /etc/systemd/system/ha-chromium-kiosk.service ]]; then
        check_restore_backup "/etc/systemd/system/ha-chromium-kiosk.service" "systemd service"
        rm -f /etc/systemd/system/ha-chromium-kiosk.service
    else
        echo "No systemd service file found."
    fi

    # Remove the startup script
    echo "Removing the kiosk startup script..."
    if [[ -f /usr/local/bin/ha-chromium-kiosk.sh ]]; then
        check_restore_backup "/usr/local/bin/ha-chromium-kiosk.sh" "kiosk startup script"
        rm -f /usr/local/bin/ha-chromium-kiosk.sh
    else
        echo "No kiosk startup script found."
    fi

    # Remove the autostart entry for Openbox
    echo "Removing Openbox autostart configuration..."
    if [[ -f $OPENBOX_CONFIG_DIR/autostart ]]; then
        check_restore_backup "$OPENBOX_CONFIG_DIR/autostart" "Openbox autostart"
        rm -f $OPENBOX_CONFIG_DIR/autostart
    else
        echo "No Openbox autostart configuration found."
    fi

    # Remove the auto-login configuration
    echo "Removing auto-login configuration..."
    if [[ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]]; then
        check_restore_backup "/etc/systemd/system/getty@tty1.service.d/override.conf" "auto-login"
        rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
    else
        echo "No auto-login configuration found."
    fi

    # Reload systemd configuration
    echo "Reloading systemd configuration..."
    systemctl daemon-reload

    # Check for kiosk configuration directory backups
    backup_dirs=( "$KIOSK_CONFIG_DIR.backup."* )
    if [ ${#backup_dirs[@]} -gt 0 ] && [ -d "${backup_dirs[-1]}" ]; then
        latest_backup="${backup_dirs[-1]}"
        echo "Backup found for kiosk configuration directory: $latest_backup"
        prompt_user restore_kiosk_config "Do you want to restore this backup before proceeding? (Y/n)" "Y"

        if [[ $restore_kiosk_config =~ ^[Yy]?$ ]]; then
            echo "Restoring backup for kiosk configuration directory..."
            if [ -d "$KIOSK_CONFIG_DIR" ]; then
                rm -rf "$KIOSK_CONFIG_DIR"
            fi
            cp -r "$latest_backup" "$KIOSK_CONFIG_DIR"
            echo "Backup restored."
        fi
    fi

    # Optionally remove installed packages
    if [[ -f "$KIOSK_CONFIG_DIR/installed-packages" ]]; then
        installed_packages=$(< "$KIOSK_CONFIG_DIR/installed-packages")
        echo "The following packages were installed:"
        echo "$installed_packages"

        prompt_user remove_packages "Do you want to remove the installed packages? (Y/n)" "Y"

        if [[ $remove_packages =~ ^[Yy]?$ ]]; then
            echo "Removing installed packages..."
            # Use read to properly handle package names with spaces
            IFS=' ' read -r -a pkg_array <<< "$installed_packages"
            for pkg in "${pkg_array[@]}"; do
                uninstall_package "$pkg"

                # Check if package was removed successfully
                if [[ $? -ne 0 ]]; then
                    echo "Failed to remove package: $pkg. Please check manually."
                else
                    echo "Package $pkg removed successfully."
                fi
            done
        else
            echo "Installed packages were not removed."
        fi
    else
        echo "No installed packages list found."
    fi

    echo "Uninstallation complete. The HA Chromium Kiosk setup has been removed."
}

## SCRIPT STARTS HERE
# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script needs to be run as root"
    echo "Re-run with sudo $0"
    exit 1
fi

print_banner

# Check if argument is provided
if [ -z "$1" ]; then
    print_usage
fi

# Main script logic to handle install or uninstall
case "$1" in
    install)
        check_create_user
        install_packages
        install_kiosk
        ;;
    uninstall)
        uninstall_kiosk
        uninstall_packages
        check_remove_user
        ;;
    *)
        print_usage
        ;;
esac

