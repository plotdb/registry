(function(){
  var fs, fsExtra, path, block, lderror, handle, route;
  fs = require('fs');
  fsExtra = require('fs-extra');
  path = require('path');
  block = require('@plotdb/block');
  lderror = require('lderror');
  handle = function(arg$){
    var provider, id, root, paths, obj;
    provider = arg$.provider, id = arg$.id, root = arg$.root;
    paths = {};
    obj = {};
    id = path.resolve(path.join('/', id)).substring(1);
    return Promise.resolve().then(function(){
      var ids, ref$;
      paths[404] = path.join(root, id) + ".404";
      paths.full = path.join(root, id);
      paths.dir = path.dirname(paths.full);
      if (!(paths.full && paths.dir)) {
        return lderror(400);
      }
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
      if (/:/.exec(obj.name)) {
        ref$ = obj.name.split(':'), obj.ns = ref$[0], obj.name = ref$[1];
      }
      if (!(obj.name && obj.version && obj.path)) {
        return lderror.reject(404);
      }
      paths.base = (obj.ns ? obj.ns + ':' : '') + "" + obj.name;
      paths.main = path.join(root, paths.base, 'main');
      paths.version = path.join(root, paths.base, obj.version, '.version');
      if ((ref$ = obj.version) === 'main' || ref$ === 'latest') {
        if (!fs.existsSync(paths.version)) {
          return lderror.reject(998);
        }
        obj.version = fs.readFileSync(paths.version).toString();
      }
      return provider.fetch(obj).then(function(arg$){
        var version, content, v, versions, isExisted, des;
        version = arg$.version, content = arg$.content;
        version = path.resolve(path.join('/', version)).substring(1);
        fsExtra.ensureDirSync(paths.dir);
        if (fs.existsSync(paths.version)) {
          v = fs.readFileSync(paths.version).toString();
          if (v !== version) {
            fsExtra.removeSync(paths.dir);
            fsExtra.ensureDirSync(paths.dir);
          }
        }
        fs.writeFileSync(paths.full, content);
        fs.writeFileSync(paths.version, version);
        versions = fs.existsSync(paths.base)
          ? fs.readdirSync(paths.base)
          : [];
        versions.sort(function(a, b){
          if (a < b) {
            return 1;
          } else if (a > b) {
            return -1;
          } else {
            return 0;
          }
        });
        if (!versions[0] || version > versions[0] || !(isExisted = fs.existsSync(paths.main))) {
          if (isExisted) {
            fs.removeSync(paths.main);
          }
          des = path.join(root, paths.base, version);
          fsExtra.ensureSymlink(des, paths.main);
        }
        return content;
      });
    })['catch'](function(e){
      if (lderror.id(e) === 998) {
        return lderror.reject(404);
      }
      if (lderror.id(e) !== 404) {
        return Promise.reject(e);
      }
      fs.writeFileSync(paths[404], '404');
      return lderror.reject(404);
    });
  };
  route = function(arg$){
    var provider, root;
    provider = arg$.provider, root = arg$.root;
    if (!root.pub.endsWith('/')) {
      root.pub = root.pub + "/";
    }
    return function(req, res){
      var url, id;
      url = req.originalUrl;
      id = url.replace(root.pub, '');
      return handle({
        provider: provider,
        id: id,
        root: root.fs
      }).then(function(){
        res.set({
          "X-Accel-Redirect": path.join(root.internal, id)
        });
        return res.send();
      })['catch'](function(e){
        if (lderror.id(e) !== 404) {
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
