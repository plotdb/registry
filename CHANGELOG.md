# Change Logs

## v0.0.10

 - features:
   - split `main` / `latest` semantics ( previously aliases ):
     - `latest` always tracks the upstream newest ( npm dist-tag convention ) and is
       302-redirect-resolved like ranges -- never materialized on disk. resolution cached
       per provider in `<pkg>/.reg.latest.<provider>` with cachetime expiry.
     - `main` is the admin-designated version: a symlink pointing at a specific version
       dir, served from disk with no redirect hop. frozen until an admin decision --
       `force` fetch re-designates to upstream latest ( existing flush routes keep working
       unchanged ), `designate` pins a chosen version. first touch auto-designates to
       the latest at that moment.
   - add `provider.designate` and a `registry.designate` admin route factory
     ( recommended mount: `/staff/registry/designate/*`, aligned with
     `/staff/registry/flush/*` ).
   - protect manually-placed `main`: a preinstalled real dir or a manual symlink
     ( e.g. pointing at a dev working copy ) is never touched by normal requests, and a
     symlink's target is never deleted -- force / designate only replaces the link itself.
 - tweaks:
   - `main` / `latest` no longer create `.reg.404` marker files; negative results are
     absorbed by the nginx proxy cache instead.
   - dev ( no-nginx ) behavior of `main` now matches production: frozen, no TTL refetch.
 - doc:
   - add "Caching Model" section in README: cache layers, version-type behaviors,
     query-string ( cachestamp ) reach, and deliberate choices ( headerless 302,
     Set-Cookie handling, chain-order resolution ). all claims verified against
     a local nginx + backend setup.


## v0.0.9

 - features:
   - support semver range version ( `~x.y.z` / `^x.y.z`, `^` comes url-encoded as `%5E` ):
     range urls are resolved to the latest satisfying version and 302-redirected to the
     specific version url, so content urls stay immutable and range dirs never land on disk.
   - `provider.resolve` resolves a range against the provider chain; version lists are
     cached per provider in `<pkg>/.reg.versions.<provider>` with cachetime-based expiry.
   - providers implement `fetch-version-list`: github via `releases?per_page=100`
     ( most recent 100 only ), npm via registry metadata `versions`.
   - ngx config: `proxy_cache_valid` now covers 302 ( ttl of range resolving ) and 400.
   - ngx config: ignore / hide `Set-Cookie` in registry backend proxy -- session middleware
     sets cookie on every response, which silently disabled proxy cache altogether.
 - bug fix:
   - fix npm provider name ( was `github` )
   - route now responds 400 ( instead of 404 ) for invalid version / range syntax,
     and no longer double-sends response on 500.
 - tweaks:
   - move `@plotdb/semver` to dependencies ( requires v0.0.4+, for `max-satisfying` etc. )
     and drop the duplicate devDependencies entry
   - add `build` / `test` npm scripts; add stub-based tests covering range resolving,
     redirect routing, cache reuse and error codes ( `test/index.ls`, no network needed )
   - upgrade `tar` 6 -> 7.5.21 for critical path-traversal / symlink-poisoning advisories
     ( registry extracts remote tarballs into an nginx-served dir, so these matter here );
     api usage ( `tar.x {strip, cwd}` ) is unchanged, but node >= 18 is now required
     ( `engines` updated; was >= 10 )


## v0.0.8

 - prevent long package name (>128 chars) and long version (>40 chars)
 - use lderror 998 for directly skip reg.404 preparation
 - upgrade dependencies


## v0.0.7

 - fix bug: incorrect id parsing in route which recognize path as part of version


## v0.0.6

 - upgrade dependencies and remove unused `request` to suppress npm vulnerability report


## v0.0.5

 - reject with 404 if id is empty.


## v0.0.4

 - skip 400 error, treat it as 404 and suppress error log for it.


## v0.0.3

 - add additional message when `version-type` can't be analyzed correctly


## v0.0.2

 - support function-based customized option (currently for `cachetime` and `force` option)


## v0.0.1

 - init release
