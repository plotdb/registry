# @plotdb/registry

`@plotdb/registry` is a local package cache service for dynamic package loading. Similar to CDN but it's meant to provide package access control directly via the backend access point.

Basic idea:

 - reverse proxy (nginx) check if a file exists. return it directly if found.
 - if the file is not found, request is passed to registry backend.
 - registry backend looks up the given package based on the file's path, and download the package if found.
 - registry backend instruct nginx to redirect for the downloaded file.

You can config the backend router to allow only certain packages to be downloaded, or provide additional information to download private packages.

`@plotdb/registry` provides:

 - a package provider interface for fetching, gatekeeping and chaining other package providers.
 - an express router for accepting fetching requests from users.
 - a nginx config generator for accessing requested files based on availability of file.


## Usage

`@plotdb/registry` is expected to be used along with expressjs and nginx.

First, include `@plotdb/registry`:

    registry = require("@plotdb/registry")


prepare a provider:

    # our own provider, only fetch modules in @plotdb scope
    myprovider = new registry do
      check: ({name, version, path}) ->
        if /@plotdb/.exec(name) => return Promise.resolve!
        return lderror.reject 403 # or 998 (skipped) to prevent creating reg.404 file
    # chain a default jsdelivr provider
    myprovider.chain(registry.provider.jsdelivr);

