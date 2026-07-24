# Task: @plotdb/registry semver range 支援

## 背景

makechart（及其它 servebase 專案）的 block 資源統一由 `/assets/lib/<name>/<version>/<path>`
提供，背後是 `@plotdb/registry`（repo: `~/workspace/plotdb/projects/registry`）的
`registry.route`：本地沒有的套件會依 provider chain（github → npm）自動抓取並 cache。

使用端範例：
 - makechart：`~/workspace/makechart/server/backend/makechart/registry.ls`
 - grantdash：`~/workspace/grantdash/v2/backend/grantdash`

目前 version 欄位只支援「精確版本」（如 `1.0.0`）或 `main`（最新）。
**沒有 semver range 的機制** — 不吃 `~1.0.0` / `^1.0.0` 這類語法。

## 需求

1. `@plotdb/registry` 支援 semver range 解析：
   - URL 中的 version segment 允許 range 語法（至少 `~x.y.z` 與 `^x.y.z`；
     URL encoding 需考慮，`^` 在 URL 中是 `%5E`，`~` 不需 encode）
   - resolve 規則：在 provider 可取得的版本清單中，取滿足 range 的**最新**版本
   - 預設策略（產品層期望）：圖表存檔時記精確版本，載入時 auto apply **minor/patch**
     更新（即以 `~x.y` / `^x.y.z` 語意解析；細節見下方開放問題）
2. cache 行為：
   - range resolve 結果需 cache，但要有失效機制（新 minor 版發佈後能被看到；
     可考慮 TTL 或 cachestamp 聯動）
   - 已 resolve 的精確版本內容 cache 不變（immutable）
3. 向後相容：
   - 精確版本與 `main` 的行為完全不變
   - 不合法的 range → 4xx（沿用 lderror 慣例）

## 開放問題（實作前與 tkirby 確認）

 - range 解析發生在哪一層？（registry.route 收到 range → redirect 至精確版本 URL？
   還是直接以 range URL serve 內容？redirect 對瀏覽器 cache 較友善）
 - 版本清單來源：github tags / npm registry metadata？兩個 provider 的清單 API 各是什麼？
 - `main` 與 range 並存的語意：`main` 是否等同 `^latest-major`？
 - auto apply minor 是存 `~x.y.z` 進 db，還是 db 存精確版、由應用層轉成 range 再查詢？

## 週邊脈絡（供參考，非本 task 範圍）

 - makechart 已將 block registry rule 統一為
   `frontend/web/src/pug/modules/block-registry.ls`（editor / viewer / sandbox / backend 共用），
   一律 canonical name（如 `@makechart/treemap`）+ version 預設 `main`
 - 舊的 `assets/block` 手動佈署目錄已更名 `assets/block-legacy` 待刪
 - db 中舊資料的 def 不做遷移，之後一律以 bid（ns, name, version, path）明確定義
