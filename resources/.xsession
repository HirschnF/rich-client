#!/bin/bash
openbox &
setxkbmap de &
#cd /workspace/usu/rc-client
#xterm -u8 -e ./admin.sh &

xterm -u8 -e bash -c 'cd /workspace/usu/rc-client; while true; do ./admin.sh; echo "Restart in 2 seconds..."; sleep 2; done' &
#xterm -u8 -e bash -c 'while true; do chromium --app=http://localhost:8087/vmwebjetty/vmweb; echo "Restart in 2 seconds..."; sleep 2; done' &
while true; do 
    chromium --app=http://localhost:8087/vmwebjetty/vmweb
    echo "Restart in 2 seconds..."
    sleep 2
done &
#/usr/local/bin/postman/Postman >/tmp/postman.log 2>&1 &
wait