add a route:

    app.get("/mylib/*", registry.route({
      provide: myprovider
      root:
        pub: "/lib"               # root path in URL users access.
        fs: "/var/lib/cdn/cache"  # root folder for `@plotdb/registry` to store file.
        internal: "/ilib"         # internal redirect URL from server to nginx.
    });

generate customied nginx config:

    npx registry-nginx -c myconfig.yaml > reg.ngx


include the generated file in the server block of your main nginx config:

    server {
      include reg.ngx
    }

where the config file ( `myconfig.yaml` above ) should contains following fields:

 - `internal`: internal path for `X-Accel-Redirect`. should be a dummy path which is not used.
 - `pub`: `pub` in the `root` parameter in `registry.route` call.
 - `fs`: `fs` in the `root` parameter in `registry.route` call.
 - `upstream`: upstream url for your backend server defined in your nginx config file. e.g., `backend_api`.
 - `cache`: with two subfields:
   - `name`: cache name.
     - for caching to work, you should manually add a cache path directive using the name configed here, e.g.,

           proxy_cache_path /tmp/cache keys_zone=mycache:10m levels=1:2 inactive=600s max_size=100m; 

   - `period`: how long the nginx proxy cache should last. e.g., `10m`.

Check `sample/config.ngx` and `sample/config.yaml` for a reference of nginx config file and corresponding config yaml.


### Admin Routes

Two admin operations are expected, mounted under a guarded prefix
( recommended naming: `/staff/registry/<operation>/` ):

    # flush: force re-fetch. for `main`, this re-designates to the upstream latest.
    app.get("/staff/registry/flush/*", isAdmin, registry.route({
      provider: myprovider,
      opt: function() { return {force: true}; },
      root: {pub: "/staff/registry/flush/", fs: "...", internal: "/ilib/"}
    }));

    # designate: pin `main` of a package to a chosen version.
    # url format: <name>/<version>; trailing path segments are ignored,
    # so a public asset url can be pasted with only the prefix swapped.
    app.get("/staff/registry/designate/*", isAdmin, registry.designate({
      provider: myprovider,
      root: {pub: "/staff/registry/designate/", fs: "..."}
    }));


## Caching Model

Four cache layers are involved when serving a package file. From the client inward:

 1. **browser cache**: keyed by full URL including query string.
 2. **nginx `proxy_cache`**: caches backend responses ( 200 / 302 / 400 / 404, for `cache.period` ).
    the default `proxy_cache_key` includes `$request_uri`, **query string included**.
 3. **nginx `try_files` ( disk )**: files materialized under `fs` root are served directly;
    matching is done on `$uri`, **query string excluded**. requests never reach the backend
    once the file exists on disk.
 4. **registry backend internal caches**: version-list cache ( `.reg.versions.<provider>` ),
    negative cache ( `.reg.404` ) and `main` staleness check, all expired by
    file mtime + `cachetime`. the backend strips query strings entirely.

How each version type travels through these layers:

 - **specific version** ( `1.2.3` ): immutable by definition. the first request falls through
   to the backend, which downloads and unpacks the package, then replies with
   `X-Accel-Redirect`; every later request is served from disk by `try_files` ( layer 3 )
   without touching the backend. this is correct exactly because the content never changes.
 - **range version** ( `~1.2.3` / `^1.2.3`, `^` arrives url-encoded as `%5E` ): never
   materialized on disk, so `try_files` always misses and the request reaches the backend,
   which 302-redirects to the resolved specific version. effective staleness bound for
   seeing a newly released version = `cache.period` ( layer 2, caches the 302 )
   + `cachetime` ( layer 4, caches the version list ).
 - **`latest`**: always tracks the upstream newest ( github latest release / npm dist-tag
   `latest` -- the keyword follows the npm dist-tag convention ). handled exactly like a
   range: never on disk, 302-redirected, same staleness bound.
 - **`main`**: the admin-designated version, kept as a **symlink** pointing at a specific
   version dir, served from disk by layer 3 ( no redirect hop ). frozen semantics: nothing
   updates `main` automatically -- not on requests, not on upstream releases. it changes only
   through a `force` fetch ( re-designate to upstream latest, e.g. an admin flush route ),
   an explicit `designate` call ( pin to a chosen version ), or manual placement:
   a real ( non-symlink ) dir at `main` is treated as preinstalled and never touched by
   normal requests; a manual symlink ( e.g. pointing at a dev working copy ) likewise
   survives everything except an explicit force / designate, and even then only the link
   is replaced -- its target is never deleted. first touch of a package with nothing at
   `main` auto-designates to the upstream latest at that moment.

Query-string cache busting ( e.g. a `cachestamp` param ) therefore only goes so deep:
it always busts layer 1 and layer 2 ( new query = new cache key, the request reaches the
backend ), but never layer 3 ( disk files, including `main` ) nor layer 4 ( backend TTLs ).
a bumped cachestamp on a range URL yields a fresh 302, but the resolved version may still
come from the version-list cache until `cachetime` expires.

Some deliberate choices worth knowing before changing them:

 - **the 302 carries no cache headers on purpose.** browsers do not cache a redirect
   without freshness info ( heuristic caching needs `Last-Modified`, which we do not send ),
   so clients re-request the range URL every time, while nginx still absorbs the load via
   `proxy_cache_valid`. do NOT add `Cache-Control: no-cache` to make browser behavior
   "explicit": upstream `Cache-Control` overrides `proxy_cache_valid`, which would disable
   the nginx 302 cache as well ( unless you also add `proxy_ignore_headers Cache-Control` ).
 - **`Set-Cookie` must be ignored and hidden in the backend proxy location.** session
   middleware sets a cookie on every response, which by default prevents nginx from caching
   anything at all. the generated config includes `proxy_ignore_headers Set-Cookie` +
   `proxy_hide_header Set-Cookie`; the latter is required, otherwise a cached response
   would replay one user's session cookie to other users.
 - **range resolution follows chain order, not the union of providers.** the first provider
   with any satisfying version wins ( consistent with how `fetch` falls through on 404 ).
   if a package has github releases, github is the source of truth for ranges: a newer
   version published only to npm stays invisible. keep github releases and npm publishes
   in sync for packages available on both.


## Registry Provider Specification

Registry providers are used to access a requested resource which is defined by its `namespace`, `name`, `version`, `path` and optionally `type`.

A registry provider can be either following format:
 - object: described below
 - (TBD) string: indicate a root path for a requested resource
 - (TBD) function: return an URL for a requested resource when called

A registry provider object should contain following fields:

 - `name`: provider name
 - `check({name, version})`: access control for the given package `{name, version}`.
   - when omitted, no check will be done.
   - return:
     - if the given package is not allowed:
       - a Promise rejects with `{id: 403, name: 'lderror'}` (or, `lderror.reject(403)`)
     - otherwise:
       - a Promise resolves with nothing.

 - `fetchRealVersion(opt)`: fetch version and tarball informations of a given package.
   - return a promise resolves with an object.
     - resolved object should contains following fields:
       - `version`: actual version for the given package information.
       - `url`: tarball url
   - `opt` is an object with following fields:
     - `root`: root directory of registry cache. 
     - `path`: an object with following fields:
       - `base`: an object with following fields:
         - `pkg`: package root directory ( exclude version name )
         - `version`: package directory of specific version.
       - `version`: path of the internal file storing return object of `fetchRealVersion` call.
       - `404`: path of the internal file that if it exists then the given version of this package is not found.
     - `name`: package name.
     - `version`: package version. should be semver. could be version range, `latest` or `main`.
     - `cachetime`: expected cache time in seconds. default 3600 if omitted.`
     - `versionType`: either `latest`, `specifc` or `range`.
     - `force`: when true, should always try to fetch, ignoring cache or current status.
 - `fetchBundleFile(opt)`: fetch the given package and ectract it.
   - return a promise resolves when bundle file is extracted completely.
   - check `fetchRealVersion` for the definition of `opt`.
 - `fetchVersionList({name})`: ( optional ) list available versions of a given package, for range resolving.
   - return a promise resolves a list of version strings ( e.g., `["1.0.0", "1.1.0"]` ).
   - github provider lists via `releases?per_page=100` ( most recent 100 releases only );
     npm provider lists via registry metadata `versions` field.
   - a provider without `fetchVersionList` is simply skipped when resolving a range.

A provider provides following APIs:

 - `opt(opt)`: provide additional options for this provider.
   - once provided, this can be accessed via `this.\_opt` internally.
 - `fetch(opt)`: download the indicated released packages and create a local copy at specified location.
   - `opt` is an object with following fields:
      - `root`: root directory for keeping cached files.
      - `name`: package name. scope is possible, such as `@plotdb/block`.
      - `version`: package version. should always in semver format (e.g., `1.0.0`) or `main`.
        - `main` is the designated ( locked ) version: frozen once set, updated only by
          `force` ( re-designate to upstream latest ) or `designate()`. see "Caching Model".
        - in github, tags is used for fetching release. tags should be in format `vx.y.z`. e.g., `v1.0.0`.
        - range ( e.g. `^1.2.3` ) and `latest` versions are rejected with 400: they should be
          resolved to a specific version with `resolve()` / `resolveLatest()` first,
          so their dirs never land on disk.
      - `force`: default false. when true, ignore cache / 404 status and always try fetching package again.
      - `cachetime`: default 3600 seconds. cache for how long (in seconds) since the last fetch attempts.
    - return value: a Promise, resolves if package is found and downloaded. reject `e` in following situation:
      - lderror.id(e) is not 0, but following:
        - 404: package not found.
        - 998: package either found or not found. result cached so no fetch is performed.
          - by our design, router send a `X-Accel-Redirect` to nginx if 998.
            if it's actually 404, nginx will then look up the file and report 404 after found not found.
          - the result will then cached by nginx and won't hit registry backend until cache expires.
      - otherwise, it's an internal exception and should be logged and tracked.
 - `resolve(opt)`: resolve a range version ( `~x.y.z` / `^x.y.z`, also `>` / `>=` ) to the latest
   specific version satisfying it, walking the provider chain like `fetch` does.
   - `opt` takes `root` / `name` / `version` / `force` / `cachetime` as in `fetch`,
     where `version` must be a range.
   - version lists are cached per provider in `<pkg>/.reg.versions.<provider>`,
     expired by mtime + `cachetime` like other cache files.
   - return value: a Promise resolving the version string; rejects 400 for a non-range
     version, 404 if no provider has a satisfying version.
   - `registry.route` uses this to serve range urls: it responds a 302 redirect to the
     specific version url ( `^` arrives url-encoded as `%5E`; `~` needs no encoding ),
     so content urls stay immutable and the redirect ttl is governed by nginx
     `proxy_cache_valid 302`.
 - `resolveLatest(opt)`: resolve what `latest` currently means ( github latest release /
   npm dist-tag ), walking the provider chain. results are cached per provider in
   `<pkg>/.reg.latest.<provider>` with `cachetime` expiry. `registry.route` uses this
   to serve `latest` urls as a 302 redirect, same as ranges.
 - `designate(opt)`: point `main` at a specific version.
   - `opt`: `root` / `name` / `version` ( must be specific ) / `cachetime`.
   - ensures the version is cached ( via the provider chain ), then atomically repoints
     the `main` symlink ( relative link, tmp + rename ). a real dir at `main`
     ( preinstalled / legacy ) is replaced only here; a symlink's target is never deleted.
   - return value: a Promise resolving `{name, version}`.
 - `check({name, version})`: call the `check()` function provided in constructor.
 - `chain(providers)`: chain given `providers` in this provider.
   - `providers`: either another provider, or a list of other providers.
   - chained providers will be called if current provider return 404.


## License

MIT License
