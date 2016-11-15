FROM ubuntu:16.04

RUN apt-get update && apt-get install -y software-properties-common curl bzip2 python build-essential libfontconfig && \
    add-apt-repository -y ppa:webupd8team/java && \
    apt-get update && \
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections && \
    apt-get install -y oracle-java8-installer && \
    apt-get clean all

# Install node
RUN wget https://nodejs.org/download/release/v6.9.1/node-v6.9.1-linux-x64.tar.gz && \
      tar -zxf node-v6.9.1-linux-x64.tar.gz && \
      rm node-v6.9.1-linux-x64.tar.gz
  ENV PATH $PATH:/node-v6.9.1-linux-x64/bin

# Install Meteor
RUN curl https://install.meteor.com | sh

# Create locale settings so meteor mongo works
RUN locale-gen en_US && localedef -i en_US -f UTF-8 en_US
ENV LC_ALL="en_US"

RUN mkdir eidr-connect

# Compile and build eidr-connect
WORKDIR eidr-connect
ADD .meteor .meteor
ADD packages packages
ADD package.json package.json
RUN meteor npm install
RUN meteor npm install --save bcrypt # native bcrypt for faster encryption
# These are added separately so the npm install step can be cached
ADD tests tests
ADD client client
ADD collections collections
ADD imports imports
ADD server server
ADD public public
ADD settings-dev.json settings-dev.json
ADD .config .config

#Create and use meteor user
RUN groupadd meteor && adduser --ingroup meteor --disabled-password --gecos "" --home /home/meteor meteor
RUN chown -R meteor:meteor /eidr-connect
USER meteor

RUN meteor add xolvio:cleaner xolvio:backdoor tmeasday:acceptance-test-driver

ADD run-tests-docker.sh run-tests-docker.sh
RUN ./run-tests-docker.sh
CMD sleep infinity
