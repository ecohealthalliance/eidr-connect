#!/bin/bash

# example:
#
# npm start-test
# ./run-tests.sh --watch=false --app_uri=http://127.0.0.1 --app_port=3001 --mongo_host=127.0.0.1 --mongo_port=27017 --prod_db=eidr-connect --test_db=eidr-connect-test

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
prod_db=${prod_db:=eidr-connect}
test_db=${test_db:=eidr-connect-test}
mongo_host=${mongo_host:=127.0.0.1}
mongo_port=${mongo_port:=27017}
app_uri=${app_uri:=http://localhost}
app_port=${app_port:=3001}
watch=${watch:=false}

chimp=node_modules/chimp/bin/chimp.js
mongo=node_modules/mongodb-prebuilt/binjs/
quit=0

# Clean-up
function finish {
  # Note: the ${test_db} is wiped-out by chimp
  echo "done."
}
trap finish EXIT
trap finish INT
trap finish SIGINT  # 2
trap finish SIGQUIT # 3
trap finish SIGKILL # 9
trap finish SIGTERM # 15
# Note: must be bound before starting the actual test


# Back up the current database
echo "Creating a bson dump of our '${prod_db}' db..."
$mongo/mongodump.js -h $mongo_host --port $mongo_port -d $prod_db -o tests/dump/ --quiet
echo "Load the '${prod_db}' into the test '${test_db}' db..."
$mongo/mongorestore.js -h $mongo_host --port $mongo_port -d $test_db tests/dump/$prod_db --quiet

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
