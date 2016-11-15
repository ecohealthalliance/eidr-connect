# eidr-connect

Global Repository of Infectious Disease Data


## Building the docker image, and running the container

Build the docker image  
`sudo docker build -t eidr-connect .`

Run the newly built image using docker-compose  
`sudo docker-compose -f eidr-compose.yml up -d`

## Testing with docker

```
docker build -t eidr-connect-test -f test.Dockerfile .
```

## Testing on OSX

Install testing dependencies
`npm install`

Run the meteor application on port 13000
`npm run start-test`

Execute the test runner to run all tests
`npm run chimp-test`

Or include the watch flag to continuously execute watched tests after file changes
`npm run chimp-watch`

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
