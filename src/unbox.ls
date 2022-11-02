require! <[yauzl tar pthk stream]>
fs = require "fs-extra"

unzip = ({path, buf}) ->
  (res, rej) <- new Promise _
  (e, zipfile) <- yauzl.from-buffer buf, {autoClose: false, lazyEntries: true}, _
  if e => return rej e
  zipfile.read-entry!
  zipfile.on \end, -> zipfile.close!; res!
  zipfile.on \entry, (entry) ->
    if /\/$/.test(entry.file-name) => return zipfile.read-entry!
    (e, rs) <- zipfile.openReadStream entry, _
    if e => return rej e
    rs.on \end, -> zipfile.read-entry!
    dirs = entry.file-name.split(\/)
    # TODO this depends on how remote zip their packages.
    if !(fn = dirs.slice 1 .join \/) => fn = entry.file-name
    desfile = pthk.join(path.base.version, pthk.rectify(fn))
    desdir = pthk.dirname desfile
    fs.ensure-dir desdir
      .then -> rs.pipe fs.createWriteStream(desfile)

untar = ({path, buf}) ->
  stream.Readable.from buf
    .pipe ws = tar.x strip: 1, cwd: path.base.version
  (res, rej) <- new Promise _
  ws.on \close, -> res!
  ws.on \error, -> rej it


module.exports = {unzip, untar}
