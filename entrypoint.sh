#!/bin/sh

set -e

# Standardkonfiguration erzeugen falls torrc fehlt
if [ ! -f /tor/torrc ]; then
    echo "Keine torrc vorhanden, erstelle torrc aus torrc.default"
    cp /tor/torrc.default /tor/torrc
fi

# Logging aktivieren
echo "Log notice stdout" >> /tor/torrc

# Watchdog: Neustarten bei Crash
while true; do
    echo "Starte Tor..."
    /tor/tor -f /tor/torrc
    echo "Tor-Prozess wurde beendet. Neustart in 5 Sekunden..."
    sleep 5
done
