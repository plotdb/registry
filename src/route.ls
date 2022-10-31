require! <[fs fs-extra path @plotdb/block lderror]>

handle = ({provider, id, root}) ->
  p404 = path.join(root, path.resolve(path.join(\/, id)).substring(1)) + ".404"
  p = path.join(root, path.resolve(path.join(\/, id)).substring(1))
  dir = path.dirname p
  verfile = path.join(dir, \.version)
  Promise.resolve!
    .then ->
      if !(p and dir) => return lderror 400
      fs-extra.ensure-dir dir
    .then ->
      if !/^[-:a-zA-Z0-9@./]+$/.exec(id) => return lderror.reject 404
      ids = id.split(\/)
      obj = if ids.length > 3 =>
        name: "#{ids.0}/#{ids.1}"
        version: ids.2
        path: ids.slice(3).join(\/)
      else
        name: ids.0
        version: ids.1
        path: ids.slice(2).join(\/)
      if /:/.exec(obj.name) => [obj.ns, obj.name] = obj.name.split(':')
      if !(obj.name and obj.version and obj.path) => return lderror.reject 404
      if obj.version in <[main latest]> => return lderror.reject 998
      provider.fetch obj
        .then ({version, content}) ->
          if fs.exists-sync verfile =>
            v = fs.read-file-sync verfile
            if v != version =>
              fs-extra.remove-sync dir
              fs-extra.ensure-dir-sync dir
          fs.write-file-sync p, content
          fs.write-file-sync verfile, version

          # prepare a `main` symlink to latest revision
          base = "#{if obj.ns => obj.ns + ':' else ''}#{obj.name}"
          main = path.join(root, path.resolve(path.join(\/, base, 'main')).substring(1))
          versions = if fs.exists-sync(base) => fs.readdir-sync base else []
          versions.sort (a,b) -> if a < b => 1 else if a > b => -1 else 0
          if !versions.0 or version > versions.0 =>
            if fs.exists-sync main => fs.removeSync main
            des = path.join(root, path.resolve(path.join(\/, base, version)).substring(1))
            fs-extra.ensure-symlink des, main

          return content
    .catch (e) ->
      # error we should skip. e.g., request of semantic versions such as `main` or `latest`
      if lderror.id(e) == 998 => return lderror.reject 404
      if lderror.id(e) != 404 => return Promise.reject e
      fs.write-file-sync p404, '404'
      lderror.reject 404

route = ({provider, root}) ->
  if !root.pub.endsWith \/ => root.pub = "#{root.pub}/"
  (req, res) ->
    url = req.originalUrl
    id = url.replace(root.pub, '')
    handle {provider, id, root: root.fs}
      .then ->
        res.set { "X-Accel-Redirect": path.join(root.internal, id) }
        res.send!
      .catch (e) ->
        if lderror.id(e) != 404 =>
          console.log e
          res.status 500 .send!
        res.status 404 .send!

module.exports = route
