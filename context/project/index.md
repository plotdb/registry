# @plotdb/registry — Project Context

local package cache service：以 nginx + express backend 動態抓取並快取套件
（github / npm），供 servebase 專案（makechart、grantdash 等）的
`/assets/lib/<name>/<version>/<path>` block 資源使用。

## Quick Guide

- 系統機制與功能現況見 `features.md`；架構與 API 細節以 repo `README.md` 為準
  （尤其「Caching Model」章節）。
- 開發：`npm run build`（lsc 編譯 src → dist）、`npm test`（stub-based，無網路需求）。
- 版本語意速記：`x.y.z` immutable 直出；`^`/`~` range 與 `latest` 皆 302 redirect
  解析、不落地；`main` 為 admin 指定版（symlink，凍結）。

## 目錄結構

- `tasks/` — 進行中/待辦 task
- `done/` — 已完成 task（`yyyymmdd-<brief>.md`）
- `logs/` — 工作記錄（`yyyymmdd-<brief>.md`）
- `review/` — 外部 review 記錄（`yyyymmdd/<n>.md`）
