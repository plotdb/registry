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
 - `cached-period`: how long the nginx proxy cache should last. e.g., `10m`.


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


## License

MIT License
