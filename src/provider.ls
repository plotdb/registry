require! <[node-fetch lderror yauzl pthk tar]>
require! <[@plotdb/semver]>
fs = require "fs-extra"

fetch = node-fetch
get-version-type = (v) ->
  if v in <[latest main]> => \latest
  else if /^\d+\.\d+\.\d+$/.test(v) => \specific
  else if /^[~^>]/.test(v) and semver.valid-range(v) => \range
  else null

provider = (o = {}) ->
  @_name = o.name or "unnamed#{provider._idx++}"
  @_ps = [] ++ (o.chain or [])
  @_fetch-real-version = o.fetch-real-version
  @_fetch-bundle-file = o.fetch-bundle-file
  @_fetch-version-list = o.fetch-version-list
  @_check = o.check
  @_opt = o.opt or {}
  @

provider <<<
  _hash: {}
  _idx: 0
  add: (p) -> @_hash[p._name] = p
  get: (n) -> @_hash[n]
  version-type: get-version-type

provider.prototype = Object.create(Object.prototype) <<<
  opt: (o) -> @_opt = o or {}
  fetch: (o = {}) ->
    <~ Promise.resolve!then _
    path = {base: {}}
    {root, name, version, force, cachetime} = o
    cachetime = cachetime or 60 * 60 # default 1hr
    version-type = get-version-type(version)
    if !version-type => return lderror.reject 400, "incorrect version-type when accessing #name@#version"
    # range should be resolved (see `resolve`) and redirected to a specific version before fetch,
    # so range directories are never materialized on disk (nginx would serve them stale forever).
    if version-type == \range => return lderror.reject 400, "range version should be resolved before fetch"
    # simply not allowed bad / long name / version, even to prepare files.
    if "#name".length > 128 or "#version".length > 40 => return lderror.reject 998
    params = {path, version-type, root, name, version, force, cachetime}
    if !/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name) => return lderror.reject 400
    path.base.pkg = pthk.join(root, pthk.rectify name)
    path.base.version = pthk.join(path.base.pkg, version)
    path.version = pthk.join(path.base.version, '.reg.version')
    path.404 = pthk.join(path.base.version, '.reg.404')
    _ = (idx = -1) ~>
      if idx >= 0 =>
        if !(pr = @_ps[idx]) => return lderror.reject 404
        p = pr.check({name, version}).then ~> pr._fetch params
      else
        p = @check({name, version})
          .then ~>
            if !@_fetch-real-version => lderror.reject 404
            else @_fetch params
      p.catch (e) -> return if (id = lderror.id e) != 404 => Promise.reject e else _(idx + 1)
    _!catch (e) ->
      # we used to use 403 for packages that are not allowed.
      # however, it still leads to reg.404 creation.
      # to explicitly skip creation of file, we add 998 (skip) to prevent file creation
      # so we won't be flooded by malicious access in our local cache dir.
      # we may want to analysis performance impact,
      # since 404 files may go through here for every acces.
      if !((id = lderror.id(e)) in [403 404 998]) => return Promise.reject e
      # 998 skipped: don't even try adding 404 file.
      if id in [998] => return lderror.reject 404
      fs.ensure-dir path.base.version
        .then -> fs.write-file path.404, ''
        .then -> return lderror.reject 404

  check: ({name, version}) -> if @_check => @_check {name, version} else Promise.resolve!
  chain: (ps) -> @_ps.splice.apply @_ps, ([0, 0] ++ (if Array.isArray(ps) => ps else [ps]))

  # resolve a range version (e.g. `^1.2.3`) to the latest specific version satisfying it,
  # walking the provider chain like `fetch` does. version lists are cached per provider
  # in `<pkg>/.reg.versions.<provider>` with the same cachetime-based expiry.
  resolve: (o = {}) ->
    <~ Promise.resolve!then _
    {root, name, version, force, cachetime} = o
    cachetime = cachetime or 60 * 60
    if get-version-type(version) != \range => return lderror.reject 400, "not a range version: #name@#version"
    if "#name".length > 128 or "#version".length > 40 => return lderror.reject 404
    if !/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name) => return lderror.reject 400
    base = pthk.join(root, pthk.rectify name)
    list = (pvd) ->
      if !pvd._fetch-version-list => return lderror.reject 404
      file = pthk.join(base, ".reg.versions.#{pvd._name}")
      Promise.resolve!
        .then ->
          if force => return null
          fs.exists file .then (is-existed) ->
            if !is-existed => return null
            (s) <- fs.stat file .then _
            if Date.now! > s.mtime.getTime! + cachetime * 1000 => return null
            fs.read-file file .then (r) -> JSON.parse(r)
        .then (cached) ->
          if cached => return cached.versions
          pvd._fetch-version-list {name}
            # cache "no version available" as an empty list, to bound remote api calls
            # (github rate limit is tight without token)
            .catch (e) -> if lderror.id(e) == 404 => [] else Promise.reject e
            .then (vs) ->
              fs.ensure-dir base
                .then -> fs.write-file file, JSON.stringify({versions: vs})
                .then -> vs
    _ = (idx = -1) ~>
      pvd = if idx < 0 => @ else @_ps[idx]
      if !pvd => return lderror.reject 404
      pvd.check {name, version}
        .then -> list pvd
        .then (vs) ->
          if (v = semver.max-satisfying(vs, version)) => return v
          lderror.reject 404
        .catch (e) -> if lderror.id(e) != 404 => Promise.reject e else _(idx + 1)
    _!catch (e) -> if lderror.id(e) == 403 => lderror.reject 404 else Promise.reject e

  _fetch: (params) ->
    {root, name, version, cachetime, force, path, version-type} = params
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
            if version-type == \specific => return false
            # latest - dirty if cache expires.
            if version-type == \latest =>
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
            if force or version-type == \specific => return remote-info
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
          .then ->
            fs.remove path.base.version
            #fs.remove path.404
          .then -> fs.ensure-dir path.base.version
          .then -> fs.write-file path.version, JSON.stringify(remote-info)
          .then -> remote-info
      .then (remote-info) ~> @_fetch-bundle-file({remote-info} <<< params)

if module? => module.exports = provider
else if window? => window.registry = provider
