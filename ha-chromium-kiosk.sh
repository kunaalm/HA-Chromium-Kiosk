#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Kunaal Mahanti
# License: Apache License, Version 2.0
# URL: https://github.com/kunaalm/ha-chromium-kiosk
#
# This script sets up a light Chromium-based kiosk mode on a Debian server
# specifically for Home Assistant dashboards, without using a display manager.
# It configures a touch-friendly kiosk environment and provides options for hiding the mouse pointer.
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

# Print disclaimer
echo "DISCLAIMER:"
echo "This script is provided 'as is,' without warranty of any kind, express or implied."
echo "By using this script, you assume all risks. It is intended for educational and personal use only."
echo "This script is not recommended for commercial deployments."
echo "Press Ctrl+C to cancel if you do not agree with these terms."
sleep 10  # Pause for 10 seconds to give the user a chance to cancel

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

# Prompt user for the IP address of their Home Assistant instance
read -p "Enter the IP address of your Home Assistant instance: " HA_IP
if [[ -z "$HA_IP" ]]; then
    echo "The IP address is required. Please run the script again."
    exit 1
fi

# Ask for the Home Assistant port, defaulting to 8123
read -p "Enter the port for Home Assistant [default: 8123]: " HA_PORT
HA_PORT=${HA_PORT:-8123}

# Ask for the path to the Home Assistant dashboard, defaulting to lovelace/default_view
read -p "Enter the path to your Home Assistant dashboard [default: lovelace/default_view]: " HA_DASHBOARD_PATH
HA_DASHBOARD_PATH=${HA_DASHBOARD_PATH:-lovelace/default_view}

# Prompt to use kiosk mode
read -p "Do you want to enable kiosk mode? (y/n): " enable_kiosk
if [[ $enable_kiosk == "y" || $enable_kiosk == "Y" ]]; then
    KIOSK_MODE="?kiosk=true"
else
    KIOSK_MODE=""
fi

# Construct the full URL for the Home Assistant dashboard
KIOSK_URL="http://$HA_IP:$HA_PORT/$HA_DASHBOARD_PATH$KIOSK_MODE"
echo "Your Home Assistant dashboard will be displayed at: $KIOSK_URL"

KIOSK_USER="kiosk"

echo "Setting up Chromium Kiosk Mode for Home Assistant URL: $KIOSK_URL"

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
cat <<EOF >/usr/local/bin/ha-chromium-kiosk.sh
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
    echo "unclutter -idle 0 &" >>/usr/local/bin/ha-chromium-kiosk.sh
fi

cat <<EOF >>/usr/local/bin/ha-chromium-kiosk.sh

# Function to check network connectivity and service availability
check_network() {
    while true; do
        if nc -z -w 5 $HA_IP $HA_PORT; then
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

chmod +x /usr/local/bin/ha-chromium-kiosk.sh

# Step 7: Configure Openbox to start the kiosk script
echo "Configuring Openbox to start the kiosk script..."
echo "/usr/local/bin/ha-chromium-kiosk.sh &" >/home/$KIOSK_USER/.config/openbox/autostart
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.config

# Step 8: Create the systemd service for the kiosk
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
