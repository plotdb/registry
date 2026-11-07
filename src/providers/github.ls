require! <[node-fetch lderror ../provider ../unbox]>
require! <[@plotdb/semver]>

get-token = ({name, opt}) ->
  ret = /^@([^/]+)\/(.+)$/.exec(name)
  scope = if ret => ret.1 else null
  token = if !opt => null else opt.{}scope[scope] or opt.{}repo[name] or opt.token or null

# version from a release tag. fedep >= 1.8 ( `publish -g` ) cuts the release on `dist/vX.Y.Z`,
# tags the source commit `src/vX.Y.Z` ( never a release ) and adds a bare `vX.Y.Z` alias with
# no release of its own; older releases are on `vX.Y.Z`. anything else is not a version.
tag-version = (tag) ->
  tag = "#{tag or ''}"
  if /^src\//.exec(tag) => return null
  v = tag.replace(/^dist\//, '').replace(/^v/, '')
  if semver.valid(v) => v else null

get = (url, headers) ->
  node-fetch url, {method: \GET, headers}
    .then (r) -> if r.status != 200 => lderror.reject 404 else r.json!

pvd = new provider do
  name: \github
  # list released versions, for range resolving. only the most recent 100 releases
  # are considered -- pagination is not followed to keep api usage low.
  fetch-version-list: ({name}) ->
    headers = if (token = get-token({name, opt: @_opt})) => {"Authorization": "token #{token}"} else {}
    jsonurl = "https://api.github.com/repos/#{name.replace('@','')}/releases?per_page=100"
    get jsonurl, headers
      .then (rs) -> rs.map(-> tag-version it.tag_name).filter(-> it)

  fetch-real-version: ({root, path, name, cachetime, version, version-type, force}) ->
    headers = if (token = get-token({name, opt: @_opt})) => {"Authorization": "token #{token}"} else {}
    base = "https://api.github.com/repos/#{name.replace('@','')}"
    p = if version-type == \latest => get "#base/releases/latest", headers
    # the bare tag first ( older releases, and most repos ), then fedep >= 1.8's `dist/` tag
    else get("#base/releases/tags/v#version", headers).catch (e) ->
      if lderror.id(e) != 404 => return Promise.reject e
      get "#base/releases/tags/dist/v#version", headers
    p.then (r) ->
      if !(v = tag-version r.tag_name) => return lderror.reject 404
      {version: v, url: r.tarball_url}

  fetch-bundle-file: ({root, path, name, cachetime, version, remote-info, version-type, force}) ->
    headers = if (token = get-token({name, opt: @_opt})) => {"Authorization": "token #{token}"} else {}
    node-fetch remote-info.url, {method: \GET, headers}
      .then (r) -> r.buffer!
      .then (buf) -> unbox.untar {path, buf}

pvd.tag-version = tag-version
module.exports = pvd
/*
params =
  root: 'lib'
  name: 'some-repo'
  version: 'latest'
  cachetime: 1
  opt: {token: "some-token"}

pvd.fetch-module params
  .catch (e) ->
    if !(lderror.id(e) in [404 998]) => return Promise.reject e
    else console.log "return code: ", lderror.id(e)
  .then -> console.log \done.
*/
