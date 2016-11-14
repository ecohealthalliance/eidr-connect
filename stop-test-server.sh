#!/bin/bash

if [ ! -f ".test-server.pid" ]; then
  echo "Error: the test-server is not running."
  exit 1
fi

echo 'Stopping test-server...'
kill `cat .test-server.pid`
rm .test-server.pid
