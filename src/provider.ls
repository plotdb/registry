require! <[node-fetch lderror yauzl pthk tar]>
fs = require "fs-extra"

fetch = node-fetch
version-type = (v) ->
  if v in <[latest main]> => \latest
  else if /^\d+\.\d+\.\d+$/.test(v) => \specific
  #else if /^[^~>]\d+\d.\d+\.\d+$/.test(v) => \range
  else null

provider = (o = {}) ->
  @_name = o.name or "unnamed#{provider._idx++}"
  @_ps = [] ++ (o.chain or [])
  @_fetch = o.fetch
  @_fetch-real-version = o.fetch-real-version
  @_fetch-bundle-file = o.fetch-bundle-file
  @_url = o.url
  @_opt = o.opt or {}
  @

provider <<<
  _hash: {}
  _idx: 0
  add: (p) -> @_hash[p._name] = p
  get: (n) -> @_hash[n]

provider.prototype = Object.create(Object.prototype) <<<
  url: (o) -> @_url o
  opt: (o) -> @_opt = o or {}
  fetch: (o = {}) ->
    _ = (idx = -1) ~>
      if idx == -1 and !@_fetch => idx = 0
      if idx >= 0 =>
        if !(pr = @_ps[idx]) => return lderror.reject 404
        p = pr._fetch o
      else p = @_fetch o
      p
        .catch (e) ->
          id = lderror.id e
          if id != 404 => return Promise.reject e
          return _(idx + 1)
        .then -> return it
    _!
  chain: (ps) ->
    @_ps.splice.apply @_ps, ([0, 0] ++ ps)
    return 

  _fetch: ({root, name, version, force, cachetime, opt}) ->
    path = {base: {}}
    cachetime = cachetime or 60 * 60 # default 1hr
    vtype = version-type(version)
    params = {root, name, version, cachetime, force, opt, path, version-type: vtype}
    <~ Promise.resolve!then _
    if !vtype => return lderror.reject 400
    if !/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name) => return lderror.reject 400
    path.base.pkg = pthk.join(root, pthk.rectify name)
    path.base.version = pthk.join(path.base.pkg, version)
    path.version = pthk.join(path.base.version, '.reg.version')
    path.404 = pthk.join(path.base.version, '.reg.404')
    Promise.resolve!
      .then ->
        # 1. in this block, we test if a pkg is dirty/expired and should be fetched again.
        if force => return
        fs.exists path.version
          .then (is-existed) ->
            # return true if dirty
            if !is-existed =>
              return fs.exists path.404 .then (is404) ->
                # not existed and 404 not found - never fetched and thus dirty
                if !is404 => return true
                (s) <- fs.stat path.404 .then _
                # not existed, 404 - dirty if cache expires
                dirty = Date.now! > s.mtime.getTime! + cachetime * 1000
                return if !dirty => false else fs.remove path.404 .then -> true
            # specific version existed. never dirty
            if vtype == \specific => return false
            # latest - dirty if cache expires.
            if vtype == \latest =>
              return fs.stat path.version .then (s) ->
                Date.now! > s.mtime.getTime! + cachetime * 1000
            # TODO range version
            return false
          .then (is-dirty) -> if !is-dirty => return lderror.reject 998
      .then ~>
        # 2. in this block, we peek real version for latest / range(TODO) version
        (remote-info) <~ @_fetch-real-version params .then _
        Promise.resolve!
          .then ->
            if force or vtype == \specific => return remote-info
            # compare remote version with local version
            fs.exists path.version .then (is-existed) ->
              # no local version -> must fetch
              if !is-existed => return
              (r) <- fs.read-file path.version .then _
              # local is older -> must fetch
              if remote-info.version > JSON.parse(r).version => return
              # no new version. skip fetch. touch version file for reset cache counter
              now = new Date!
              fs.utimes path.version, now, now
              lderror.reject 998
          .then -> fs.remove path.404 # TODO should we remove the whole path.base.version?
          .then -> fs.ensure-dir path.base.version
          .then -> fs.write-file path.version, JSON.stringify(remote-info)
          .then -> remote-info
      .then (remote-info) ~> @_fetch-bundle-file({remote-info} <<< params)

if module? => module.exports = provider
else if window? => window.registry = provider
