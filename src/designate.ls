require! <[pthk lderror]>

# admin route for designating `main` of a package to a specific version.
# expected to be mounted like ( naming aligned with the flush route ):
#
#     app.get '/staff/registry/designate/*', is-admin, registry.designate {
#       provider: custom
#       root: {pub: '/staff/registry/designate/', fs: '/var/lib/cdn/cache/assets/lib'}
#     }
#
# url format: `<name>/<version>`. trailing path segments ( if any ) are ignored,
# so a public asset url can be pasted with only the prefix swapped.
designate = ({provider, root, opt}) ->
  if !root.pub.endsWith \/ => root.pub = "#{root.pub}/"
  (req, res) ->
    url = req.originalUrl
    id = pthk.rectify(url.replace(root.pub, '').replace(/[#?].*$/,''))
    _o = if !opt => {}
    else if typeof(opt) == \function => opt(req, res)
    else opt
    Promise.resolve!
      .then ->
        if !(id and /^[-_a-zA-Z0-9@./]+$/.exec(id)) => return lderror.reject 404
        ids = id.split(\/)
        [name, version] = if (ids.0 or '').0 == \@ =>
          ["#{ids.0}/#{ids.1}", ids.2]
        else
          [ids.0, ids.1]
        if !(name and version) => return lderror.reject 404
        provider.designate {root: root.fs, name, version} <<< _o
      .then ({name, version}) -> res.status 200 .json {name, version}
      .catch (e) ->
        code = lderror.id e
        if code in [400 404] => return res.status code .send!
        console.log e
        res.status 500 .send!

module.exports = designate
