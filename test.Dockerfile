FROM dannyanko/meteor-headless-testing:0.1

# Compile and build eidr-connect
RUN mkdir eidr-connect
WORKDIR eidr-connect

# Add files
COPY .meteor .meteor
COPY packages packages
COPY package.json package.json
RUN meteor npm install
RUN meteor npm install --save bcrypt # native bcrypt for faster encryption

# These are added separately so the npm install step can be cached
COPY tests tests
COPY client client
COPY collections collections
COPY imports imports
COPY server server
COPY public public
COPY settings-dev.json settings-dev.json

RUN meteor add xolvio:cleaner xolvio:backdoor tmeasday:acceptance-test-driver

#COPY run-tests-docker.sh run-tests-docker.sh
#RUN ./run-tests-docker.sh
#CMD sleep infinity

CMD /bin/bash
