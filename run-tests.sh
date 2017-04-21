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
    --tags=*)
    tags="${i#*=}"
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
mongo_host=${mongo_host:=localhost}
mongo_port=${mongo_port:=27017}
is_docker=${is_docker:=false}
tags=${tags:=~@ignore}
pwd=$(pwd)
pid_file=$pwd/tests/eidr-connect-test-server.pid
log_file=$pwd/tests/log/eidr-connect-test-server.log
killed=false
timeout_sec=60*5

function pauseForApp {
  end_time=$((`date +%s`+$timeout_sec))
  while ! grep -qs '=> App running at:' $log_file
  do
    if [ $killed = "true" ]; then
      exit 0
    fi
    current_time=`date +%s`
    if [ $current_time -gt $end_time ]; then
      echo "Server startup timed out."
      exit 1
    fi
    echo "Waiting for app to start... ${current_time}"
    sleep 2
  done
}

function finishTest {
  if [ $browser = "phantomjs" ]; then
    echo "Killing phantomjs"
    pkill phantomjs
  fi
  killed=true
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

$chimp .config/chimp.js \
  --watch=$watch \
  --ddp=$app_protocol://$app_host:$app_port \
  --browser=$browser \
  --tags=$tags \
  --chai=true \
  --debug=false
