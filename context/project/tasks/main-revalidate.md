# Task: main 版本的 revalidation 機制

（2026-07-24 從 semver range task 分出來，暫不實作）

## 問題

production 部署（如 makechart）的 nginx 以 `try_files` 先查磁碟：

    location ~ ^/assets/lib/(.*)$ {
      try_files /assets/lib/$1 ... @registry_backend;
    }

`main` 目錄一旦被 registry 解開落地（實體目錄，非 symlink），nginx 之後永遠直接出檔，
**backend 完全不會再被打到**，`provider._fetch` 內的 cachetime TTL 檢查形同虛設。
`main` 內容從此凍結，唯一更新途徑是 admin 手動打 force route
（如 makechart `server/backend/makechart/registry.ls` 的 `/staff/flush/assets/lib/*`）。

註：dev 環境（無 nginx、每 request 都進 route）不受影響，TTL 正常運作。

## 方向（與 tkirby 討論 2026-07-24）

revalidate 有必要，但應由 server / admin 側負責，registry 提供工具。候選做法：

1. **CLI / API**：registry 提供指令（或 exported function），掃描 cache root 下所有
   `<name>/main/.reg.version`，對 mtime 超過 TTL 者執行 force fetch。
   server 端用系統 cron 定期呼叫 —— registry 本身不起 timer。
2. **registry 內建 cronjob**：route 初始化時 opt-in 起 interval。侵入性較高，
   且多 instance 部署會重複執行，傾向不採用。
3. **ngx config 改 main 一律回 backend**：main path 不走 try_files 直接出檔，
   由 backend 302 redirect 至精確版本（同 semver range 的做法），
   TTL 交給 `proxy_cache_valid`。行為最正確，但 main URL 多一個 redirect hop。

傾向 1（短期、簡單）；3 可作為長期統一方案（main 語意變成「redirect 到最新版」，
與 range 機制一致，磁碟上不再有 main 目錄）。

## 相關

 - semver range task（`context/project/semver.md`）：range 採 302 redirect、
   不落地目錄，所以 range **沒有**這個問題；本 task 只涉及 `main` / `latest`。
