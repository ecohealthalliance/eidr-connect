#!/bin/bash

# example:
#
# npm start-test
# ./run-tests.sh --watch=false --app_host=localhost --app_port=3001 --browser=phantomjs
 
for i in "$@"
do
case $i in
    --app_protocol=*)
    app_host="${i#*=}"
    shift
    ;;
    --app_host=*)
    app_host="${i#*=}"
    shift
    ;;
    --app_port=*)
    app_port="${i#*=}"
    shift
    ;;
    --test_db=*)
    test_db="${i#*=}"
    shift
    ;;
    --mongo_host=*)
    mongo_host="${i#*=}"
    shift
    ;;
    --mongo_port=*)
    mongo_port="${i#*=}"
    shift
    ;;
    --watch=*)
    watch="${i#*=}"
    shift
    ;;
    --is_docker=*)
    is_docker="${i#*=}"
    shift
    ;;
    --browser=*)
    browser="${i#*=}"
    shift
    ;;  
    *)
    ;;
esac
shift
done

# use args or default
app_protocol=${app_protocol:=http}
app_host=${app_host:=localhost}
app_port=${app_port:=3001}
watch=${watch:=false}
browser=${browser:=phantomjs}
test_db=${test_db:=eidr-connect-test}
mongo_host=${mongo_host:=mongodb}
mongo_port=${mongo_port:=27017}
is_docker=${is_docker:=false}
pwd=$(pwd)
killed=false

function pauseForApp {
  while ! grep -qs '=> App running at:' ${pwd}/tests/log/eidr-test-server.log
  do
    if [ $killed = "true" ]; then
      exit 0
    fi
    echo "Waiting for app to start... ${killed}"
    sleep 2
  done
}

if [ ! -f "/tmp/eidr-test-server.pid" ]; then
  echo "Starting the test server..."
  ${pwd}/start-test-server.sh --app_host=$app_host --app_port=$app_port --mongo_host=$mongo_host --mongo_port=$mongo_port --test_db=$test_db --is_docker=$is_docker &
  started=true
  # give some time for pid to be created
  sleep 1
fi

if [ ! -f "/tmp/eidr-test-server.pid" ]; then
  echo "Error: is the test-server running?"
  exit 1
fi

function finishTest {
  killed=true
  if [ $started ]; then
    # only stop the test server if this script started it
    ./stop-test-server.sh --is_docker=$is_docker
  fi
}

trap finishTest EXIT
trap finishTest INT
trap finishTest SIGINT  # 2
trap finishTest SIGQUIT # 3
trap finishTest SIGKILL # 9
trap finishTest SIGTERM # 15

# determine if the app has started by grep on the log
pauseForApp

chimp=node_modules/chimp/bin/chimp.js

$chimp --watch=$watch --ddp=$app_protocol://$app_host:$app_port \
        --path=tests/ \
        --browser=$browser \
        --coffee=true \
        --compiler=coffee:coffee-script/register
