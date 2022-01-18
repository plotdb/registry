provider =
  jsdelivr: ({name, version, path}) ->
    url = "https://cdn.jsdelivr.net/npm/#{name}#{if version => '@' + version else ''}/#{path or 'dist/index.min.js'}"
    fetch url
      .then (response) ->
        v = response.headers.get(\x-jsd-version)
        response.text!then -> {version: v or version, content: it}

  unpkg: ({name, version, path}) ->
    Promise.resolve!then ->
      url = "https://unpkg.com/#{name}#{if version => '@' + version else ''}/#{path or 'dist/index.min.js'}"
      fetch url
        .then (response) ->
          v = (/^https:\/\/unpkg.com\/([^@]+)@([^/]+)\//.exec(response.url) or []).2
          response.text!then -> {version: v or version, content: it}

rsp = new rescope registry: provider.jsdelivr

rsp.init!
  .then ->
    rsp.load [{name: "ldview", version: "^0.1"}]
      .then -> console.log ">", it
