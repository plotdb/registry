(function(){
  var pthk, lderror, fs, handle, route;
  pthk = require('pthk');
  lderror = require('lderror');
  fs = require("fs-extra");
  handle = function(arg$){
    var provider, id, root, opt, ref$, paths, obj;
    provider = arg$.provider, id = arg$.id, root = arg$.root, opt = arg$.opt;
    ref$ = [{}, {}, pthk.rectify(id)], paths = ref$[0], obj = ref$[1], id = ref$[2];
    return Promise.resolve().then(function(){
      var ids;
      if (!/^[-_a-zA-Z0-9@./]+$/.exec(id)) {
        return lderror.reject(404);
      }
      ids = id.split('/');
      import$(obj, ids.length > 3
        ? {
          name: ids[0] + "/" + ids[1],
          version: ids[2],
          path: ids.slice(3).join('/')
        }
        : {
          name: ids[0],
          version: ids[1],
          path: ids.slice(2).join('/')
        });
      if (!(obj.name && obj.version && obj.path)) {
        return lderror.reject(404);
      }
      return provider.fetch(import$({
        root: root.fs,
        name: obj.name,
        version: obj.version,
        force: false,
        cachetime: 60 * 60
      }, opt));
    })['catch'](function(e){
      if (lderror.id(e) === 998) {
        return;
      }
      if (lderror.id(e) !== 404) {
        return Promise.reject(e);
      }
      return lderror.reject(404);
    });
  };
  route = function(arg$){
    var provider, root, opt;
    provider = arg$.provider, root = arg$.root, opt = arg$.opt;
    if (!root.pub.endsWith('/')) {
      root.pub = root.pub + "/";
    }
    return function(req, res){
      var url, id, _o;
      url = req.originalUrl;
      id = url.replace(root.pub, '').replace(/[#?].*$/, '');
      _o = !opt
        ? {}
        : typeof opt === 'function' ? opt(req, res) : opt;
      return handle({
        provider: provider,
        id: id,
        root: root,
        opt: _o
      }).then(function(){
        res.set({
          "X-Accel-Redirect": pthk.join(root.internal, id)
        });
        return res.send();
      })['catch'](function(e){
        var ref$;
        if (!((ref$ = lderror.id(e)) === 400 || ref$ === 404)) {
          console.log(e);
          res.status(500).send();
        }
        return res.status(404).send();
      });
    };
  };
  module.exports = route;
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
