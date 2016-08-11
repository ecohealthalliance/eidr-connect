#!/bin/bash

# Instructions:
#   run meteor app instance on port 13000
#   execute this script


chimp=node_modules/chimp/bin/chimp.js
watch=""
quit=0


if [ "$WATCH" == "true" ]; then
  watch="--watch";
  SECONDS=0
fi

# Clean-up
function finish {
  echo "Cleaning-up..."
  mongo localhost:13001/meteor .scripts/drop-database.js
  echo "Restoring the original 'meteor' db from a dump file..."
  mongorestore -h 127.0.0.1 --port 13001 -d meteor tests/dump/meteor --quiet
  echo "done."
  rm -rf tests/dump/ # cle
}
trap finish EXIT
trap finish INT
trap finish SIGINT  # 2
trap finish SIGQUIT # 3
trap finish SIGKILL # 9
trap finish SIGTERM # 15
# Note: must be bound before starting the actual test


# Back up the current database
rm -rf tests/dump/
echo "Creating a bson dump of our 'meteor' db..."
mongodump -h 127.0.0.1 --port 13001 -d meteor -o tests/dump/ --quiet
echo "done."


# Run the tests
$chimp $watch --ddp=http://localhost:13000 \
        --path=tests/ \
        --coffee=true \
        --compiler=coffee:coffee-script/register \

# Output time elapsed
if [ "$WATCH" != "true" ]; then
  echo ''
  echo "$(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds elapsed"
  echo ''
fi
