FROM ubuntu:14.04

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

#Add in the repo
ADD . /eidr-connect
WORKDIR /eidr-connect

#Create and use meteor user
RUN groupadd meteor && adduser --ingroup meteor --home /home/meteor meteor
RUN chown -R meteor:meteor /eidr-connect
USER meteor

# Install Meteor
RUN curl https://install.meteor.com/ | sh
ENV PATH=$PATH:$HOME/.meteor

RUN meteor npm install
RUN meteor build /build --directory
WORKDIR /build/bundle/programs/server
RUN npm install
WORKDIR /
ADD eidr-connect.sh .

#Switch back to root user
USER root

# Add the application files
ADD supervisor-eidr-connect.conf /etc/supervisor/conf.d/eidr-connect.conf
ADD run.sh /run.sh

# Prepare for production
LABEL app="eidr-connect"
EXPOSE 3000
VOLUME /shared

# Start application
CMD /bin/bash /run.sh
