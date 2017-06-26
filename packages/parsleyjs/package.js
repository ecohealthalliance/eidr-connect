Package.describe({
  name: 'eidr:parsley',
  version: '0.0.1',
  summary: "Parsley whcih uses meteor's version of jquery"
});

Package.onUse(function(api) {
  api.addFiles('parsley.min.js', 'client');
});
