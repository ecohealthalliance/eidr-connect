FROM ubuntu:14.04
RUN add-apt-repository universe &&   add-apt-repository multiverse &&   apt-get update
RUN apt-get install -y curl libfontconfig build-essential xvfb x11vnc git-core python vim
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927 && \
  echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-3.2.list && \
  apt-get update && \
  apt-get install -y mongodb-org-tools=3.2.10 mongodb-org-shell=3.2.10
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
RUN add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer
# RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - &&   sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' &&   apt-get update &&   apt-get install -y google-chrome-stable libexif-dev
RUN groupadd meteor && adduser --ingroup meteor --disabled-password --gecos "" --home /home/meteor meteor

# Add spcies data from ITIS
RUN wget https://s3.amazonaws.com/bsve-integration/itisSqlite.zip

# Install nodejs
#RUN wget https://nodejs.org/download/release/v4.4.7/node-v4.4.7-linux-x64.tar.gz && \
#    tar -zxf node-v4.4.7-linux-x64.tar.gz && \
#    rm node-v4.4.7-linux-x64.tar.gz
#ENV PATH $PATH:/node-v4.4.7-linux-x64/bin

USER meteor

# Install Meteor
RUN curl https://install.meteor.com/ | sh

# Create the working directory
RUN mkdir /home/meteor/eidr-connect
WORKDIR /home/meteor/eidr-connect

# Add package.json to cache npm install
COPY package.json package.json

#USER meteor

# Install npm dependencies
RUN meteor npm install

# native bcrypt for faster encryption
RUN meteor npm install --save bcrypt

USER root
# Copy project files
COPY . .

# Admin chores
RUN ln -s /usr/bin/meteor /usr/local/bin/meteor  && \
  ln -s /home/meteor/eidr-connect/node_modules/phantomjs-prebuilt/lib/phantom/bin/phantomjs /usr/local/bin/phantomjs  && \
  chown -R meteor:meteor /home/meteor/

# Setup github
# RUN git config user.email "ecohealth-automation@users.noreply.github.com" && \
#   git config user.name "ecohealth-automation"  && \
#   git remote set-url origin https://github.com/ecohealthalliance/eidr-connect.git

USER meteor

CMD /bin/bash
