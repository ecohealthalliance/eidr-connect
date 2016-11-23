FROM dannyanko/meteor-headless-testing:latest

# Create the working directory
RUN mkdir /home/meteor/eidr-connect
WORKDIR /home/meteor/eidr-connect

# Add package.json to cache npm install
COPY package.json package.json

USER meteor

# Install npm dependencies
RUN meteor npm install

# native bcrypt for faster encryption
RUN npm install --save bcrypt

USER root
# Copy project files
COPY . .

# Admin chores
RUN cp /usr/bin/meteor /usr/local/bin/meteor
RUN touch /var/log/eidr-test-server.log && chown meteor:meteor /var/log/eidr-test-server.log
RUN chown -R meteor:meteor /home/meteor/

USER meteor

CMD /bin/bash
