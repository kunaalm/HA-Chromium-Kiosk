#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Optionally hide the mouse cursor
if [ "$CHROMIUM_HIDE_MOUSE" == "Y" ]; then
    unclutter -idle 0 &
fi

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