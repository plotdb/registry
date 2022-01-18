registry =
  jsdelivr:
    url: ({name, version, path}) ->
      "https://cdn.jsdelivr.net/npm/#{name}#{version and "@#version" or ''}#{path and "/#path" or ''}"
    fetch: (o) ->
      fetch @url(o)
        .then (r) ->
          v = r.headers.get(\x-jsd-version)
          r.text!then -> {version: v or version, content: it}

  unpkg:
    url: ({name, version, path}) ->
      "https://unpkg.com/#{name}#{version and "@#version" or ''}#{path and "/#path" or ''}"
    fetch: ({name, version, path}) ->
      fetch @url(o)
        .then (r) ->
          v = (/^https:\/\/unpkg.com\/([^@]+)@([^/]+)\//.exec(r.url) or []).2
          r.text!then -> {version: v or version, content: it}

if module? => module.exports = registry
else if window? => window.registry = registry
