#!/bin/bash

export LANG=de_DE.UTF-8
export LC_ALL=de_DE.UTF-8

openbox &
setxkbmap de &
#cd /workspace/usu/rc-client
#xterm -u8 -e ./admin.sh &

#wir muessen Firefox vorbereiten
# 🔧 Firefox-Profil automatisch einrichten (stateless container)
PROFILE_NAME="minimalapp"
APP_URL="http://localhost:8087/vmwebjetty/vmweb"
TARGET_DIR="~/.mozilla/firefox"
PROFILE_DIR="$TARGET_DIR/ba4y551j.minimalapp"
ARCHIVE="firefox-profile.tar.gz"
# Prüfen, ob das Verzeichnis schon existiert
if [ -d "$PROFILE_DIR" ]; then
    echo "Profilverzeichnis '$PROFILE_DIR' existiert bereits. Entpacken wird übersprungen."
else
    #mkdir -p "$TARGET_DIR"
    cd $TARGET_DIR
    tar -xf "$ARCHIVE"
fi

# # Profil erstellen (wenn nicht vorhanden)
# if ! firefox -P | grep -q "$PROFILE_NAME"; then
#     firefox -CreateProfile "$PROFILE_NAME"
# fi

# # Profilverzeichnis finden
# PROFILE_DIR=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name "*.$PROFILE_NAME" | head -n 1)

# if [ -n "$PROFILE_DIR" ]; then
#     mkdir -p "$PROFILE_DIR/chrome"

# #     # userChrome.css schreiben
# #     cat > "$PROFILE_DIR/chrome/userChrome.css" <<EOF
# # #navigator-toolbox {
# #   display: none !important;
# # }
# # EOF

#     # user.js schreiben
#     echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' > "$PROFILE_DIR/user.js"
# fi

# Firefox im App-Modus starten (mit Neustart bei Schließen)
(
  while true; do
    firefox -P "$PROFILE_NAME" --no-remote "$APP_URL"
    echo "Firefox wurde geschlossen. Neustart in 5 Sekunden..."
    sleep 5
  done
) &

xterm -geometry 80x24+100+100 -fa 'Monospace' -fs 10 -u8 -e bash -c '
    cd /workspace/usu/rc-client
    while true; do
    ./admin.sh
    echo "Restart in 3 seconds..."
    sleep 3
    done
' &
#xterm -u8 -e bash -c 'while true; do chromium --app=http://localhost:8087/vmwebjetty/vmweb; echo "Restart in 2 seconds..."; sleep 2; done' &
# while true; do 
#     firefox --kiosk=http://localhost:8087/vmwebjetty/vmweb
#     echo "Restart in 2 seconds..."
#     sleep 2
# done &
#/usr/local/bin/postman/Postman >/tmp/postman.log 2>&1 &
wait