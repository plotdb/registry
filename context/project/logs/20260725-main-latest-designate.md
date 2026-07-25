# 工作記錄：main / latest 語意拆分與 designate 機制（v0.0.10）

前情：v0.0.9 的 semver range 支援見 `done/20260724-semver.md`；
本次源自 main revalidation 的討論，完整決策過程見 `done/20260725-main-revalidate.md`。

## 決策摘要

- `main` 的原始語意是「系統/admin 指定版本」（`@plotdb/block` 的 locked version 概念），
  production 下「落地後凍結」不是 bug 而是正確行為；「自動追新」的需求由 `latest` 承接。
- `latest` 是 npm dist-tag 慣例（非 semver 規範的一部分），語意與 npm 對齊。
- admin route naming 定為 `/staff/registry/flush/*` 與 `/staff/registry/designate/*`。

## 實作（registry v0.0.10, commit 17f0417）

- `main` / `latest` 拆開（原互為別名）：
  - `latest`：302 redirect 到上游最新（比照 range），永不落地；
    解析結果 cache 於 `<pkg>/.reg.latest.<provider>`（cachetime TTL）。
  - `main`：symlink 指向精確版本目錄，磁碟直出零 redirect hop。凍結語意——
    一般請求絕不改動；首觸自動 designate 到當下最新（取樣一次，非持續 fallback）；
    只被 force flush（重指向上游最新）或 `designate`（指定版本）repoint。
- 新增 `provider.designate` + `registry.designate` route factory
  （URL `<name>/<version>`，尾端多餘 path 忽略，方便從 flush 欄位貼路徑改 prefix）。
- 保護手動佈署的 main：實體目錄 = 預裝，hands off；手動 symlink（如指向 dev repo）
  只有 force/designate 會換掉，且只換 link 本身、target 永不刪
  （repoint 為 relative symlink + tmp + rename 原子操作）。
- main/latest 不再產生 `.reg.404` 檔（負面結果交由 nginx proxy cache 吸收）。
- dev（無 nginx）的 main 行為與 production 一致：凍結、無 TTL 重抓。

## 驗證

- 單元測試 37 條（stub provider、無網路）：latest 302 與解析 cache、main 首觸/凍結/
  flush 重指向、dev symlink 與預裝保護、designate 各情境（含 400/404）。
- 真 nginx E2E：symlink 直出且 backend 零請求、dev symlink 指向 root 外目錄可服務、
  force flush 收回後 dev 目錄完好。
- 另：README「Caching Model」章節的所有宣稱（四層 cache、cachestamp 作用深度、
  headerless 302、Set-Cookie 影響、`Cache-Control: no-cache` 陷阱）均以
  本地 nginx + instrumented backend 實測 21 條 assertion 驗證。

## 相容性

- grantdash / makechart 既有 `/staff/flush/assets/lib/*` 掛法不改可運作
  （force flush main = 更新到最新，與 Library Cache Flush UI 相容）；
  舊實體 main 目錄在第一次 flush 時自動轉為 symlink。
- 路徑改名 `/staff/registry/*` 與 designate 的 version 輸入 UI 屬 app 端後續工作。

## 後續（backlog）

- outdated report 工具：列出各套件 main 指向版本 vs 上游最新，供 admin 決策。
- grantdash / makechart staff UI：route 改名 + designate version 欄位。
