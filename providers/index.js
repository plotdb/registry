(function(){
  var github, npm;
  github = require('./github');
  npm = require('./npm');
  module.exports = {
    github: github,
    npm: npm
  };
}).call(this);
