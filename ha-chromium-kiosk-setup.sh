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
KIOSK_USER="kiosk"
CONFIG_DIR="/home/$KIOSK_USER/.config"
KIOSK_CONFIG_DIR="$CONFIG_DIR/ha-chromium-kiosk"
OPENBOX_CONFIG_DIR="$CONFIG_DIR/openbox"

DEFAULT_HA_PORT="8123"
DEFAULT_HA_DASHBOARD_PATH="lovelace/default_view"

PKGS_NEEDED=(xorg openbox chromium xserver-xorg xinit unclutter curl)

## FUNCTIONS ##

# Print usage
print_usage() {
    echo "Usage: sudo $0 {install|uninstall}"
    exit 1
}

# Install the necessary packages
# Keep track of the installed packages for later removal
install_packages() {
    # Create the kiosk configuration directory
    mkdir -p "$KIOSK_CONFIG_DIR"
    
    # Install the necessary packages and keep track of what was installed 
    missing_pkgs=()

    echo "Checking required packages..."

    # Create a list of packages that need to be checked
    pkgs_list="${PKGS_NEEDED[*]}"

    # Get the install status of all required packages at once
    dpkg_query_output=$(dpkg-query -W -f='${Package} ${Status}\n' $pkgs_list 2>/dev/null)

    for pkg in "${PKGS_NEEDED[@]}"; do
        if ! echo "$dpkg_query_output" | grep -q "^$pkg install ok installed$"; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        echo "The following packages are missing and will be installed: ${missing_pkgs[*]}"
        if ! apt install -y "${missing_pkgs[@]}"; then
            echo "Failed to install the required packages. Exiting..."
            exit 1
        fi
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
            
            # Uninstall the packages and handle errors
            if ! apt-get purge -y $installed_packages; then
                echo "Failed to purge some of the installed packages."
                exit 1
            fi

            if ! apt-get autoremove -y; then
                echo "Failed to autoremove some unnecessary packages."
                exit 1
            fi
            
            echo "Packages removed successfully."
        else
            echo "No packages to remove."
        fi
    else
        echo "No installed packages file found."
    fi
}

# Check and create user
check_create_user() {
    if id "$KIOSK_USER" &>/dev/null; then
        # wait until user input to use existing user or create a new one, default to use existing
        while true; do
            read -p "The kiosk user already exists. Do you want to use the existing user? (Y/n): " use_existing
            if [[ $use_existing =~ ^[YyNn]?$ ]]; then
                use_existing=${use_existing:-y}
                break
            fi
        done

        # if user does not want to use existing user, ask for a new username
        if [[ $use_existing =~ ^[nN]$ ]]; then
            read -p "Enter a different username for the kiosk user: " KIOSK_USER
            if id "$KIOSK_USER" &>/dev/null; then
                echo "The user already exists. Please remove the user before running the script."
                exit 1
            fi
        fi
    fi 

    echo "Creating the kiosk user..."
    if ! adduser --disabled-password --gecos "" "$KIOSK_USER"; then
        echo "Failed to create the kiosk user. Exiting..."
        exit 1
    fi
}

# Check and remove user if needed
check_remove_user() {
    if id "$KIOSK_USER" &>/dev/null; then
        read -p "The kiosk user exists. Do you want to remove the user? (Y/n): " remove_user
        if [[ $remove_user =~ ^[Yy]?$ ]]; then
            echo "Removing the kiosk user..."
            userdel -r "$KIOSK_USER"
        else
            echo "The kiosk user was not removed."
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
    # Print disclaimer
    echo "DISCLAIMER:"
    echo "This script is provided 'as is,' without warranty of any kind, express or implied."
    echo "By using this script, you assume all risks. It is intended for educational and personal use only."
    echo "This script is not recommended for commercial deployments."
    echo "Press Ctrl+C to cancel if you do not agree with these terms."
    sleep 5

    # Prompt user for necessary inputs
    prompt_user HA_IP "Enter the IP address of your Home Assistant instance" ""
    prompt_user HA_PORT "Enter the port for Home Assistant" "8123"
    prompt_user HA_DASHBOARD_PATH "Enter the path to your Home Assistant dashboard" "lovelace/default_view"

    # Kiosk mode and cursor settings
    prompt_user enable_kiosk "Do you want to enable kiosk mode? (Y/n)" "Y"
    prompt_user hide_cursor "Do you want to hide the mouse cursor? (Y/n)" "Y"

    KIOSK_MODE=""
    [[ $enable_kiosk =~ ^[Yy]$ ]] && KIOSK_MODE="?kiosk=true"

    KIOSK_URL="http://$HA_IP:$HA_PORT/$HA_DASHBOARD_PATH$KIOSK_MODE"
    echo "Your Home Assistant dashboard will be displayed at: $KIOSK_URL"
    echo "Setting up Chromium Kiosk Mode for Home Assistant URL:$KIOSK_URL"

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
    systemctl restart getty@tty1.service

    # Configure Openbox
    echo "Configuring Openbox for the kiosk user..."
    sudo -u $KIOSK_USER mkdir -p $OPENBOX_CONFIG_DIR

    # Create the kiosk startup script
    echo "Creating the kiosk startup script..."
    cat <<EOF >/usr/local/bin/ha-chromium-kiosk.sh
#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Optionally hide the mouse cursor
EOF

    [[ $hide_cursor =~ ^[Yy]$ ]] && echo "unclutter -idle 0 &" >>/usr/local/bin/ha-chromium-kiosk.sh

    cat <<EOF >>/usr/local/bin/ha-chromium-kiosk.sh

check_network() {
    while ! nc -z -w 5 $HA_IP $HA_PORT; do
        echo "Checking if Home Assistant is reachable..."
        sleep 2
    done
}

check_network
echo "Home Assistant is reachable. Starting Chromium..."

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

    chmod +x /usr/local/bin/ha-chromium-kiosk.sh

    echo "Configuring Openbox to start the kiosk script..."
    echo "/usr/local/bin/ha-chromium-kiosk.sh &" > $OPENBOX_CONFIG_DIR/autostart

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

    systemctl daemon-reload
    systemctl enable ha-chromium-kiosk.service

    echo "Adding the kiosk user to the tty group..."
    usermod -aG tty $KIOSK_USER

    # Prompt for immediate reboot
    prompt_user reboot_now "Setup is complete. Do you want to reboot now?" "n"
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

    # Reload systemd configuration
    echo "Reloading systemd configuration..."
    systemctl daemon-reload

    # Optionally remove installed packages
    if [[ -f "$KIOSK_CONFIG_DIR/installed-packages" ]]; then
        installed_packages=$(< "$KIOSK_CONFIG_DIR/installed-packages")
        echo "The following packages were installed:"
        echo "$installed_packages"
        
        prompt_user remove_packages "Do you want to remove the installed packages? (Y/n)" "Y"
        
        if [[ $remove_packages =~ ^[Yn]?$ ]]; then
            echo "Removing installed packages..."
            apt-get remove --purge -y $installed_packages
            
            # Check if packages were removed successfully
            if [[ $? -ne 0 ]]; then
                echo "Failed to remove some packages. Please check manually."
            else
                echo "Packages removed successfully."
            fi
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
    echo "Please run as root using sudo."
    exit 1
fi

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

