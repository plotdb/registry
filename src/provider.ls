require! <[node-fetch lderror yauzl pthk tar]>
require! <[@plotdb/semver]>
fs = require "fs-extra"

fetch = node-fetch
get-version-type = (v) ->
  # `main` = admin-designated version ( frozen until force / designate ).
  # `latest` = always tracking upstream newest ( redirect-resolved, like range ).
  if v == \main => \main
  else if v == \latest => \latest
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
    # range / latest should be resolved (see `resolve` / `resolve-latest`) and redirected to a
    # specific version before fetch, so their directories are never materialized on disk
    # (nginx would serve them stale forever).
    if version-type in <[range latest]> => return lderror.reject 400, "#version-type version should be resolved before fetch"
    # simply not allowed bad / long name / version, even to prepare files.
    if "#name".length > 128 or "#version".length > 40 => return lderror.reject 998
    params = {path, version-type, root, name, version, force, cachetime}
    if !/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name) => return lderror.reject 400
    path.base.pkg = pthk.join(root, pthk.rectify name)
    path.base.version = pthk.join(path.base.pkg, version)
    path.version = pthk.join(path.base.version, '.reg.version')
    path.404 = pthk.join(path.base.version, '.reg.404')
    if version-type == \main => return @_fetch-main params
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

  # `main` is an admin-designated version, kept as a symlink pointing at a specific version dir.
  # frozen semantics: whatever exists at `main` ( our symlink, a manual dev symlink, or a
  # preinstalled real dir ) is left untouched unless forced. force = re-designate to upstream
  # latest. first touch ( nothing at `main` yet ) auto-designates to latest.
  _fetch-main: ({root, name, version, force, cachetime, path}) ->
    Promise.resolve!
      .then -> fs.lstat path.base.version .catch -> null
      .then (s) ~>
        if s and !force => return lderror.reject 998
        @resolve-latest {root, name, cachetime, force}
          .then (v) ~> @designate {root, name, version: v, cachetime}

  # resolve what `latest` currently means, walking the provider chain like `fetch` does.
  # results are cached per provider in `<pkg>/.reg.latest.<provider>` with cachetime expiry.
  resolve-latest: (o = {}) ->
    <~ Promise.resolve!then _
    {root, name, force, cachetime} = o
    cachetime = cachetime or 60 * 60
    if "#name".length > 128 => return lderror.reject 404
    if !/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name) => return lderror.reject 400
    base = pthk.join(root, pthk.rectify name)
    peek = (pvd) ->
      if !pvd._fetch-real-version => return lderror.reject 404
      file = pthk.join(base, ".reg.latest.#{pvd._name}")
      Promise.resolve!
        .then ->
          if force => return null
          fs.exists file .then (is-existed) ->
            if !is-existed => return null
            (s) <- fs.stat file .then _
            if Date.now! > s.mtime.getTime! + cachetime * 1000 => return null
            fs.read-file file .then (r) -> JSON.parse(r)
        .then (cached) ->
          if cached => return cached.version
          pvd._fetch-real-version {root, name, cachetime, version: \latest, version-type: \latest}
            .then (info) ->
              fs.ensure-dir base
                .then -> fs.write-file file, JSON.stringify({version: info.version})
                .then -> info.version
    _ = (idx = -1) ~>
      pvd = if idx < 0 => @ else @_ps[idx]
      if !pvd => return lderror.reject 404
      pvd.check {name, version: \latest}
        .then -> peek pvd
        .catch (e) -> if lderror.id(e) != 404 => Promise.reject e else _(idx + 1)
    _!catch (e) -> if lderror.id(e) == 403 => lderror.reject 404 else Promise.reject e

  # point `main` at a specific version: ensure the version is cached ( via the provider
  # chain ), then atomically repoint the `main` symlink ( relative, tmp + rename ).
  # a real dir at `main` ( preinstalled / legacy ) is only replaced here.
  # `fs.remove` on a symlink removes the link itself -- a manual symlink's target
  # ( e.g. a dev repo ) is never deleted.
  designate: (o = {}) ->
    <~ Promise.resolve!then _
    {root, name, version, cachetime} = o
    if get-version-type(version) != \specific => return lderror.reject 400, "designate requires a specific version"
    if "#name".length > 128 or "#version".length > 40 => return lderror.reject 404
    if !/^(?:@[0-9a-z._-]+\/)?[0-9a-z._-]+$/.test(name) => return lderror.reject 400
    base = pthk.join(root, pthk.rectify name)
    [main-path, tmp] = [pthk.join(base, \main), pthk.join(base, ".main.#{process.pid}.tmp")]
    Promise.resolve!
      .then ~>
        (is-existed) <~ fs.exists pthk.join(base, version, \.reg.version) .then _
        if is-existed => return
        @fetch {root, name, version, force: false, cachetime}
      .then -> fs.lstat main-path .catch -> null
      .then (s) ->
        Promise.resolve!
          .then -> if s and !s.isSymbolicLink! => fs.remove main-path
          .then -> fs.remove tmp
          .then -> fs.symlink version, tmp
          .then -> fs.rename tmp, main-path
      .then -> {name, version}

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
            # specific version existed. never dirty.
            # ( only specific versions reach here -- main / latest / range are handled upstream )
            return false
          .then (is-dirty) -> if !is-dirty => return lderror.reject 998
      .then ~>
        # 2. in this block, we confirm the real version info of the specific version.
        (remote-info) <~ @_fetch-real-version params .then _
        Promise.resolve!
          .then ->
            fs.remove path.base.version
            #fs.remove path.404
          .then -> fs.ensure-dir path.base.version
          .then -> fs.write-file path.version, JSON.stringify(remote-info)
          .then -> remote-info
      .then (remote-info) ~> @_fetch-bundle-file({remote-info} <<< params)

if module? => module.exports = provider
else if window? => window.registry = provider
