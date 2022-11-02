require! <[fs express path @plotdb/colors lderror]>
require! <[../src/provider ../src/route ../src/providers/github ../src/providers/npm]>

lib = fs.realpathSync path.dirname __filename

if !fs.exists-sync path.join(lib, \secret.json) =>
  console.log "please add a `secret.json` file with a access token for github access, such as:"
  console.log ""
  console.log '    {"token": "your-access-token-goes-here"}'
  console.log ""
  process.exit!

token = JSON.parse(fs.read-file-sync path.join(lib, \secret.json) .toString!)
custom = new provider do
  check: ({name, version, path}) ->
    return if !(/^(ld|pth|@plotdb)/.exec(name)) => lderror.reject 403 else Promise.resolve!

github.opt token
custom.chain([github, npm])

server = do
  init: (opt={}) ->
    app = express!
    app.use \/, express.static \static
    app.get '/lib/*', route({
      provider: custom
      root:
        pub: \/lib/
        fs: \/var/lib/cdn/cache/lib
        internal: \/ilib/
    })
    console.log "[Server] Express Initialized in #{app.get \env} Mode".green
    server = app.listen opt.port, ->
      delta = if opt.start-time => "( takes #{Date.now! - opt.start-time}ms )" else ''
      console.log "[SERVER] listening on port #{server.address!port} #delta".cyan

server.init {port: 9900}

