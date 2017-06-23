Package.describe({
  name: 'eha:coordinate-selector',
  version: '0.0.2',
  summary: 'Autoform leaflet input',
});

Package.onUse(function(api) {

  api.use(
    [
      'coffeescript',
      'templating',
      'stylus',
      'mquandalle:jade',
      'fuatsengul:leaflet'
    ], 'client'
  );

  api.addFiles('coordinateSelector.jade', 'client');
  api.addFiles('coordinateSelector.coffee', 'client');
  api.addFiles('coordinateSelector.styl', 'client');

});
