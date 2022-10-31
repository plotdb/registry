require! <[fs path template-text js-yaml yargs]>

lib = fs.realpathSync path.dirname __filename
cfgfile = 'config.json'

argv = yargs
  .option \config, do
    alias: \c
    description: "config json"
    type: \string
  .help \help
  .alias \help, \h
  .check (argv, options) ->
    if !argv.c => throw new Error("config file required")
    cfgfile := path.join(argv.c)
    if !fs.exists-sync(cfgfile) => throw new Error("config file not found: #cfgfile")
    return true
  .argv

temp = fs.read-file-sync path.join(lib, '..', \dist, \config.ngx) .toString!
code = fs.read-file-sync cfgfile .toString!
try
  cfg = JSON.parse(code)
catch e
  cfg = js-yaml.load code

console.log template-text(temp, cfg, lib)
