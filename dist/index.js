(function(){
  var route, provider;
  route = require('./route');
  provider = require('./provider');
  module.exports = {
    route: route,
    provider: provider
  };
}).call(this);
