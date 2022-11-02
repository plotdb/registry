(function(){
  var nodeFetch, lderror, yauzl, pthk, tar, fs, fetch, versionType, provider, ref$;
  nodeFetch = require('node-fetch');
  lderror = require('lderror');
  yauzl = require('yauzl');
  pthk = require('pthk');
  tar = require('tar');
  fs = require("fs-extra");
  fetch = nodeFetch;
  versionType = function(v){
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
    this._fetch = o.fetch;
    this._fetchRealVersion = o.fetchRealVersion;
    this._fetchBundleFile = o.fetchBundleFile;
    this._url = o.url;
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
  provider.prototype = (ref$ = Object.create(Object.prototype), ref$.url = function(o){
    return this._url(o);
  }, ref$.opt = function(o){
    return this._opt = o || {};
  }, ref$.fetch = function(o){
    var _, this$ = this;
    o == null && (o = {});
    _ = function(idx){
      var pr, p;
      idx == null && (idx = -1);
      if (idx === -1 && !this$._fetch) {
        idx = 0;
      }
      if (idx >= 0) {
        if (!(pr = this$._ps[idx])) {
          return lderror.reject(404);
        }
        p = pr._fetch(o);
      } else {
        p = this$._fetch(o);
      }
      return p['catch'](function(e){
        var id;
        id = lderror.id(e);
        if (id !== 404) {
          return Promise.reject(e);
        }
        return _(idx + 1);
      }).then(function(it){
        return it;
      });
    };
    return _();
  }, ref$.chain = function(ps){
    this._ps.splice.apply(this._ps, [0, 0].concat(ps));
  }, ref$._fetch = function(arg$){
    var root, name, version, force, cachetime, opt, path, vtype, params, this$ = this;
    root = arg$.root, name = arg$.name, version = arg$.version, force = arg$.force, cachetime = arg$.cachetime, opt = arg$.opt;
    path = {
      base: {}
    };
    cachetime = cachetime || 60 * 60;
    vtype = versionType(version);
    params = {
      root: root,
      name: name,
      version: version,
      cachetime: cachetime,
      force: force,
      opt: opt,
      path: path,
      versionType: vtype
    };
    return Promise.resolve().then(function(){
      if (!vtype) {
        return lderror.reject(400);
      }
      if (!/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name)) {
        return lderror.reject(400);
      }
      path.base.pkg = pthk.join(root, pthk.rectify(name));
      path.base.version = pthk.join(path.base.pkg, version);
      path.version = pthk.join(path.base.version, '.reg.version');
      path[404] = pthk.join(path.base.version, '.reg.404');
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
          if (vtype === 'specific') {
            return false;
          }
          if (vtype === 'latest') {
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
            if (force || vtype === 'specific') {
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
            return fs.remove(path[404]);
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
