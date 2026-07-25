# Task: main 版本的 revalidation 機制

（2026-07-24 從 semver range task 分出來；**2026-07-25 以語意重定義解決，見文末**）

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

## 結論（2026-07-25，與 tkirby 定案並實作）

「main 該自動 revalidate」的前提被推翻：main 的原始語意是**系統/admin 指定版本**
（`@plotdb/block` 的 locked version 概念），凍結才是正確行為——production 的
「落地後不再更新」從 bug 變成 spec。自動追新的需求由 `latest` 承接。實作：

 - `main` / `latest` 語意拆開（原本互為別名）：
   - `latest`：追上游最新（npm dist-tag 慣例），比照 range 走 302、不落地。
   - `main`：symlink 指向精確版本目錄、磁碟直出零 redirect hop。凍結；
     只被 force flush（重新指向上游最新）、`designate`（指定版本）、
     或手動佈署（預裝實體目錄 / dev symlink，registry 不碰）改變。
 - 新增 `provider.designate` + `registry.designate` route factory；
   admin route naming 定為 `/staff/registry/flush/*` 與 `/staff/registry/designate/*`
   （grantdash / makechart 既有 `/staff/flush/assets/lib/*` 掛法不改也能運作，
   force flush main = 自動更新到最新，與現有 Library Cache Flush UI 相容）。
 - cron sweep（方案 1）與 main 改 302（方案 3）皆不需要了。
 - 遺留 nice-to-have（backlog）：outdated report 工具——列出各套件 main
   指向版本 vs 上游最新，供 admin 決定要不要 flush / designate。
