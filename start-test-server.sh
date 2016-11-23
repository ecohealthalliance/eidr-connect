#!/bin/bash
#
# Starts meteor with a standalone MONGO_URL pointing to the test database.
#
# example:
#
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
mongo_host=${mongo_host:=127.0.0.1}
mongo_port=${mongo_port:=27017}
app_port=${app_port:=3001}
is_docker=${is_docker:=false}
shared_dir=${SHARED_DIR:=/shared}
mongo=node_modules/mongodb-prebuilt/binjs
pwd=$(pwd)

if [ -f "/tmp/eidr-test-server.pid" ]; then
  echo "Error: the test-server is already running."
  exit 1
fi

echo "Dropping testing '${test_db}' if it exists..."
if [ $is_docker = "true" ]; then
  mongo --host $mongo_host --port $mongo_port $test_db --eval "db.dropDatabase()"
  # copy settings-dev.json from the shared volume
  cp $shared_dir/settings-dev.json ${pwd}/settings-dev.json
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

mkdir -p ${pwd}/tests/log
touch ${pwd}/tests/log/eidr-test-server.log
MONGO_URL=mongodb://${mongo_host}:${mongo_port}/${test_db} meteor -p ${app_port} --settings settings-dev.json > ${pwd}/tests/log/eidr-test-server.log &
APP_PID=$!
echo $APP_PID > /tmp/eidr-test-server.pid
echo "Starting server with PID: ${APP_PID}"
wait $APP_PID
