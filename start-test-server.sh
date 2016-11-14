#!/bin/bash
#
# Starts meteor with a standalone MONGO_URL pointing to the test database.
#
# example:
#
# ./start-test-server.sh --app_port=3001 --mongo_host=127.0.0.1 --mongo_port=27017 --test_db=eidr-connect-test

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
    *)
    ;;
esac
shift
done

# use args or default
test_db=${test_db:=eidr-connect-tests}
mongo_host=${mongo_host:=127.0.0.1}
mongo_port=${mongo_port:=27017}
app_port=${app_port:=3001}

if [ -f ".test-server.pid" ]; then
  echo "Error: the test-server is already running."
  exit 1
fi

MONGO_URL=mongodb://${mongo_host}:${mongo_port}/${test_db} meteor -p ${app_port} --settings settings-dev.json &
echo $! > .test-server.pid
