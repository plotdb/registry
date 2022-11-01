require! <[node-fetch lderror]>

fetch = node-fetch

provider = (o = {}) ->
  @_name = o.name or "unnamed#{provider._idx++}"
  @_ps = [] ++ (o.chain or [])
  @_fetch = o.fetch
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

provider.add new provider do
  name: \github
  url: ({name, version, path}) ->
    v = "v#version"
    if !/^[0-9.]+$/.exec(version) => v = version
    "https://raw.githubusercontent.com/#{name.replace(/^@/,'')}/#v/#path"
  fetch: (o) ->
    opt = {}
    Promise.resolve!
      .then ~>
        ret = /^@([^/]+)\/(.+)$/.exec(o.name)
        scope = if ret => ret.1 else null
        opt <<< o <<< {name: o.name.replace(/^@/,'')}
        token = if !@_opt => null else @_opt.{}scope[scope] or @_opt.{}repo[o.name] or @_opt.token
        headers = if !token => {} else {"Authorization": "token #{token}"}
        if !token and o.ns != \github => return lderror.reject 404
        fetch @url(opt), {method: \GET, headers}
      .catch (e) ->
        if lderror.id(e) == 404 => return lderror.reject 404
        Promise.reject e
      .then (r) -> if r.status == 404 => lderror.reject 404 else r.text!
      .then -> {version: o.version, content: it}

provider.add new provider do
  name: \jsdelivr
  url: ({name, version, path}) ->
    "https://cdn.jsdelivr.net/npm/#{name}#{version and "@#version" or ''}#{path and "/#path" or ''}"
  fetch: (o) ->
    fetch @url(o)
      .catch -> lderror.reject 404
      .then (r) ->
        v = r.headers.get(\x-jsd-version)
        if !v => return lderror.reject 404
        r.text!then -> {version: v or version, content: it}

provider.add new provider do
  name: \unpkg
  url: ({name, version, path}) ->
    "https://unpkg.com/#{name}#{version and "@#version" or ''}#{path and "/#path" or ''}"
  fetch: (o = {}) ->
    fetch @url o
      .catch -> lderror.reject 404
      .then (r) ->
        v = (/^https:\/\/unpkg.com\/([^@]+)@([^/]+)\//.exec(r.url) or []).2
        r.text!then -> {version: v or o.version, content: it}

if module? => module.exports = provider
else if window? => window.registry = provider
