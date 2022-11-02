# @plotdb/registry

`@plotdb/registry` is a definition and tool for how modules are managed. It helps us fetching and managing pacakges and module files.

It provides:

 - an express route for fetching and storing requested module files.
 - a nginx config for accessing requested files based on availability of file.
 - a provider interface for customizing and chaining module providers.


## Usage

`@plotdb/registry` is expected to be used along with expressjs and nginx.

First, include `@plotdb/registry`:

    registry = require("@plotdb/registry")


prepare a provider:

    # our own provider, only fetch modules in @plotdb scope
    myprovider = new registry do
      fetch: ({name, version, path}) ->
        if /@plotdb/.exec(name) => return fetch("/assets/lib/#name/#version/#path").then -> it.text!
        return lderror 404
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

 - `url({ns, name, version, path, type})`: for a given resource, return an URL string pointing to it.
 - `fetch({ns, name, version, path, type})`: for fetching resource object.
   - return value: should always return Promise.
     - if found, return a Promise which resolves with an object with following fields:
       - `version`: exact version of the returned content for the requested resource.
       - `content`: content of the requested resource
     - if not found, return a Promise which rejects with `lderror(404)`.
       - Error other than `lderror(404)` triggers exception.
       - when chained, only `lderror(404)` triggers fetch of chained provider.
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

## License

MIT License
