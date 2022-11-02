require! <[node-fetch lderror ../provider ../unbox]>

pvd = new provider do
  name: \github
  fetch-real-version: ({root, path, name, cachetime, version, version-type, force, opt}) ->
    jsonurl = "https://registry.npmjs.org/#name"
    node-fetch jsonurl, {method: \GET}
      .then (r) -> if r.status != 200 => lderror.reject 404 else r.json!
      .then (r) ->
        # TODO range version
        v = if version-type == \latest => r["dist-tags"].latest else version
        if !(url = r.versions{}[v].{}dist.tarball) => return lderror.reject 404
        {version: v, url}

  fetch-bundle-file: ({root, path, name, cachetime, version, remote-info, version-type, force, opt}) ->
    headers = if (opt or {}).token => {"Authorization": "token #{opt.token}"} else {}
    node-fetch remote-info.url, {method: \GET, headers}
      .then (r) -> r.buffer!
      .then (buf) -> unbox.untar {path, buf}

module.exports = pvd
/*
params =
  root: 'npmlib'
  name: 'ldcover'
  version: 'latest'
  cachetime: 60 * 60

pvd.fetch-module params
  .catch (e) ->
    if !(lderror.id(e) in [404 998]) => return Promise.reject e
    else console.log "return code: ", lderror.id(e)
  .then -> console.log \done.
*/
