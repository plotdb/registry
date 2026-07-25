# stub-based tests for range resolving / routing. no network access involved.
reg = require "../src/index.ls"
require! <[lderror]>
fs = require "fs-extra"

root = "#{__dirname}/.cache"
fs.remove-sync root

failed = 0
eq = (desc, actual, expected) ->
  if JSON.stringify(actual) == JSON.stringify(expected) => console.log "  ok   : #desc"
  else
    failed := failed + 1
    console.log "  FAIL : #desc - got #{JSON.stringify actual}, expect #{JSON.stringify expected}"

count = {p1: 0, p2: 0}
p1 = new reg.provider do
  name: \p1
  fetch-version-list: ({name}) ->
    count.p1++
    Promise.resolve <[0.1.0 0.2.0]>
p2 = new reg.provider do
  name: \p2
  fetch-version-list: ({name}) ->
    count.p2++
    if name == \p1only => return lderror.reject 404
    Promise.resolve <[1.0.0 1.2.3 1.4.0 2.0.0-beta.1]>
custom = new reg.provider do
  name: \custom
  check: ({name}) -> if name == \denied => lderror.reject 403 else Promise.resolve!
custom.chain [p1, p2]

# providers with full fetch support, for main / latest / designate semantics.
# `stub.latest` is mutable so tests can simulate an upstream release.
stub = {latest: "1.4.0", versions: <[1.0.0 1.2.3 1.4.0 2.0.0]>}
count.lp = {real: 0, bundle: 0}
lp = new reg.provider do
  name: \lp
  fetch-version-list: ({name}) -> Promise.resolve stub.versions
  fetch-real-version: ({name, version, version-type}) ->
    count.lp.real++
    v = if version-type == \latest => stub.latest else version
    if !(v in stub.versions) => return lderror.reject 404
    Promise.resolve {version: v, url: "stub://lp/#name/#v"}
  fetch-bundle-file: ({path, remote-info}) ->
    count.lp.bundle++
    fs.ensure-dir path.base.version
      .then -> fs.write-file "#{path.base.version}/index.min.js", "content #{remote-info.version}"
custom2 = new reg.provider {name: \custom2}
custom2.chain [lp]

mk-call = (r) -> (url) -> new Promise (done) ->
  res =
    headers: {}
    status-code: 200
    set: (h) -> @headers <<< h; @
    status: (c) -> @status-code = c; @
    send: -> done {status: @status-code, headers: @headers}
    json: (o) -> done {status: @status-code, json: o}
    redirect: (c, u) -> done {status: c, redirect: u}
  r({originalUrl: url}, res)

call = mk-call reg.route {provider: custom, root: {pub: '/assets/lib/', fs: root, internal: '/ilib/'}}
call2 = mk-call reg.route {provider: custom2, root: {pub: '/assets/lib/', fs: root, internal: '/ilib/'}}
flush = mk-call reg.route {provider: custom2, opt: (-> {force: true}), root: {pub: '/assets/lib/', fs: root, internal: '/ilib/'}}
desig = mk-call reg.designate {provider: custom2, root: {pub: '/staff/registry/designate/', fs: root}}

code-of = (p) -> p.then (-> \resolved), (e) -> lderror.id e

