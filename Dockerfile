FROM ubuntu:14.04

RUN apt-get clean all && apt-get -y update && \
    apt-get -y install curl wget python build-essential && \
    apt-get clean all

RUN wget https://nodejs.org/download/release/v4.4.7/node-v4.4.7-linux-x64.tar.gz && \
    tar -zxf node-v4.4.7-linux-x64.tar.gz && \
    rm node-v4.4.7-linux-x64.tar.gz
ENV PATH $PATH:/node-v4.4.7-linux-x64/bin

# install Meteor
RUN curl https://install.meteor.com | sh

# compile and build eidr-connect
ADD . eidr-connect
WORKDIR eidr-connect
RUN meteor npm install --save bcrypt # native bcrypt for faster encryption
RUN meteor build /build --directory
RUN rm -rf eidr-connect

# need to set up node_modules before starting main.js
WORKDIR /build/bundle
RUN cd programs/server && npm install

# modify settings-production.json if necessary
COPY settings-production.json settings.json
CMD METEOR_SETTINGS="$(cat settings.json)" node main.js
