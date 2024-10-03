#!/bin/bash

CONFIG_DIR="/home/__KIOSK_USER__/.config"
KIOSK_CONFIG_DIR="$CONFIG_DIR/ha-chromium-kiosk"
CONFIG_FILE="$KIOSK_CONFIG_DIR/config.json"

# Function to load configuration from a JSON file using Python
load_config() {
    local config_file=$1

    if [ ! -f "$config_file" ]; then
        echo "Configuration file $config_file does not exist!"
        exit 1
    fi

    # Load configuration values using Python
    echo "Loading configuration from $config_file..."
    eval $(python3 -c "
import sys, json
try:
    with open('$config_file', 'r') as f:
        config = json.load(f)
    for key, value in config['homeassistant'].items():
        print(f'export {key.upper()}=\"{value}\"')
except Exception as e:
    print('Error:', e)
    sys.exit(1)
")
}

# Load the Home Assistant configuration
load_config "$CONFIG_FILE"

# Print loaded environment variables for debugging
echo "Loaded configuration:"
echo "Host: $HA_HOSTNAME"
echo "IP Address: $HA_IP_ADDRESS"
echo "Port: $HA_PORT"
echo "Dashboard URL: $HA_DASHBOARD_URL"

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Optionally hide the mouse cursor
if [ "$CHROMIUM_HIDE_MOUSE" == "Y" ]; then
    unclutter -idle 0 &
fi

# Function to check network connectivity to Home Assistant
check_network() {
    while ! nc -z -w 5 "$HA_IP_ADDRESS" "$HA_PORT"; do
        echo "Checking if Home Assistant is reachable..."
        sleep 2
    done
}

# Check network and start Chromium browser pointing to the Home Assistant dashboard
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
    "$HA_DASHBOARD_URL"
