#!/bin/bash
openbox &
setxkbmap de &

cd /workspace/usu/rc-client
exec xterm -u8 -e ./admin.sh

