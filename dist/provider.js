(function(){
  var nodeFetch, lderror, fetch, provider, ref$;
  nodeFetch = require('node-fetch');
  lderror = require('lderror');
  fetch = nodeFetch;
  provider = function(o){
    o == null && (o = {});
    this._name = o.name || "unnamed" + (provider._idx++);
    this._ps = [].concat(o.chain || []);
    this._fetch = o.fetch;
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
  }, ref$);
  provider.add(new provider({
    name: 'github',
    url: function(arg$){
      var name, version, path;
      name = arg$.name, version = arg$.version, path = arg$.path;
      return "https://raw.githubusercontent.com/" + name.replace(/^@/, '') + "/v" + version + "/" + path;
    },
    fetch: function(o){
      var opt, this$ = this;
      opt = {};
      return Promise.resolve().then(function(){
        var ret, scope, token, ref$, headers;
        ret = /^@([^/]+)\/(.+)$/.exec(o.name);
        scope = ret ? ret[1] : null;
        import$(opt, o).name = o.name.replace(/^@/, '');
        token = !this$._opt
          ? null
          : ((ref$ = this$._opt).scope || (ref$.scope = {}))[scope] || ((ref$ = this$._opt).repo || (ref$.repo = {}))[o.name] || this$._opt.token;
        headers = !token
          ? {}
          : {
            "Authorization": "token " + token
          };
        if (!token && o.ns !== 'github') {
          return lderror.reject(404);
        }
        return fetch(this$.url(opt), {
          method: 'GET',
          headers: headers
        });
      })['catch'](function(e){
        if (lderror.id(e) === 404) {
          return lderror.reject(404);
        }
        return Promise.reject(e);
      }).then(function(r){
        if (r.status === 404) {
          return lderror.reject(404);
        } else {
          return r.text();
        }
      }).then(function(it){
        return {
          version: o.version,
          content: it
        };
      });
    }
  }));
  provider.add(new provider({
    name: 'jsdelivr',
    url: function(arg$){
      var name, version, path;
      name = arg$.name, version = arg$.version, path = arg$.path;
      return "https://cdn.jsdelivr.net/npm/" + name + (version && "@" + version || '') + (path && "/" + path || '');
    },
    fetch: function(o){
      return fetch(this.url(o))['catch'](function(){
        return lderror.reject(404);
      }).then(function(r){
        var v;
        v = r.headers.get('x-jsd-version');
        if (!v) {
          return lderror.reject(404);
        }
        return r.text().then(function(it){
          return {
            version: v || version,
            content: it
          };
        });
      });
    }
  }));
  provider.add(new provider({
    name: 'unpkg',
    url: function(arg$){
      var name, version, path;
      name = arg$.name, version = arg$.version, path = arg$.path;
      return "https://unpkg.com/" + name + (version && "@" + version || '') + (path && "/" + path || '');
    },
    fetch: function(o){
      o == null && (o = {});
      return fetch(this.url(o))['catch'](function(){
        return lderror.reject(404);
      }).then(function(r){
        var v;
        v = (/^https:\/\/unpkg.com\/([^@]+)@([^/]+)\//.exec(r.url) || [])[2];
        return r.text().then(function(it){
          return {
            version: v || o.version,
            content: it
          };
        });
      });
    }
  }));
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
