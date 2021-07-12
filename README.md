# @plotdb/registry

`@plotdb/registry` is a definition and tool for how modules are managed. 



## Module Naming

similar to `npm`, with a repo name and optional scope:

 - @scope/repo

for example:

 - wrap-svg-text
 - @plotdb/form

where names contain only [a-z-.] characters, and is case insensitive ( or, all lowercase characters ).


## Module Grouping

Use `.` in module name for semantic grouping:

 - base library: `@plotdb/form`
 - widgets
   - `@plotdb/form.short-answer`
   - `@plotdb/form.long-answer`

These modules ( `@plotdb/form`, `@plotdb/form.short-answer`, `@plotdb/form.long-answer` ) are independent modules and have their own repo and version. Grouping is only for semantic purpose.


## Module Reference

Reference to module is possible with additional information or URL:

 - github:loadingio/ldcover
 - https://plotdb.github.io/form/block/short-answer/0.0.1/index.html

A formal definition of a reference to a module / a module's file can be done by following object:

    {
      name: "module-name",
      version: "0.0.1",
      path: "path/some-file"    /* optional path to file. default `index.html` if omitted. */
                                /* similar to web server rules, `path` may refer to `path/index.html`. */
    }


