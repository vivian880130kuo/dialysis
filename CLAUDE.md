# Claude Code 專案入口

請先完整閱讀 `SYSTEM_HANDOFF.md`。實際網站原始碼在 `work/index.html`，不是專案根目錄。

- 這是洗腎室交班系統（多位護理師共用同一份病人/排班/交班事項，不是個人資料隔離的系統）。
- 部署到 Netlify 前，`work/index.html` 開頭的 `SUPABASE_URL` / `SUPABASE_ANON_KEY` 必須換成本專案自己的 Supabase project，不要沿用其他系統的 project。
- Supabase schema 在 `supabase/migrations/0001_dialysis_handoff.sql`，套用前請先看過內容，不要盲目 apply 到已有資料的專案。
- 資料庫是全單位共用（RLS 只檢查「有沒有登入」，不分帳號），任何登入帳號都能看到/修改所有病人資料；如需限制只有本單位員工能註冊，記得在 Supabase Auth 設定關閉公開註冊或另外加白名單。
- 舊的 `交班系統.html.md` 是最初交來的原始檔（純前端 localStorage 版本，且文字經轉檔後標點跑掉、無法直接執行），保留當作歷史參考，不要拿它部署。
- 修改後請至少測試：手機寬度、跨裝置即時同步（開兩個分頁登入不同帳號互相新增/勾選事項）、登出後資料不殘留、RLS（未登入應該完全看不到資料）。
