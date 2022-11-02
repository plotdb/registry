require! <[node-fetch lderror ../provider ../unbox]>
fs = require "fs-extra"

pvd = new provider do
  name: \github
  fetch-real-version: ({root, path, name, cachetime, version, version-type, force, opt}) ->
    headers = if (opt or {}).token => {"Authorization": "token #{opt.token}"} else {}
    release = if version-type == \latest => "releases/latest" else "releases/tags/v#version"
    jsonurl = "https://api.github.com/repos/#{name.replace('@','')}/#release"
    node-fetch jsonurl, {method: \GET, headers}
      .then (r) -> if r.status != 200 => lderror.reject 404 else r.json!
      .then (r) -> {version: (r.tag_name or '').replace(/^v/,''), url: r.tarball_url}

  fetch-bundle-file: ({root, path, name, cachetime, version, remote-info, version-type, force, opt}) ->
    headers = if (opt or {}).token => {"Authorization": "token #{opt.token}"} else {}
    node-fetch remote-info.url, {method: \GET, headers}
      .then (r) -> r.buffer!
      .then (buf) -> unbox.untar {path, buf}

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
