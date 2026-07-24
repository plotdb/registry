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

route = reg.route {provider: custom, root: {pub: '/assets/lib/', fs: root, internal: '/ilib/'}}
call = (url) -> new Promise (done) ->
  res =
    headers: {}
    status-code: 200
    set: (h) -> @headers <<< h; @
    status: (c) -> @status-code = c; @
    send: -> done {status: @status-code, headers: @headers}
    redirect: (c, u) -> done {status: c, redirect: u}
  route({originalUrl: url}, res)

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
  .then ->
    console.log if failed => "\n#failed test(s) FAILED" else "\nall tests passed"
    process.exit if failed => 1 else 0
  .catch (e) ->
    console.log "unexpected error:", e
    process.exit 1
