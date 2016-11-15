#!/bin/bash
meteor test --port 13000 --full-app --driver-package tmeasday:acceptance-test-driver --settings settings-dev.json &
APP_PID=$!
# The app needs a lot of time to start up before a ddp connection is attempted.
sleep 160

chimp=node_modules/chimp/bin/chimp.js

# Run the tests
$chimp .config/chimp.js --ddp=http://localhost:13000 \
    --path=tests/ \
    --browser=phantomjs \
    --debug=true

# Output time elapsed
echo "$(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds elapsed"

kill $APP_PID
