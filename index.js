(function(){
  var route, provider, providers;
  route = require('./route');
  provider = require('./provider');
  providers = require('./providers');
  module.exports = {
    route: route,
    provider: provider,
    providers: providers
  };
}).call(this);
