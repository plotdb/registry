(function(){
  var registry;
  registry = {
    jsdelivr: {
      url: function(arg$){
        var name, version, path;
        name = arg$.name, version = arg$.version, path = arg$.path;
        return "https://cdn.jsdelivr.net/npm/" + name + (version && "@" + version || '') + (path && "/" + path || '');
      },
      fetch: function(o){
        return fetch(this.url(o)).then(function(r){
          var v;
          v = r.headers.get('x-jsd-version');
          return r.text().then(function(it){
            return {
              version: v || version,
              content: it
            };
          });
        });
      }
    },
    unpkg: {
      url: function(arg$){
        var name, version, path;
        name = arg$.name, version = arg$.version, path = arg$.path;
        return "https://unpkg.com/" + name + (version && "@" + version || '') + (path && "/" + path || '');
      },
      fetch: function(arg$){
        var name, version, path;
        name = arg$.name, version = arg$.version, path = arg$.path;
        return fetch(this.url(o)).then(function(r){
          var v;
          v = (/^https:\/\/unpkg.com\/([^@]+)@([^/]+)\//.exec(r.url) || [])[2];
          return r.text().then(function(it){
            return {
              version: v || version,
              content: it
            };
          });
        });
      }
    }
  };
  if (typeof module != 'undefined' && module !== null) {
    module.exports = registry;
  } else if (typeof window != 'undefined' && window !== null) {
    window.registry = registry;
  }
}).call(this);
