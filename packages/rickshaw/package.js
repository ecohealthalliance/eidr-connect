Package.describe({
  // The .min prevents the meteor standard minifier from minifying the package.
  // The Rickshaw class library breaks if the $super variable is mangled.
  name: "eidr:rickshaw.min",
  version: "0.0.1",
  summary: "A rickshaw wrapper package that prevents it from being minified by meteor."
});

// Newer versions of d3 cause an error due to indexing of d3 selections not working.
Npm.depends({
  d3: '3.5.16'
});

Package.onUse(function(api) {
  api.use('modules');
  api.mainModule('rickshaw.min.js', 'client');
  api.addFiles('rickshaw.min.css', 'client');
});