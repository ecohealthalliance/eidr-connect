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
    --prod_db=*)
    prod_db="${i#*=}"
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

# use args or default
prod_db=${prod_db:=eidr-connect}
test_db=${test_db:=eidr-connect-test}
mongo_host=${mongo_host:=127.0.0.1}
mongo_port=${mongo_port:=27017}
app_port=${app_port:=3001}
mongo=node_modules/mongodb-prebuilt/binjs

if [ -f ".test-server.pid" ]; then
  echo "Error: the test-server is already running."
  exit 1
fi

# Use the current prod_db database for testing.
# TODO: we should load mock data for each test feature using fixtures
echo "Creating a bson dump of our production '${prod_db}' db for testing..."
$mongo/mongodump.js --host $mongo_host --port $mongo_port -d $prod_db -o tests/dump/ --quiet

echo "Dropping testing '${test_db}' if it exists..."
$mongo/mongo.js --host $mongo_host --port $mongo_port $test_db --eval "db.dropDatabase()"

MONGO_URL=mongodb://${mongo_host}:${mongo_port}/${test_db} meteor -p ${app_port} --settings settings-dev.json &
APP_PID=$!
echo "Server starting with PID: ${APP_PID}"
echo $APP_PID > .test-server.pid
