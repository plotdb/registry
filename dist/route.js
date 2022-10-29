(function(){
  var fs, fsExtra, path, block, lderror, handle, route;
  fs = require('fs');
  fsExtra = require('fs-extra');
  path = require('path');
  block = require('@plotdb/block');
  lderror = require('lderror');
  handle = function(arg$){
    var provider, id, root;
    provider = arg$.provider, id = arg$.id, root = arg$.root;
    return Promise.resolve().then(function(){
      var ids, name, version, p, obj, p404, dir, verfile;
      if (!/^[a-zA-Z0-9@./]+$/.exec(id)) {
        return lderror.reject(404);
      }
      ids = id.split('/');
      if (ids.length > 3) {
        name = ids[0] + "/" + ids[1];
        version = ids[2];
        p = ids.slice(3).join('/');
      } else {
        name = ids[0];
        version = ids[1];
        p = ids.slice(2).join('/');
      }
      obj = {
        name: name,
        version: version,
        path: p
      };
      p404 = path.join(root, path.resolve(path.join('/', id)).substring(1)) + ".404";
      p = path.join(root, path.resolve(path.join('/', id)).substring(1));
      if (!p) {
        return lderror(400);
      }
      dir = path.dirname(p);
      verfile = path.join(dir, '.version');
      fsExtra.ensureDirSync(dir);
      return provider.fetch(obj).then(function(arg$){
        var version, content, v;
        version = arg$.version, content = arg$.content;
        if (fs.existsSync(verfile)) {
          v = fs.readFileSync(verfile);
          if (v !== version) {
            fsExtra.removeSync(dir);
            fsExtra.ensureDirSync(dir);
          }
        }
        fs.writeFileSync(p, content);
        fs.writeFileSync(verfile, version);
        return content;
      })['catch'](function(){
        fs.writeFileSync(p404, '404');
        return lderror.reject(404);
      });
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
}).call(this);
