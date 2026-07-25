require! <[pthk lderror]>
fs = require "fs-extra"
version-type = require(\./provider).version-type

handle = ({provider, id, root, opt}) ->
  if !(id and ("#id".trim!)) => return lderror.reject 404
  [paths, obj, id] = [{}, {}, pthk.rectify(id)]
  Promise.resolve!
    .then ->
      # `~^%` for range versions in url ( `^` comes encoded as `%5E` )
      if !/^[-_a-zA-Z0-9@./~^%]+$/.exec(id) => return lderror.reject 404
      ids = id.split(\/)
      obj <<< if (ids.0 or '').0 == \@ =>
        name: "#{ids.0}/#{ids.1}"
        version: ids.2
        path: ids.slice(3).join(\/)
      else
        name: ids.0
        version: ids.1
        path: ids.slice(2).join(\/)
      if !(obj.name and obj.version and obj.path) => return lderror.reject 404
      try obj.version = decodeURIComponent(obj.version) catch => return lderror.reject 404
      if (vt = version-type(obj.version)) in <[range latest]> =>
        # range / latest are resolved to a specific version and redirected ( instead of served
        # directly ) so content urls stay immutable and their dirs are never materialized on disk.
        p = if vt == \range =>
          provider.resolve {
            root: root.fs
            name: obj.name
            version: obj.version
            force: false
            cachetime: 60 * 60
          } <<< opt
        else
          provider.resolve-latest {
            root: root.fs
            name: obj.name
            force: false
            cachetime: 60 * 60
          } <<< opt
        return p.then (v) -> {redirect: pthk.join(root.pub, obj.name, v, obj.path)}
      provider.fetch {
        root: root.fs
        name: obj.name
        version: obj.version
        force: false
        cachetime: 60 * 60
      } <<< opt
    .catch (e) ->
      if lderror.id(e) == 998 => return # skip fetching. as if fetch successfully.
      if lderror.id(e) != 404 => return Promise.reject e
      lderror.reject 404

route = ({provider, root, opt}) ->
  if !root.pub.endsWith \/ => root.pub = "#{root.pub}/"
  (req, res) ->
    url = req.originalUrl
    id = url.replace(root.pub, '').replace(/[#?].*$/,'')
    _o = if !opt => {}
    else if typeof(opt) == \function => opt(req, res)
    else opt
    handle {provider, id, root, opt: _o}
      .then (r) ->
        if r and r.redirect => return res.redirect 302, r.redirect
        res.set { "X-Accel-Redirect": pthk.join(root.internal, id) }
        res.send!
      .catch (e) ->
        # 400: invalid range / version syntax. 404: not found / incorrect url.
        code = lderror.id e
        if code in [400 404] => return res.status code .send!
        console.log e
        res.status 500 .send!

module.exports = route
