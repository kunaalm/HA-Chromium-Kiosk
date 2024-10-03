#!/bin/bash
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

CONFIG_DIR=".config"

KIOSK_CONFIG_DIR="$CONFIG_DIR/ha-chromium-kiosk"
CONFIG_FILE="$KIOSK_CONFIG_DIR/config.json"
INSTALL_FILE="$KIOSK_CONFIG_DIR/installation.json"

OPENBOX_CONFIG_DIR="$CONFIG_DIR/openbox"

# Separate variables to hold the configuration for each file
HA_CONFIG=""
INST_CONFIG=""

# Variables to hold configuration values
HA_HOSTNAME=""
HA_IP_ADDRESS=""
HA_PORT=""
HA_DASHBOARD_URL=""
HA_KIOSK_MODE=""
CHROMIUM_HIDE_MOUSE=""
CHROMIUM_PULL_TO_REFRESH=""
KIOSK_USER=""
KIOSK_USER_EXISTING=""

declare -A PACKAGES  # Associative array to hold all package values (key-value pairs)


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

# Function to load a JSON file into the respective variable
load_config() {
    local config_file=$1
    local config_data_var=$2

    eval "$config_data_var=\$(python3 -c \"
import sys, json
with open('$config_file', 'r') as f:
    config = json.load(f)
    print(json.dumps(config))
    \")"
}

