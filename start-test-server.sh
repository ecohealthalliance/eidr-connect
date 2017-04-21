#!/bin/bash
#
# Starts meteor with a standalone MONGO_URL pointing to the test database.
# Author: Dan Nyanko <nyanko@ecohealthalliance.org>
#
# example:
# ./start-test-server.sh --app_port=3001 --mongo_host=127.0.0.1 --mongo_port=27017 --prod_db=eidr-connect --test_db=eidr-connect-test

for i in "$@"
do
case $i in
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
    --app_port=*)
    app_port="${i#*=}"
    shift
    ;;
    --is_docker=*)
    is_docker="${i#*=}"
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

# use args or default
test_db=${test_db:=eidr-connect-test}
mongo_host=${mongo_host:=mongodb}
mongo_port=${mongo_port:=27017}
app_port=${app_port:=3001}
is_docker=${is_docker:=false}
shared_dir=${SHARED_DIR:=/shared}
pwd=$(pwd)
mongo=node_modules/mongodb-prebuilt/binjs
pid_file=$pwd/tests/eidr-connect-test-server.pid
mkdir -p $pwd/tests/log
log_file=$pwd/tests/log/eidr-connect-test-server.log
touch $log_file

if [ -f "${pid_file}" ]; then
  echo "Error: the test-server is already running."
  exit 1
fi

echo "Dropping testing '${test_db}' if it exists..."
if [ $is_docker = "true" ]; then
  mongo --host $mongo_host --port $mongo_port $test_db --eval "db.dropDatabase()"
  # copy settings-dev.json from the shared volume
  cp $shared_dir/settings-dev.json ${pwd}/settings-dev.json
  # checkout the correct branch
  git fetch && git checkout origin/$ghprbSourceBranch
  # perform npm install in case the branch added new dependencies
  npm install .
else
  $mongo/mongo.js --host $mongo_host --port $mongo_port $test_db --eval "db.dropDatabase()"
fi

function signalCaught {
  ./stop-test-server.sh
}

trap signalCaught EXIT
trap signalCaught INT
trap signalCaught SIGINT  # 2
trap signalCaught SIGQUIT # 3
trap signalCaught SIGKILL # 9
trap signalCaught SIGTERM # 15

MONGO_URL=mongodb://${mongo_host}:${mongo_port}/${test_db} meteor test --full-app --driver-package tmeasday:acceptance-test-driver -p ${app_port} --settings settings-dev.json > ${log_file} &
APP_PID=$!
echo $APP_PID > $pid_file
echo "Starting server with PID: ${APP_PID}"
tail -f $log_file
wait $APP_PID
