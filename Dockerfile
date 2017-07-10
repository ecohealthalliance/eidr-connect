FROM ubuntu:14.04

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install apt package dependencies
RUN apt-get clean all && apt-get update && \
    apt-get -y install wget curl python make g++ git supervisor unzip && \
    apt-get clean all

# Add spcies data from ITIS
RUN wget https://www.itis.gov/downloads/itisSqlite.zip

# Install nodejs
RUN wget https://nodejs.org/download/release/v4.4.7/node-v4.4.7-linux-x64.tar.gz && \
    tar -zxf node-v4.4.7-linux-x64.tar.gz && \
    rm node-v4.4.7-linux-x64.tar.gz
ENV PATH $PATH:/node-v4.4.7-linux-x64/bin

#Add in the repo
ADD . /eidr-connect
ADD eidr-connect.sh .
WORKDIR /eidr-connect

# Install Meteor
RUN curl https://install.meteor.com/ | sh

#Create and use meteor user
RUN groupadd meteor && adduser --ingroup meteor --home /home/meteor meteor
RUN chown -R meteor:meteor /eidr-connect
USER meteor

RUN meteor npm install
RUN meteor build /home/meteor/build --directory
WORKDIR /home/meteor/build/bundle/programs/server
RUN npm install
WORKDIR /

#Switch back to root user
USER root

# Add the application files
ADD supervisor-eidr-connect.conf /etc/supervisor/conf.d/eidr-connect.conf
ADD run.sh /run.sh
RUN cd /eidr-connect && git rev-parse HEAD > /home/meteor/build/bundle/revision.txt

# Prepare for production
LABEL app="eidr-connect"
EXPOSE 3000
VOLUME /shared

# Start application
CMD /bin/bash /run.sh
