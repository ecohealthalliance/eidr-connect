FROM ubuntu:14.04.4

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install apt package dependencies
RUN apt-get clean all && apt-get update && \
    apt-get -y install wget curl python make g++ git supervisor && \
    apt-get clean all

# Install nodejs
RUN wget https://nodejs.org/download/release/v4.4.7/node-v4.4.7-linux-x64.tar.gz && \
    tar -zxf node-v4.4.7-linux-x64.tar.gz && \
    rm node-v4.4.7-linux-x64.tar.gz
ENV PATH $PATH:/node-v4.4.7-linux-x64/bin

# Install Meteor
RUN curl https://install.meteor.com/ | sh

ADD . /eidr-connect
WORKDIR /eidr-connect
RUN meteor build /build --directory
WORKDIR /build/bundle/programs/server
RUN npm install
WORKDIR /
ADD eidr-connect.sh .

# Add the application files
ADD supervisor-eidr-connect.conf /etc/supervisor/conf.d/eidr-connect.conf
ADD run.sh /run.sh

# Prepare for production
LABEL app="eidr-connect"
EXPOSE 3000
VOLUME /shared

# Start application
CMD /bin/bash /run.sh
