require! <[pthk lderror]>
fs = require "fs-extra"
version-type = require(\./provider).version-type

# a path is only safe to hand to nginx if it cannot climb out of the cache root once nginx
# unescapes it. nginx unescapes the `X-Accel-Redirect` value but does not collapse dot
# segments, so `..%2f` ( or a double-encoded `%252e%252e%252f` ) left in the uri would make
# the internal redirect read files outside the root. decode until stable, then refuse any
# `..` segment or nul byte.
safe-path = (p) ->
  [prev, cur] = ['', "#{p or ''}"]
  for til 4
    if cur == prev => break
    prev = cur
    try cur = decodeURIComponent(cur) catch => return false
  if cur != prev => return false   # still encoded after 4 rounds: nothing legitimate is
  if /\0/.test(cur) => return false
  (cur.split /[\/\\]/).every (seg) -> seg != '..'

handle = ({provider, id, root, opt}) ->
  if !(id and ("#id".trim!)) => return lderror.reject 404
  [paths, obj, id] = [{}, {}, pthk.rectify(id)]
  # built from the parsed / validated `name`, `version` and `path` -- never from the raw
  # url, whose dot segments and encodings nginx would resolve on our behalf ( see safe-path ).
  accel = -> pthk.join(root.internal, obj.name, "#{obj.version}", obj.path)
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
      if !safe-path obj.path => return lderror.reject 404
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
    .then (r) -> if r and r.redirect => r else {accel: accel!}
    .catch (e) ->
      # 998 = skip fetching. as if fetch successfully.
      if lderror.id(e) == 998 => return {accel: accel!}
      if lderror.id(e) != 404 => return Promise.reject e
      lderror.reject 404

# check `root.fs` once when a route is created ( i.e., on server start ), so a missing or
# unwritable cache dir ( e.g. `/var/lib/cdn` not prepared, `/var/lib` is root-only ) is
# reported up front instead of as a 500 on the first fetch. only warns: a broken registry
# route should not keep the whole server from starting. returns whether `dir` is writable.
checked = {}
check-root = (dir) ->
  if !dir => return false
  if checked[dir]? => return checked[dir]
  checked[dir] = try
    fs.ensure-dir-sync dir
    fs.access-sync dir, fs.constants.W_OK
    true
  catch e
    user = try require(\os).user-info!.username catch => \<server-user>
    console.warn """
    [@plotdb/registry] fs root `#dir` is not writable ( #{e.code or e.message} ).
    fetching packages will fail with 500 until it is fixed, e.g.:
        sudo mkdir -p #dir && sudo chown #user #dir
    """
    false

# warn once per provider when a route's entry provider has no access-control gate: every
# package its chain can reach ( e.g. all of npm ) is then served from this origin, under
# our own domain. `open: true` on the provider says that is intended and silences this.
gated = {}
check-gate = (provider, where) ->
  if !provider or typeof(provider.has-gate) != \function => return true
  if provider.has-gate! => return true
  if gated[name = provider._name] => return false
  gated[name] = true
  console.warn """
  [@plotdb/registry] provider `#name` used by #where has no `scopes` / `check`:
  every package reachable through its chain is served from this origin. restrict it, e.g.:
      myprovider = new registry.provider {scopes: ['@plotdb'], chain: [...]}
  pass `open: true` to the provider if serving anything is intended.
  """
  false

route = ({provider, root, opt}) ->
  if !root.pub.endsWith \/ => root.pub = "#{root.pub}/"
  check-root root.fs
  check-gate provider, \registry.route
  (req, res) ->
    url = req.originalUrl
    id = url.replace(root.pub, '').replace(/[#?].*$/,'')
    _o = if !opt => {}
    else if typeof(opt) == \function => opt(req, res)
    else opt
    handle {provider, id, root, opt: _o}
      .then (r) ->
        if r and r.redirect => return res.redirect 302, r.redirect
        res.set { "X-Accel-Redirect": r.accel }
        res.send!
      .catch (e) ->
        # 400: invalid range / version syntax. 404: not found / incorrect url.
        code = lderror.id e
        if code in [400 404] => return res.status code .send!
        console.log e
        res.status 500 .send!

route.check-root = check-root
route.check-gate = check-gate
module.exports = route
