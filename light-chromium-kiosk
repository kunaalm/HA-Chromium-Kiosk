#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Kunaal Mahanti
# License: Apache License, Version 2.0
# URL: https://github.com/kunaalm/light-chromium-kiosk
#
# This script sets up a light Chromium-based kiosk mode on a Debian server
# without using a display manager. It configures a touch-friendly kiosk
# environment and provides options for hiding the mouse pointer.
#
# DISCLAIMER:
# This script is provided "as is," without warranty of any kind, express or
# implied. By using this script, you assume all risks. This script is intended
# for educational and personal use only and is not recommended for commercial
# deployments.
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
# -----------------------------------------------------------------------------

# Display the disclaimer
echo "-------------------------------------------------------------"
echo "DISCLAIMER:"
echo "This script is provided 'as is,' without warranty of any kind."
echo "By using this script, you assume all risks. This script is"
echo "intended for educational and personal use only and is not"
echo "recommended for commercial deployments."
echo "-------------------------------------------------------------"
read -p "Do you wish to proceed? (y/n): " proceed
if [[ $proceed != "y" && $proceed != "Y" ]]; then
    echo "Exiting the script. No changes have been made."
    exit 1
fi

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root using sudo"
    exit
fi

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Usage: sudo $0 <URL>"
    exit 1
fi

KIOSK_URL=$1
KIOSK_USER="kiosk"

echo "Setting up Chromium Kiosk Mode for URL: $KIOSK_URL"

# Step 1: Update and upgrade the system
echo "Updating and upgrading the system..."
apt update && apt upgrade -y

# Step 2: Create the kiosk user
echo "Creating the kiosk user..."
adduser --disabled-password --gecos "" $KIOSK_USER

# Step 3: Install necessary packages
echo "Installing required packages..."
apt install -y xorg openbox chromium xserver-xorg xinit unclutter netcat curl

# Step 4: Set up auto login for the kiosk user
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

# Step 5: Configure Openbox
echo "Configuring Openbox for the kiosk user..."
sudo -u $KIOSK_USER mkdir -p /home/$KIOSK_USER/.config/openbox

# Step 6: Create the kiosk startup script
echo "Creating the kiosk startup script..."
cat <<EOF >/usr/local/bin/light-chromium-kiosk.sh
#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Optionally hide the mouse cursor
EOF

# Prompt the user about hiding the cursor
read -p "Do you want to hide the mouse cursor? (y/n): " hide_cursor
if [[ $hide_cursor == "y" || $hide_cursor == "Y" ]]; then
    echo "unclutter -idle 0 &" >>/usr/local/bin/light-chromium-kiosk.sh
fi

cat <<EOF >>/usr/local/bin/light-chromium-kiosk.sh

# Function to check network connectivity and service availability
check_network() {
    while true; do
        if nc -z -w 5 192.168.1.1 80; then
            break
        else
            sleep 2
        fi
    done
}

check_network

# Start Chromium in a loop to ensure it restarts if it crashes
while true; do
    chromium \
        --noerrdialogs \
        --disable-infobars \
        --kiosk \
        --incognito \
        --disable-session-crashed-bubble \
        --disable-features=TranslateUI \
        --overscroll-history-navigation=0 \
        --pull-to-refresh=2 \
        "$KIOSK_URL" &
    wait \$!
    sleep 2
done
EOF

chmod +x /usr/local/bin/light-chromium-kiosk.sh

# Step 7: Configure Openbox to start the kiosk script
echo "Configuring Openbox to start the kiosk script..."
echo "/usr/local/bin/light-chromium-kiosk.sh &" >/home/$KIOSK_USER/.config/openbox/autostart
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.config

# Step 8: Create the systemd service for the kiosk
echo "Creating the systemd service..."
cat <<EOF >/etc/systemd/system/light-chromium-kiosk.service
[Unit]
Description=Chromium Kiosk Mode
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
systemctl enable light-chromium-kiosk.service

# Step 9: Add kiosk user to the tty group
echo "Adding the kiosk user to the tty group..."
usermod -aG tty $KIOSK_USER

# Prompt for immediate reboot
read -p "Setup is complete. Do you want to reboot now? (y/n): " reboot_now
if [[ $reboot_now == "y" || $reboot_now == "Y" ]]; then
    echo "Rebooting the system..."
    reboot
else
    echo "Setup is complete. Please reboot the system manually when ready."
fi