# Function to retrieve a value from the loaded configuration
get_json_value() {
    local config_data=$1
    local key=$2
    python3 -c "
import sys, json
config = json.loads('$config_data')
print(eval('config' + \"$key\"))
    "
}

# Function to retrieve all package names and their values into the associative array
load_packages() {
    local config_data=$1
    local package_keys=$(python3 -c "
import sys, json
config = json.loads('$config_data')
print(' '.join(config['package'].keys()))
    ")

    for package_key in $package_keys; do
        PACKAGES["$package_key"]=$(get_json_value "$config_data" "['package']['$package_key']")
    done
}

# Function to update the configuration in memory and write it back to the file
update_json_value() {
    local config_file=$1
    local config_data=$2
    local key=$3
    local value=$4
    updated_config=$(python3 -c "
import sys, json
config = json.loads('$config_data')

# Navigate to the specified key and update the value
keys = \"$key\".split('.')
current = config
for k in keys[:-1]:
    current = current[k]
current[keys[-1]] = \"$value\"

# Return the updated config as a JSON string
print(json.dumps(config))
    ")

    # Write the updated configuration back to the file
    python3 -c "
import sys, json
with open('$config_file', 'w') as f:
    json.dump(json.loads('$updated_config'), f, indent=4)
    "
}

# Function to read all parameters from both config files into variables
read_all_parameters() {
    # Load config.json (Home Assistant)
    CONFIG_FILE="config.json"
    load_config "$CONFIG_FILE" "HA_CONFIG"
    
    HA_HOSTNAME=$(get_json_value "$HA_CONFIG" "['homeassistant']['hostname']")
    HA_IP_ADDRESS=$(get_json_value "$HA_CONFIG" "['homeassistant']['ip_address']")
    HA_PORT=$(get_json_value "$HA_CONFIG" "['homeassistant']['port']")
    HA_DASHBOARD_URL=$(get_json_value "$HA_CONFIG" "['homeassistant']['dashboard_url']")
    HA_KIOSK_MODE=$(get_json_value "$HA_CONFIG" "['homeassistant']['kiosk_mode']")
    CHROMIUM_HIDE_MOUSE=$(get_json_value "$HA_CONFIG" "['chromium']['hide_mouse']")
    CHROMIUM_PULL_TO_REFRESH=$(get_json_value "$HA_CONFIG" "['chromium']['pull_to_refresh']")

    # Load installation.json (Installation Config)
    INSTALL_FILE="installation.json"
    load_config "$INSTALL_FILE" "INST_CONFIG"
    
    KIOSK_USER=$(get_json_value "$INST_CONFIG" "['kiosk user']['name']")
    KIOSK_USER_EXISTING=$(get_json_value "$INST_CONFIG" "['kiosk user']['existing']")

    # Dynamically load all package values into the associative array
    load_packages "$INST_CONFIG"
}

# Function to write all updated parameters back to the config files
write_all_parameters() {
    # Write back to config.json (Home Assistant)
    update_json_value "config.json" "$HA_CONFIG" "homeassistant.hostname" "$HA_HOSTNAME"
    update_json_value "config.json" "$HA_CONFIG" "homeassistant.ip_address" "$HA_IP_ADDRESS"
    update_json_value "config.json" "$HA_CONFIG" "homeassistant.port" "$HA_PORT"
    update_json_value "config.json" "$HA_CONFIG" "homeassistant.dashboard_url" "$HA_DASHBOARD_URL"
    update_json_value "config.json" "$HA_CONFIG" "homeassistant.kiosk_mode" "$HA_KIOSK_MODE"
    update_json_value "config.json" "$HA_CONFIG" "chromium.hide_mouse" "$CHROMIUM_HIDE_MOUSE"
    update_json_value "config.json" "$HA_CONFIG" "chromium.pull_to_refresh" "$CHROMIUM_PULL_TO_REFRESH"
    
    # Write back to installation.json (Installation Config)
    update_json_value "installation.json" "$INST_CONFIG" "kiosk user.name" "$KIOSK_USER"
    update_json_value "installation.json" "$INST_CONFIG" "kiosk user.existing" "$KIOSK_USER_EXISTING"
    
    # Loop through the packages array and write the updated values back to the file
    for package_key in "${!PACKAGES[@]}"; do
        update_json_value "installation.json" "$INST_CONFIG" "package.$package_key" "${PACKAGES[$package_key]}"
    done
}

# Install a package and print dots while waiting
install_package() {
    package=$1  # Corrected assignment syntax

    # Start a background job to print dots
    while true; do
        echo -n "..."
        sleep 1
    done &

    # Capture the PID of the background job
    DOT_PID=$!

    # Run apt-get update and install silently
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y "$package" > /dev/null 2>&1  # Quoting $package for safety
    # Capture the exit status of the apt-get command
    apt_status=$?

    # Kill the background job
    kill $DOT_PID

    # Wait for the background job to completely terminate
    wait $DOT_PID 2>/dev/null
    # Return the exit status of the apt-get command
    return $apt_status
}

# Uninstall the installed package and print dots while waiting
uninstall_package() {
    package=$1

    # Start a background job to print dots
    while true; do
        echo -n "..."
        sleep 1
    done &

    # Capture the PID of the background job
    DOT_PID=$!

    # Run apt-get remove silently
    sudo apt-get remove --purge -y "$package" > /dev/null 2>&1
    # Capture the exit status of the apt-get command
    apt_status=$?

    # Kill the background job
    kill $DOT_PID

    # Wait for the background job to completely terminate
    wait $DOT_PID 2>/dev/null
    # Return the exit status of the apt-get command
    return $apt_status
}

# Install the necessary packages
# Keep track of the installed packages for later removal
install_packages() {
    # Create the kiosk configuration directory
    sudo -u $KIOSK_USER mkdir -p "$KIOSK_CONFIG_DIR"
    
    # Install the necessary packages and keep track of what was installed 
    missing_pkgs=()

    echo "Checking required packages..."

    # Loop through the PACKAGES array to check which ones need installation
    for package_key in "${!PACKAGES[@]}"; do
        if [ "${PACKAGES[$package_key]}" = "needed" ]; then
            # Check if the package is installed using dpkg-query
            if dpkg -s "$package_key" > /dev/null 2>&1; then
                # If the package is already installed, update its status
                PACKAGES[$package_key]="pre-installed"
                echo "$package_key is already installed (pre-installed)."
            else
                # If not installed, add it to the list of packages to install
                missing_pkgs+=("$package_key")
            fi
        fi
    done

    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        echo "Installing missing packages..."
        total_pkgs=${#missing_pkgs[@]}
        current_pkg=0

        for pkg in "${missing_pkgs[@]}"; do
            current_pkg=$((current_pkg + 1))
            echo -ne "Installing package $current_pkg of $total_pkgs: $pkg "

            if ! install_package "$pkg"; then
                echo "Failed to install package: $pkg"
                exit 1
            fi

            # After a successful installation, update the package status
            PACKAGES[$pkg]="installed"
            echo " Done."
        done

        echo "All missing packages have been installed."
    else
        echo "All prerequisites are already installed."
    fi
}

# Uninstall only the that were packages installed by the script
uninstall_packages() {
    echo "Checking for packages to uninstall..."

    # Initialize an array to hold the packages that need to be uninstalled
    packages_to_remove=()

    # Loop through the PACKAGES array and check for packages marked as "installed"
    for package_key in "${!PACKAGES[@]}"; do
        if [ "${PACKAGES[$package_key]}" = "installed" ]; then
            packages_to_remove+=("$package_key")
        fi
    done

    # If there are packages to uninstall, proceed
    if [ ${#packages_to_remove[@]} -ne 0 ]; then
        echo "Removing installed packages..."

        total_pkgs=${#packages_to_remove[@]}
        current_pkg=0

        for pkg in "${packages_to_remove[@]}"; do
            current_pkg=$((current_pkg + 1))
            echo -ne "Uninstalling package $current_pkg of $total_pkgs: $pkg "

            # Uninstall the package using the provided uninstall_package function
            if ! uninstall_package "$pkg"; then
                echo "Failed to uninstall package: $pkg"
                exit 1
            fi

            echo " Done."

            # Optionally, update the package statuses in the PACKAGES array to indicate removal
            PACKAGES[$pkg]="removed"
        done

        echo "All installed packages have been removed."
    else
        echo "No packages to remove."
    fi
}

# Check and create user
check_create_user() {
    # Ensure KIOSK_USER and KIOSK_USER_EXISTING are set
    if [ -z "$KIOSK_USER" ]; then
        echo "No username provided. Please set KIOSK_USER."
        exit 1
    fi

    if [ "$KIOSK_USER_EXISTING" = "true" ]; then
        echo "Using the existing user: $KIOSK_USER."
        return
    fi

    # If KIOSK_USER_EXISTING is false, or not defined, check if the user exists
    while id "$KIOSK_USER" &>/dev/null; do
        # Prompt to use existing user or create a new one
        read -p "The kiosk user '$KIOSK_USER' already exists. Do you want to use the existing user? (Y/n): " use_existing
        use_existing=${use_existing:-Y}

        if [[ $use_existing =~ ^[Yy]$ ]]; then
            echo "Using the existing user."
            KIOSK_USER_EXISTING="true"  # Update the user status in memory
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
    if ! adduser --disabled-password --gecos "" "$KIOSK_USER" 2>&1 >/dev/null; then
        echo "Failed to create the kiosk user. Exiting..."
        exit 1
    fi

    # After successfully creating the user, update the status
    KIOSK_USER_EXISTING="true"  # Update the status in memory
    echo "Kiosk user '$KIOSK_USER' created successfully."
}

check_remove_user() {
    if id "$KIOSK_USER" &>/dev/null; then
        if [ "$KIOSK_USER_EXISTING" = "true" ]; then
            read -p "The kiosk user exists. Do you want to remove the user? (Y/n): " remove_user
            remove_user=${remove_user:-N}

            if [[ $remove_user =~ ^[Yy]$ ]]; then
                echo "Removing the kiosk user..."
                if userdel -rf "$KIOSK_USER"; then
                    echo "User '$KIOSK_USER' removed successfully."
                    KIOSK_USER_EXISTING="false"  # Update the status in memory
                else
                    echo "Failed to remove the kiosk user."
                    exit 1
                fi
            else
                echo "The kiosk user was not removed."
            fi
        else
            echo "User '$KIOSK_USER' does not exist according to the configuration."
        fi
    else
        echo "The kiosk user does not exist."
    fi
}

# Prompt user function
prompt_user() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3
    
    read -p "$prompt_message [$default_value]: " value
    value=${value:-$default_value}
    
    if [[ -z "$value" && -z "$default_value" ]]; then
        echo "Error: $var_name is required. Please run the script again."
        exit 1
    fi
    
    eval $var_name=\$value
}

# Install the kiosk setup
install_kiosk() {
    # Prompt user for necessary inputs
    prompt_user HA_IP_ADDRESS "Enter the IP address of your Home Assistant instance" "$HA_IP_ADDRESS"
    prompt_user HA_PORT "Enter the port for Home Assistant" "$HA_PORT"
    prompt_user HA_DASHBOARD_PATH "Enter the path to your Home Assistant dashboard" "$HA_DASHBOARD_URL"

    # Kiosk mode and cursor settings
    prompt_user HA_KIOSK_MODE "Do you want to enable kiosk mode? (Y/n)" "$HA_KIOSK_MODE"
    prompt_user CHROMIUM_HIDE_MOUSE "Do you want to hide the mouse cursor? (Y/n)" "$CHROMIUM_HIDE_MOUSE"

    KIOSK_MODE=""
    [[ $HA_KIOSK_MODE =~ ^[Yy]$ ]] && KIOSK_MODE="?kiosk=true"

    KIOSK_URL="http://$HA_IP:$HA_PORT/$HA_DASHBOARD_PATH$KIOSK_MODE"
    echo "Your Home Assistant dashboard will be displayed at: $KIOSK_URL"
    echo "Setting up Chromium Kiosk Mode for Home Assistant URL:$KIOSK_URL"

    # Configure auto login
    echo "Configuring auto-login for the kiosk user..."
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    curl -o /etc/systemd/system/getty@tty1.service.d/override.conf \
        https://github.com/kunaalm/ha-chromium-kiosk/raw/main/src/override.conf

    # Adjust ExecStart line as required
    sed -i "s/__KIOSK_USER__/$KIOSK_USER/g" /etc/systemd/system/getty@tty1.service.d/override.conf

    systemctl daemon-reload
    systemctl restart getty@tty1.service

    # Configure Openbox
    echo "Configuring Openbox for the kiosk user..."
    sudo -u "$KIOSK_USER" mkdir -p "/home/$KIOSK_USER/$OPENBOX_CONFIG_DIR"

    # Download the kiosk startup script
    echo "Downloading the kiosk startup script..."
    curl -o /usr/local/bin/ha-chromium-kiosk.sh \
        https://github.com/kunaalm/ha-chromium-kiosk/raw/main/src/ha-chromium-kiosk.sh

    chmod +x /usr/local/bin/ha-chromium-kiosk.sh

    # Update necessary placeholders in the downloaded script
    sed -i "s/__KIOSK_USER__/$KIOSK_USER/g" /usr/local/bin/ha-chromium-kiosk.sh

    echo "Configuring Openbox to start the kiosk script..."
    curl -o "$OPENBOX_CONFIG_DIR/autostart" \
        https://github.com/kunaalm/ha-chromium-kiosk/raw/main/src/autostart
    
    # Create the systemd service
    echo "Downloading the systemd service file..."
    curl -o /etc/systemd/system/ha-chromium-kiosk.service \
        https://github.com/kunaalm/ha-chromium-kiosk/raw/main/src/ha-chromium-kiosk.service

    # Ensure the service uses the correct KIOSK_USER
    sed -i "s/__KIOSK_USER__/$KIOSK_USER/g" /etc/systemd/system/ha-chromium-kiosk.service

    systemctl daemon-reload
    systemctl enable ha-chromium-kiosk.service

    echo "Adding the kiosk user to the tty group..."
    usermod -aG tty "$KIOSK_USER"

    # Prompt for immediate reboot
    prompt_user reboot_now "Setup is complete. Do you want to reboot now?" "Y"
    [[ $reboot_now =~ ^[Yy]$ ]] && { echo "Rebooting the system..."; reboot; } || echo "Setup is complete. Please reboot the system manually when ready."
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

    # Remove the systemd service file
    echo "Removing the systemd service file..."
    rm -f /etc/systemd/system/ha-chromium-kiosk.service

    # Remove the startup script
    echo "Removing the kiosk startup script..."
    rm -f /usr/local/bin/ha-chromium-kiosk.sh

    # Remove the autostart entry for Openbox
    echo "Removing Openbox autostart configuration..."
    if [[ -f $OPENBOX_CONFIG_DIR/autostart ]]; then
        rm -f $OPENBOX_CONFIG_DIR/autostart
    else
        echo "No Openbox autostart configuration found."
    fi

    # Remove the auto-login configuration
    echo "Removing auto-login configuration..."
    if [[ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]]; then
        rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
    else
        echo "No auto-login configuration found."
    fi

    # Reload systemd configuration
    echo "Reloading systemd configuration..."
    systemctl daemon-reload
}

# Function to check if Python is installed
check_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Python3 could not be found. Please install it before running this script."
        exit 1
    else
        echo "Python3 is installed."
    fi
}

## SCRIPT STARTS HERE
# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script needs to be run as root"
    echo "Re-run with sudo $0"
    exit 1
fi

print_banner
check_python

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
        echo "Uninstallation complete. The HA Chromium Kiosk setup has been removed."
        ;;
    *)
        print_usage
        ;;
esac

