# Tastatur und Locale setzen
setxkbmap de &
export LANG=de_DE.UTF-8
export LC_ALL=de_DE.UTF-8

# Fenstermanager starten
openbox &

cd /workspace/usu/rc-client
exec xterm -u8 -e ./admin.sh

# # Warten bis Webdienst erreichbar ist
# while ! curl -s --head http://localhost:8087/vmwebjetty/vmweb | grep "200 OK" > /dev/null; do
#   echo "Wait webservice on port 8087... (60sec)"
#   sleep 30
# done

# # Browser im Kiosk-Modus starten
# #chromium --kiosk http://localhost:8087/vmwebjetty/vmweb &
# # Alternativ:
# chromium --app=http://localhost:8087/vmwebjetty/vmweb &
# # Starte Postman
# postman &
# # Sitzung offen halten
# wait

