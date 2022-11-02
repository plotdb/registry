(function(){
  var nodeFetch, lderror, yauzl, pthk, tar, fs, fetch, getVersionType, provider, ref$;
  nodeFetch = require('node-fetch');
  lderror = require('lderror');
  yauzl = require('yauzl');
  pthk = require('pthk');
  tar = require('tar');
  fs = require("fs-extra");
  fetch = nodeFetch;
  getVersionType = function(v){
    if (v === 'latest' || v === 'main') {
      return 'latest';
    } else if (/^\d+\.\d+\.\d+$/.test(v)) {
      return 'specific';
    } else {
      return null;
    }
  };
  provider = function(o){
    o == null && (o = {});
    this._name = o.name || "unnamed" + (provider._idx++);
    this._ps = [].concat(o.chain || []);
    this._fetchRealVersion = o.fetchRealVersion;
    this._fetchBundleFile = o.fetchBundleFile;
    this._check = o.check;
    this._opt = o.opt || {};
    return this;
  };
  provider._hash = {};
  provider._idx = 0;
  provider.add = function(p){
    return this._hash[p._name] = p;
  };
  provider.get = function(n){
    return this._hash[n];
  };
  provider.prototype = (ref$ = Object.create(Object.prototype), ref$.opt = function(o){
    return this._opt = o || {};
  }, ref$.fetch = function(o){
    var this$ = this;
    o == null && (o = {});
    return Promise.resolve().then(function(){
      var path, root, name, version, force, cachetime, versionType, params, _;
      path = {
        base: {}
      };
      root = o.root, name = o.name, version = o.version, force = o.force, cachetime = o.cachetime;
      cachetime = cachetime || 60 * 60;
      versionType = getVersionType(version);
      if (!versionType) {
        return lderror.reject(400);
      }
      params = {
        path: path,
        versionType: versionType,
        root: root,
        name: name,
        version: version,
        force: force,
        cachetime: cachetime
      };
      if (!/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name)) {
        return lderror.reject(400);
      }
      path.base.pkg = pthk.join(root, pthk.rectify(name));
      path.base.version = pthk.join(path.base.pkg, version);
      path.version = pthk.join(path.base.version, '.reg.version');
      path[404] = pthk.join(path.base.version, '.reg.404');
      _ = function(idx){
        var pr, p;
        idx == null && (idx = -1);
        if (idx >= 0) {
          if (!(pr = this$._ps[idx])) {
            return lderror.reject(404);
          }
          p = pr.check({
            name: name,
            version: version
          }).then(function(){
            return pr._fetch(params);
          });
        } else {
          p = this$.check({
            name: name,
            version: version
          }).then(function(){
            if (!this$._fetchRealVersion) {
              return lderror.reject(404);
            } else {
              return this$._fetch(params);
            }
          });
        }
        return p['catch'](function(e){
          var id;
          return (id = lderror.id(e)) !== 404
            ? Promise.reject(e)
            : _(idx + 1);
        });
      };
      return _()['catch'](function(e){
        var id;
        if (!((id = lderror.id(e)) === 403 || id === 404)) {
          return Promise.reject(e);
        }
        return fs.ensureDir(path.base.version).then(function(){
          return fs.writeFile(path[404], '');
        }).then(function(){
          return lderror.reject(404);
        });
      });
    });
  }, ref$.check = function(arg$){
    var name, version;
    name = arg$.name, version = arg$.version;
    if (this._check) {
      return this._check({
        name: name,
        version: version
      });
    } else {
      return Promise.resolve();
    }
  }, ref$.chain = function(ps){
    return this._ps.splice.apply(this._ps, [0, 0].concat(Array.isArray(ps)
      ? ps
      : [ps]));
  }, ref$._fetch = function(params){
    var root, name, version, cachetime, force, path, versionType, this$ = this;
    root = params.root, name = params.name, version = params.version, cachetime = params.cachetime, force = params.force, path = params.path, versionType = params.versionType;
    return Promise.resolve().then(function(){
      if (force) {
        return;
      }
      return fs.exists(path.version).then(function(isExisted){
        if (!isExisted) {
          return fs.exists(path[404]).then(function(is404){
            if (!is404) {
              return true;
            }
            return fs.stat(path[404]).then(function(s){
              var dirty;
              dirty = Date.now() > s.mtime.getTime() + cachetime * 1000;
              return !dirty
                ? false
                : fs.remove(path[404]).then(function(){
                  return true;
                });
            });
          });
        }
        if (versionType === 'specific') {
          return false;
        }
        if (versionType === 'latest') {
          return fs.stat(path.version).then(function(s){
            return Date.now() > s.mtime.getTime() + cachetime * 1000;
          });
        }
        return false;
      }).then(function(isDirty){
        if (!isDirty) {
          return lderror.reject(998);
        }
      });
    }).then(function(){
      return this$._fetchRealVersion(params).then(function(remoteInfo){
        return Promise.resolve().then(function(){
          if (force || versionType === 'specific') {
            return remoteInfo;
          }
          return fs.exists(path.version).then(function(isExisted){
            if (!isExisted) {
              return;
            }
            return fs.readFile(path.version).then(function(r){
              var now;
              if (remoteInfo.version > JSON.parse(r).version) {
                return;
              }
              now = new Date();
              fs.utimes(path.version, now, now);
              return lderror.reject(998);
            });
          });
        }).then(function(){
          return fs.remove(path.base.version);
        }).then(function(){
          return fs.ensureDir(path.base.version);
        }).then(function(){
          return fs.writeFile(path.version, JSON.stringify(remoteInfo));
        }).then(function(){
          return remoteInfo;
        });
      });
    }).then(function(remoteInfo){
      return this$._fetchBundleFile(import$({
        remoteInfo: remoteInfo
      }, params));
    });
  }, ref$);
  if (typeof module != 'undefined' && module !== null) {
    module.exports = provider;
  } else if (typeof window != 'undefined' && window !== null) {
    window.registry = provider;
  }
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
