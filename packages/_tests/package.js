Package.describe({
  name: "eidr:fixtures",
  version: "0.0.1",
  debugOnly: true,
  summary: "Tools to aid in acceptance and integration testing."
});

Package.onUse(function(api) {
  api.versionsFrom("1.1.0.2");
  api.use("coffeescript");
  api.use("xolvio:cleaner");
  api.addFiles("fixtures.coffee");
});
