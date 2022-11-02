(function(){
  var nodeFetch, lderror, provider, unbox, fs, pvd;
  nodeFetch = require('node-fetch');
  lderror = require('lderror');
  provider = require('../provider');
  unbox = require('../unbox');
  fs = require("fs-extra");
  pvd = new provider({
    name: 'github',
    fetchRealVersion: function(arg$){
      var root, path, name, cachetime, version, versionType, force, opt, headers, release, jsonurl;
      root = arg$.root, path = arg$.path, name = arg$.name, cachetime = arg$.cachetime, version = arg$.version, versionType = arg$.versionType, force = arg$.force, opt = arg$.opt;
      headers = (opt || {}).token
        ? {
          "Authorization": "token " + opt.token
        }
        : {};
      release = versionType === 'latest'
        ? "releases/latest"
        : "releases/tags/v" + version;
      jsonurl = "https://api.github.com/repos/" + name.replace('@', '') + "/" + release;
      return nodeFetch(jsonurl, {
        method: 'GET',
        headers: headers
      }).then(function(r){
        if (r.status !== 200) {
          return lderror.reject(404);
        } else {
          return r.json();
        }
      }).then(function(r){
        return {
          version: (r.tag_name || '').replace(/^v/, ''),
          url: r.tarball_url
        };
      });
    },
    fetchBundleFile: function(arg$){
      var root, path, name, cachetime, version, remoteInfo, versionType, force, opt, headers;
      root = arg$.root, path = arg$.path, name = arg$.name, cachetime = arg$.cachetime, version = arg$.version, remoteInfo = arg$.remoteInfo, versionType = arg$.versionType, force = arg$.force, opt = arg$.opt;
      headers = (opt || {}).token
        ? {
          "Authorization": "token " + opt.token
        }
        : {};
      return nodeFetch(remoteInfo.url, {
        method: 'GET',
        headers: headers
      }).then(function(r){
        return r.buffer();
      }).then(function(buf){
        return unbox.untar({
          path: path,
          buf: buf
        });
      });
    }
  });
  /*
  params =
    root: 'lib'
    name: 'some-repo'
    version: 'latest'
    cachetime: 1
    opt: {token: "some-token"}
  
  pvd.fetch-module params
    .catch (e) ->
      if !(lderror.id(e) in [404 998]) => return Promise.reject e
      else console.log "return code: ", lderror.id(e)
    .then -> console.log \done.
  */
}).call(this);
