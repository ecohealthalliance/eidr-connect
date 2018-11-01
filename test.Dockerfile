FROM ubuntu:16.04

RUN apt-get update && \
  apt-get install -y \
    curl \
    libfontconfig \
    build-essential\
    xvfb \
    x11vnc \
    git-core \
    python \
    vim \
    software-properties-common \
    python-software-properties
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927 && \
  echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-3.2.list && \
  apt-get update && \
  apt-get install -y mongodb-org-tools=3.2.10 mongodb-org-shell=3.2.10
RUN apt-get install -y openjdk-8-jre
RUN groupadd meteor && adduser --ingroup meteor --disabled-password --gecos "" --home /home/meteor meteor

# Add spcies data from ITIS
# RUN wget https://s3.amazonaws.com/bsve-integration/itisSqlite.zip

# Install nodejs
#RUN wget https://nodejs.org/download/release/v4.4.7/node-v4.4.7-linux-x64.tar.gz && \
#    tar -zxf node-v4.4.7-linux-x64.tar.gz && \
#    rm node-v4.4.7-linux-x64.tar.gz
#ENV PATH $PATH:/node-v4.4.7-linux-x64/bin

# Install Meteor
RUN curl https://install.meteor.com/ | sh

# Create the working directory
RUN mkdir /home/meteor/eidr-connect
WORKDIR /home/meteor/eidr-connect

# Copy project files
COPY . .
RUN chown -R meteor:meteor /home/meteor/eidr-connect

USER meteor

# Install npm dependencies
RUN meteor list
RUN cd imports/incident-resolution && meteor npm link
RUN meteor npm link incident-resolution
RUN meteor npm install

# native bcrypt for faster encryption
RUN meteor npm install --save bcrypt

USER root

# Admin chores
RUN ln -s /home/meteor/eidr-connect/node_modules/phantomjs-prebuilt/lib/phantom/bin/phantomjs /usr/local/bin/phantomjs  && \
  chown -R meteor:meteor /home/meteor/

USER meteor

CMD /bin/bash
