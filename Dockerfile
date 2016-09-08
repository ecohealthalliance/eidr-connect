FROM node:4
EXPOSE 80

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
COPY settings-dev.json settings.json
CMD METEOR_SETTINGS="$(cat settings.json)" node main.js
