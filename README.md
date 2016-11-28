# eidr-connect

Global Repository of Infectious Disease Data


## Building the docker image, and running the container

Build the docker image  
`sudo docker build -t eidr-connect .`

Run the newly built image using docker-compose  
`sudo docker-compose -f eidr-compose.yml up -d`

## Testing with docker

### Step 1: build the image

```
docker build -t eidr-connect-test -f test.Dockerfile .
```

### Step 2: run docker-compose (Step 1 only needs done once) 

Note: docker-compose will bring up two containers `eidrconnect_app_1` and `eidrconnect_mongodb_1` that have an isoloated IP network.  They can communicate via hostname `app` and `mongodb`, which will be converted into IP addresses via /etc/hosts.
The default CMD for `app` is to start the test server using `start-test-server.sh`.  See the eird-connect-test.yml for the specifics.

```
docker-compose -f eidr-connect-test.yml up -d 
docker exec -it --user meteor eidrconnect_app_1 ./run-tests.sh --mongo_host=mongodb --is_docker=true
docker-compose -f eidr-connect-test.yml down
```

## Testing on OSX

Install testing dependencies
```
npm install
```

Run the meteor test application
```
npm run-script start-test-server
```

- Or you may customize the script by running directly with the following optional args:
```
./start-test-server.sh --app_port=3001 --mongo_host=127.0.0.1 --mongo_port=27017 --test_db=eidr-connect-test --prod_db=eidr-connect
```

Execute the test runner to run all tests
```
npm run chimp-test
```

- Or include the watch flag to continuously execute watched tests after file changes
```
npm run chimp-watch
```

- Or you may customize the script by running directly with the following optional args:
```
./run-tests.sh --watch=true --app_uri=http://127.0.0.1 --app_port=3001
```

Stop the meteor test application
```
npm run-script stop-test-server
```

## License

Copyright 2016 EcoHealth Alliance

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
