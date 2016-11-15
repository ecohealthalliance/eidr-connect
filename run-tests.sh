#!/bin/bash

# example:
#
# npm start-test
# ./run-tests.sh --watch=false --app_uri=http://127.0.0.1 --app_port=3001

for i in "$@"
do
case $i in
    --app_uri=*)
    app_uri="${i#*=}"
    shift
    ;;
    --app_port=*)
    app_port="${i#*=}"
    shift
    ;;
    --watch=*)
    watch="${i#*=}"
    shift
    ;;
    *)
    ;;
esac
shift
done

if [ ! -f ".test-server.pid" ]; then
  echo "Error: is the test-server running?"
  exit 1
fi

# use args or default
app_uri=${app_uri:=http://localhost}
app_port=${app_port:=3001}
watch=${watch:=false}

chimp=node_modules/chimp/bin/chimp.js

$chimp --watch=$watch --ddp=$app_uri:$app_port \
        --path=tests/ \
        --coffee=true \
        --compiler=coffee:coffee-script/register \

# Output time elapsed
if [ "$WATCH" != "true" ]; then
  echo ''
  echo "$(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds elapsed"
  echo ''
fi
