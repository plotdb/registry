# Features — 目前系統機制

（摘要層級；API 與行為細節以 repo `README.md` 為準）

## 版本語意（v0.0.10 起）

| 語法 | 語意 | 機制 |
|---|---|---|
| `x.y.z` | immutable | 首次由 backend 抓取落地，之後 nginx 磁碟直出 |
| `^x.y.z` / `~x.y.z` | 政策內自動更新 | 302 redirect 至解析出的精確版本，不落地 |
| `latest` | 永遠追上游最新（npm dist-tag 慣例） | 同 range，302、不落地 |
| `main` | admin 指定版（locked） | symlink 指向精確版本目錄，磁碟直出、凍結 |

- `main` 首觸自動 designate 到當下最新（取樣一次）；之後只被 force flush
  （重指向最新）或 designate（指定版本）改變。預裝實體目錄與手動 symlink
  （dev repo）受保護：一般請求不碰，force 也只換 link 不刪 target。
- range/`latest` 的 URL 中 `^` 編碼為 `%5E`；不合法 version/range 回 400。

## Provider Chain

- `provider.fetch / resolve / resolve-latest / designate` 皆沿 chain 依序嘗試，
  404 才輪到下一個（first-match wins）。內建 github（releases）與 npm provider。
- 注意：range/latest 解析以「第一個有滿足版本的 provider」為真相來源——
  套件同時存在 github release 與 npm 時，github 先贏；兩邊發佈需保持同步。

## Cache 層（詳見 README「Caching Model」）

1. browser（含 query string）
2. nginx `proxy_cache`（200/302/400/404，key 含 query string → cachestamp 可破）
3. nginx `try_files` 磁碟直出（不含 query → cachestamp 不可破）
4. backend 內部：`.reg.versions.<pvd>`（range 清單）、`.reg.latest.<pvd>`（latest 解析）、
   `.reg.404`（負面快取，僅精確版本）、皆 mtime + cachetime 過期

刻意設計：302 不帶 cache headers（browser 不 cache、nginx 用 `proxy_cache_valid` 管）；
backend proxy location 必須 `proxy_ignore_headers Set-Cookie` + `proxy_hide_header Set-Cookie`。

## Admin Routes（app 端掛載）

- flush：`/staff/registry/flush/*`（registry.route + `force: true`）——
  精確版本重抓；main 重指向上游最新。
- designate：`/staff/registry/designate/*`（registry.designate）——
  main 指定到特定版本，URL `<name>/<version>`。
- grantdash / makechart 現行舊路徑 `/staff/flush/assets/lib/*` 相容可用。

## 其它

- `registry-ngx`（bin/ngxgen）生成 nginx config 片段；cache 需另設 `proxy_cache_path`。
- 依賴 `@plotdb/semver`（0.0.4+，自有輕量 semver 工具，前後端共用）。
- engines：node >= 18（tar 7 要求）。