Promise.resolve!
  .then ->
    # chain falls through: p1 has no 1.x, p2 resolves
    custom.resolve {root, name: \pkg, version: \^1.2.0} .then ->
      eq "resolve ^1.2.0 falls through chain to p2", it, "1.4.0"
  .then ->
    # caret with zero major locks minor; resolved from p1 before p2 is consulted
    custom.resolve {root, name: \pkg, version: \^0.1.0} .then ->
      eq "resolve ^0.1.0 from p1", it, "0.1.0"
  .then ->
    # prerelease is not picked by a release-only range
    custom.resolve {root, name: \pkg, version: \^1.4.0} .then ->
      eq "resolve ^1.4.0 skips 2.0.0-beta.1", it, "1.4.0"
  .then ->
    # second resolve hits version-list cache; no extra fetch-version-list calls
    [c1, c2] = [count.p1, count.p2]
    custom.resolve {root, name: \pkg, version: \~1.2.0} .then ->
      eq "resolve ~1.2.0 (cached)", it, "1.2.3"
      eq "version-list cache reused", [count.p1, count.p2], [c1, c2]
  .then ->
    # force refetches the version list
    [c1, c2] = [count.p1, count.p2]
    custom.resolve {root, name: \pkg, version: \~1.2.0, force: true} .then ->
      eq "force refetches version list", [count.p1, count.p2], [c1 + 1, c2 + 1]
  .then ->
    # provider list 404 is cached as empty list and skipped
    code-of custom.resolve {root, name: \p1only, version: \^1.0.0} .then ->
      eq "list-404 provider falls back to 404", it, 404
  .then -> code-of custom.resolve {root, name: \pkg, version: \^9.0.0} .then ->
    eq "unsatisfiable range rejects 404", it, 404
  .then -> code-of custom.resolve {root, name: \denied, version: \^1.0.0} .then ->
    eq "denied name rejects 404 (403 mapped)", it, 404
  .then -> code-of custom.resolve {root, name: \pkg, version: \1.2.3} .then ->
    eq "resolve with non-range rejects 400", it, 400
  .then -> code-of custom.fetch {root, name: \pkg, version: \^1.2.0} .then ->
    eq "fetch with range rejects 400", it, 400
  .then -> call '/assets/lib/pkg/%5E1.2.0/a/b.js' .then ->
    eq "route %5E1.2.0 redirects", it, {status: 302, redirect: '/assets/lib/pkg/1.4.0/a/b.js'}
  .then -> call '/assets/lib/pkg/~1.2.0/a.js' .then ->
    eq "route ~1.2.0 redirects", it, {status: 302, redirect: '/assets/lib/pkg/1.2.3/a.js'}
  .then -> call '/assets/lib/@scope/pkg/%5E1.2.0/a.js' .then ->
    eq "route scoped name redirects", it, {status: 302, redirect: '/assets/lib/@scope/pkg/1.4.0/a.js'}
  .then -> call '/assets/lib/pkg/%5Ebad/a.js' .then ->
    eq "route invalid range responds 400", it.status, 400
  .then -> call '/assets/lib/pkg/%5E9.0.0/a.js' .then ->
    eq "route unsatisfiable range responds 404", it.status, 404
  .then ->
    # range dirs should never be materialized on disk
    dirs = fs.readdir-sync "#root/pkg" .filter -> !/^\.reg\./.test(it)
    eq "no range dir on disk", dirs, []

  # ---- main ( designated ) / latest ( tracking ) semantics ----
  .then -> call2 '/assets/lib/lpkg/latest/index.min.js' .then ->
    eq "latest redirects to resolved newest", it, {status: 302, redirect: '/assets/lib/lpkg/1.4.0/index.min.js'}
  .then ->
    c = count.lp.real
    call2 '/assets/lib/lpkg/latest/a.js' .then ->
      eq "latest resolution cached ( .reg.latest )", [it.status, count.lp.real], [302, c]
  .then -> code-of custom2.fetch {root, name: \lpkg, version: \latest} .then ->
    eq "fetch with latest rejects 400", it, 400

  .then -> call2 '/assets/lib/lpkg/main/index.min.js' .then ->
    st = fs.lstat-sync "#root/lpkg/main"
    eq "main first touch: designated + served", [it.status, st.isSymbolicLink!, fs.readlink-sync("#root/lpkg/main")], [200, true, "1.4.0"]
  .then ->
    stub.latest = "2.0.0"   # upstream releases a new version
    cb = count.lp.bundle
    call2 '/assets/lib/lpkg/main/index.min.js' .then ->
      eq "main frozen: upstream update invisible", [it.status, fs.readlink-sync("#root/lpkg/main"), count.lp.bundle], [200, "1.4.0", cb]
  .then -> flush '/assets/lib/lpkg/main/index.min.js' .then ->
    eq "force flush re-designates main to newest", [it.status, fs.readlink-sync("#root/lpkg/main")], [200, "2.0.0"]
    eq "old version dir remains ( immutable )", fs.exists-sync("#root/lpkg/1.4.0/index.min.js"), true

  .then ->
    # manual dev symlink: untouched unless forced; target dir itself is never deleted
    fs.ensure-dir-sync "#root/devrepo"
    fs.write-file-sync "#root/devrepo/index.min.js", "dev content"
    fs.ensure-dir-sync "#root/dpkg"
    fs.symlink-sync "../devrepo", "#root/dpkg/main"
    call2 '/assets/lib/dpkg/main/index.min.js' .then ->
      eq "manual symlink main: served frozen", [it.status, fs.readlink-sync("#root/dpkg/main")], [200, "../devrepo"]
  .then -> flush '/assets/lib/dpkg/main/index.min.js' .then ->
    eq "force flush replaces manual symlink with published latest", fs.readlink-sync("#root/dpkg/main"), "2.0.0"
    eq "dev repo target not deleted", fs.read-file-sync("#root/devrepo/index.min.js", \utf8), "dev content"

  .then ->
    # preinstalled real dir: hands off on normal requests
    fs.ensure-dir-sync "#root/ppkg/main"
    fs.write-file-sync "#root/ppkg/main/index.min.js", "preinstalled"
    call2 '/assets/lib/ppkg/main/index.min.js' .then ->
      eq "preinstalled main: untouched", [it.status, fs.read-file-sync("#root/ppkg/main/index.min.js", \utf8)], [200, "preinstalled"]
  .then -> flush '/assets/lib/ppkg/main/index.min.js' .then ->
    eq "force flush takes over preinstalled dir", fs.lstat-sync("#root/ppkg/main").isSymbolicLink!, true

  # ---- designate route ----
  .then -> desig '/staff/registry/designate/lpkg/1.2.3' .then ->
    eq "designate to a specific version", [it.status, fs.readlink-sync("#root/lpkg/main")], [200, "1.2.3"]
    eq "designated version fetched via chain", fs.exists-sync("#root/lpkg/1.2.3/index.min.js"), true
  .then -> desig '/staff/registry/designate/lpkg/2.0.0/some/extra/path.js' .then ->
    eq "designate ignores trailing path", [it.status, fs.readlink-sync("#root/lpkg/main")], [200, "2.0.0"]
  .then -> desig '/staff/registry/designate/lpkg/notaversion' .then ->
    eq "designate invalid version responds 400", it.status, 400
  .then -> desig '/staff/registry/designate/lpkg/9.9.9' .then ->
    eq "designate unknown version responds 404", it.status, 404

  .then ->
    console.log if failed => "\n#failed test(s) FAILED" else "\nall tests passed"
    process.exit if failed => 1 else 0
  .catch (e) ->
    console.log "unexpected error:", e
    process.exit 1
