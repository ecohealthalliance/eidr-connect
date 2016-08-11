# eidr-connect

Global Repository of Infectious Disease Data


## Building the docker image, and running the container

Build the app with the shell script  
`./build.sh`

Build the docker image  
`sudo docker build -t eidr-connect .`

Run the newly built image using docker-compose  
`sudo docker-compose -f <compose yml file> up -d`  
Examples of compose files here:  
https://github.com/ecohealthalliance/infrastructure/tree/master/docker/containers


## Testing

Install Chimp by running
`meteor npm install`

Install mongoDB by following the appropriate installation instructions on the official site:
https://www.mongodb.com/download-center

Run the meteor application on port 13000
`meteor -p 13000`

Execute `run-tests.sh`

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
