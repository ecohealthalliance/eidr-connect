FROM dannyanko/meteor-headless-testing:latest

# Create the working directory
RUN mkdir /home/meteor/eidr-connect
WORKDIR /home/meteor/eidr-connect

# Add project files
ADD . .

RUN chown -R meteor:meteor /home/meteor/

USER meteor

# Install npm dependencies
RUN meteor npm install

# native bcrypt for faster encryption
RUN npm install --save bcrypt

ENTRYPOINT /home/meteor/eidr-connect/run-tests.sh

CMD /bin/bash

