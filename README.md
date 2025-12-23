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

A provider provides following APIs:

 - `opt(opt)`: provide additional options for this provider.
   - once provided, this can be accessed via `this.\_opt` internally.
 - `fetch(opt)`: download the indicated released packages and create a local copy at specified location.
   - `opt` is an object with following fields:
      - `root`: root directory for keeping cached files.
      - `name`: package name. scope is possible, such as `@plotdb/block`.
      - `version`: package version. should always in semver format (e.g., `1.0.0`) or one of `latest` or `main`.
        - in `@plotdb/block` `main` is the locked version, however there is no locked version defined here,
          so `main` is equivalent to `latest`.
        - in github, tags is used for fetching release. tags should be in format `vx.y.z`. e.g., `v1.0.0`.
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
 - `check({name, version})`: call the `check()` function provided in constructor.
 - `chain(providers)`: chain given `providers` in this provider.
   - `providers`: either another provider, or a list of other providers.
   - chained providers will be called if current provider return 404.


## License

MIT License
