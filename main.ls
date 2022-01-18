require! <[express path @plotdb/colors]>

server = do
  init: (opt={}) ->
    app = express!
    app.use \/, express.static \static
    app.get '/:type(npm|gh)/*', (req, res) ->
      res.set \content-type, \text/html
      paths = (req.originalUrl or '').split(\/).filter(->it)
      obj = {paths}
      if paths.0 == \npm =>
        obj.type = \npm
        if paths.1.0 == \@ =>
          obj.scope = paths.1
          [repo,version] = paths.2.split(\@)
          file = paths.slice(3)
        else
          [repo,version] = paths.1.split(\@)
          file = paths.slice(2)
        obj <<< {repo, version, file}
      else if paths.0 == \gh =>
        [repo,version] = paths.2.split(\@)
        obj <<< type: \gh, user: paths.1, repo: repo, version: version, file: paths.slice(3)
      # sanity check
      
      res.send obj
    console.log "[Server] Express Initialized in #{app.get \env} Mode".green
    server = app.listen opt.port, ->
      delta = if opt.start-time => "( takes #{Date.now! - opt.start-time}ms )" else ''
      console.log "[SERVER] listening on port #{server.address!port} #delta".cyan

server.init {port: 5000}

#/npm/package@version/...
#/npm/scope/package@version/...
#/gh/user/repo@version/...
