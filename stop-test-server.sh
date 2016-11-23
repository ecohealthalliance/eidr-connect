#!/bin/bash
pwd=$(pwd)
if [ -f /tmp/eidr-test-server.pid ]; then
  PID=`cat /tmp/eidr-test-server.pid`
  if [ -e /proc/$PID ]; then
    echo $'\nStopping the test server'
    kill $PID
  fi
  rm /tmp/eidr-test-server.pid
  rm ${pwd}/tests/log/eidr-test-server.log
fi

