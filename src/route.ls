require! <[pthk lderror]>
fs = require "fs-extra"

handle = ({provider, id, root}) ->
  [paths, obj, id] = [{}, {}, pthk.rectify(id)]
  Promise.resolve!
    .then ->
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
      if !(obj.name and obj.version and obj.path) => return lderror.reject 404
      provider.fetch-module {
        root: root.fs
        name: obj.name
        version: obj.version
        force: false
        cachetime: 60 * 60
      }
    .catch (e) ->
      if lderror.id(e) == 998 => return # skip fetching. as if fetch successfully.
      if lderror.id(e) != 404 => return Promise.reject e
      lderror.reject 404

route = ({provider, root}) ->
  if !root.pub.endsWith \/ => root.pub = "#{root.pub}/"
  (req, res) ->
    url = req.originalUrl
    id = url.replace(root.pub, '').replace(/[#?].*$/,'')
    handle {provider, id, root: root.fs}
      .then ->
        res.set { "X-Accel-Redirect": pthk.join(root.internal, id) }
        res.send!
      .catch (e) ->
        if lderror.id(e) != 404 =>
          console.log e
          res.status 500 .send!
        res.status 404 .send!

module.exports = route
