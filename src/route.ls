require! <[fs fs-extra path @plotdb/block lderror]>

handle = ({provider, id, root}) ->
  paths = {}
  obj = {}
  id = path.resolve(path.join(\/,id)).substring(1)

  Promise.resolve!
    .then ->
      paths.404 = path.join(root, id) + ".404"
      paths.full = path.join(root, id)
      paths.dir = path.dirname paths.full
      if !(paths.full and paths.dir) => return lderror 400
      if !/^[-_a-zA-Z0-9@./]+$/.exec(id) => return lderror.reject 404

      ids = id.split(\/)
      obj <<< if ids.length > 3 =>
        name: "#{ids.0}/#{ids.1}"
        version: ids.2
        path: ids.slice(3).join(\/)
      else
        name: ids.0
        version: ids.1
        path: ids.slice(2).join(\/)
      if /:/.exec(obj.name) => [obj.ns, obj.name] = obj.name.split(':')
      if !(obj.name and obj.version and obj.path) => return lderror.reject 404

      paths.base = "#{if obj.ns => obj.ns + ':' else ''}#{obj.name}"
      paths.main = path.join(root, paths.base, \main)
      paths.version = path.join(root, paths.base, obj.version, \.version)

      if obj.version in <[main latest]> =>
        obj.version = if !fs.exists-sync(paths.version) => \master
        else fs.read-file-sync paths.version .toString!

      provider.fetch obj
        .then ({version, content}) ->
          version = path.resolve(path.join(\/, version)).substring(1)
          fs-extra.ensure-dir-sync paths.dir
          if fs.exists-sync paths.version =>
            v = fs.read-file-sync paths.version .toString!
            if v != version =>
              fs-extra.remove-sync paths.dir
              fs-extra.ensure-dir-sync paths.dir
          fs.write-file-sync paths.full, content
          fs.write-file-sync paths.version, version

          # prepare a `main` symlink to latest revision
          versions = if fs.exists-sync(paths.base) => fs.readdir-sync paths.base else []
          versions.sort (a,b) -> if a < b => 1 else if a > b => -1 else 0
          if !versions.0 or version > versions.0 or !(is-existed = fs.exists-sync(paths.main)) =>
            if is-existed=> fs.remove-sync paths.main
            des = path.join(root, paths.base, version)
            fs-extra.ensure-symlink des, paths.main

          return content
    .catch (e) ->
      # error we should skip. e.g., request of semantic versions such as `main` or `latest`
      if lderror.id(e) == 998 => return lderror.reject 404
      if lderror.id(e) != 404 => return Promise.reject e
      fs-extra.ensure-dir-sync paths.dir
      fs.write-file-sync paths.404, '404'
      lderror.reject 404

route = ({provider, root}) ->
  if !root.pub.endsWith \/ => root.pub = "#{root.pub}/"
  (req, res) ->
    url = req.originalUrl
    id = url.replace(root.pub, '').replace(/[#?].*$/,'')
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
