# @plotdb/registry

`@plotdb/registry` is a definition and tool for how modules are managed. 


## Registry Provider Specification

Registry providers are used to access a requested resource which is defined by its `namespace`, `name`, `version`, `path` and optionally `type`.

A registry provider can be either following format:
 - string: indicate a root path for a requested resource
 - function: return an URL for a requested resource when called
 - object: described below

A registry provider object should contain following fields:

 - `url({ns, name, version, path, type})`: for a given resource, return an URL string pointing to it.
 - `fetch({ns, name, version, path, type})`: return a resource object for given params with following fields:
   - `version`: exact version of the returned content for the requested resource.
   - `content`: content of the requested resource


## Module Naming

similar to `npm`, with a repo name and optional scope:

    `@scope/repo`

for example:

    `wrap-svg-text`
    `@plotdb/form`

where names contain only [a-z-.] characters, and is case insensitive ( or, all lowercase characters ).


## Module Grouping

Use `.` in module name for semantic grouping:

 - base library: `@plotdb/form`
 - widgets
   - `@plotdb/form.short-answer`
   - `@plotdb/form.long-answer`

These modules ( `@plotdb/form`, `@plotdb/form.short-answer`, `@plotdb/form.long-answer` ) are independent modules and have their own repo and version. Grouping is just a semantic suggestion and there won't any checks against it.


## Module Reference

Reference to module is possible with additional information or URL:

 - `github:loadingio/ldcover`
 - `https://plotdb.github.io/form/block/short-answer/0.0.1/index.html`

A formal definition of a reference to a module / a module's file can be done by following object:

    {
      ns: "namespace",
      name: "module-name",
      version: "0.0.1",
      path: "path/some-file"    /* optional path to file. default `index.html` if omitted. */
                                /* similar to web server rules, `path` may refer to `path/index.html`. */
    }


## Registry service

`@plotdb/registry` is also a concept of on demend module provider. It can be implemented with 2 parts:

 - web server which maps URL to file, or fallback to an api server which helps in prepraing the requested module.
 - an api server that prepares request modules


For example, we can setup a nginx server to serve module files as follow:

 - accept requests of module in `https://site/assets/lib/<name>/<version>/<path>`
 - try files `/<rootdir>/static/assets/lib/<name>/<version>/<path>`
 - if file is not found, pass this request to api server.

Then in the api server:

 - fetch the requested files from public registries such as github, npm or other cdn
 - write downloaded files in `/<rootdir>/static/assets/lib/<name>/<version>/<path>` 

It's also possible that the api server uses symlinks for semver rules to speed up assets requests. In this case, registry should properly manage these symlink to reflect the most up-to-date status of modules - for example, provide a trigger which flushes these symlinks by request.

