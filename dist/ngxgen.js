(function(){
  var fs, path, templateText, jsYaml, yargs, lib, cfgfile, argv, temp, code, cfg, e;
  fs = require('fs');
  path = require('path');
  templateText = require('template-text');
  jsYaml = require('js-yaml');
  yargs = require('yargs');
  lib = fs.realpathSync(path.dirname(__filename));
  cfgfile = 'config.json';
  argv = yargs.option('config', {
    alias: 'c',
    description: "config json",
    type: 'string'
  }).help('help').alias('help', 'h').check(function(argv, options){
    if (!argv.c) {
      throw new Error("config file required");
    }
    cfgfile = path.join(lib, argv.c);
    if (!fs.existsSync(cfgfile)) {
      throw new Error("config file not found: " + cfgfile);
    }
    return true;
  }).argv;
  temp = fs.readFileSync(path.join(lib, 'dist', 'config.ngx')).toString();
  code = fs.readFileSync(cfgfile).toString();
  try {
    cfg = JSON.parse(code);
  } catch (e$) {
    e = e$;
    cfg = jsYaml.load(code);
  }
  console.log(templateText(temp, cfg, lib));
}).call(this);
