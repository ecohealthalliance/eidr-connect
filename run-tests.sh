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
    --watch=*)
    watch="${i#*=}"
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
prod_db=${prod_db:=eidr-connect}
test_db=${test_db:=eidr-connect-test}
mongo_host=${mongo_host:=mongodb}
mongo_port=${mongo_port:=27017}

if [ ! -f ".test-server.pid" ]; then
  echo "Starting the test server..."
  ./start-test-server.sh --app_host=$app_host --app_port=$app_port --mongo_host=$mongo_host --mongo_port=$mongo_port --prod_db=$prod_db --test_db==$test_db
  sleep 15
fi

if [ ! -f ".test-server.pid" ]; then
  echo "Error: is the test-server running?"
  exit 1
fi

function finish {
  ./stop-test-server.sh
}
trap finish EXIT
trap finish INT
trap finish SIGINT  # 2
trap finish SIGQUIT # 3
trap finish SIGKILL # 9
trap finish SIGTERM # 15

chimp=node_modules/chimp/bin/chimp.js

$chimp --watch=$watch --ddp=$app_protocol://$app_host:$app_port \
        --path=tests/ \
        --browser=$browser \
        --coffee=true \
        --compiler=coffee:coffee-script/register \

# Output time elapsed
if [ "$WATCH" != "true" ]; then
  echo ''
  echo "$(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds elapsed"
  echo ''
fi
