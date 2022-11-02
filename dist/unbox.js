(function(){
  var yauzl, tar, pthk, stream, fs, unzip, untar;
  yauzl = require('yauzl');
  tar = require('tar');
  pthk = require('pthk');
  stream = require('stream');
  fs = require("fs-extra");
  unzip = function(arg$){
    var path, buf;
    path = arg$.path, buf = arg$.buf;
    return new Promise(function(res, rej){
      return yauzl.fromBuffer(buf, {
        autoClose: false,
        lazyEntries: true
      }, function(e, zipfile){
        if (e) {
          return rej(e);
        }
        zipfile.readEntry();
        zipfile.on('end', function(){
          zipfile.close();
          return res();
        });
        return zipfile.on('entry', function(entry){
          if (/\/$/.test(entry.fileName)) {
            return zipfile.readEntry();
          }
          return zipfile.openReadStream(entry, function(e, rs){
            var dirs, fn, desfile, desdir;
            if (e) {
              return rej(e);
            }
            rs.on('end', function(){
              return zipfile.readEntry();
            });
            dirs = entry.fileName.split('/');
            if (!(fn = dirs.slice(1).join('/'))) {
              fn = entry.fileName;
            }
            desfile = pthk.join(path.base.version, pthk.rectify(fn));
            desdir = pthk.dirname(desfile);
            return fs.ensureDir(desdir).then(function(){
              return rs.pipe(fs.createWriteStream(desfile));
            });
          });
        });
      });
    });
  };
  untar = function(arg$){
    var path, buf;
    path = arg$.path, buf = arg$.buf;
    return stream.Readable.from(buf).pipe(tar.x({
      strip: 1,
      cwd: path.base.version
    }));
  };
  module.exports = {
    unzip: unzip,
    untar: untar
  };
}).call(this);
