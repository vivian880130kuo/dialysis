# 洗腎室交班系統 — 交接文件

整理日期：2026-09-15（Asia/Taipei）。

## 1. 現況

原始檔 `交班系統.html.md` 是純前端、`localStorage` 版本：資料只存在單一瀏覽器裡，換裝置或換人登入都看不到彼此的資料，且該檔案在交接轉檔過程中標點被換成全形／彎引號（例如 `var(–card)`、`’…’`），內嵌 JS 語法已損毀、無法直接執行。

本次已重寫成 `work/index.html`：畫面、班別/病人/事項邏輯與原版相同，但把資料層換成 Supabase（PostgreSQL + Auth + Realtime），讓同單位護理師可以跨裝置共用同一份交班看板。**尚未部署**，因為還沒有這個系統專屬的 Supabase project 與 Netlify site（見第 3 節「還需要什麼」）。

## 2. 架構

- `work/index.html`：完整介面、CSS、業務邏輯、Supabase 用戶端。Vanilla JS，非 React，無需 build。
- `work/netlify.toml`：`publish="."`，純靜態網站，沒有 Netlify Functions。
- `supabase/migrations/0001_dialysis_handoff.sql`：資料表 + RLS + realtime publication，尚未套用到任何 Supabase project。

### 資料模型（與原本 localStorage 結構對應）

- `profiles`：`id`（= auth.users.id）、`display_name`（登入後顯示的護理師姓名，第一次登入時用 `prompt()` 詢問一次並存起來）。
- `dialysis_patients`：`pid`（病歷號，主鍵）、`name`。
- `dialysis_schedule`：某日期某班別排了哪些病人、床號、負責護理師。`unique(date,shift,pid)`。
- `dialysis_sessions`：某病人在某日期某班別的一次交班（床號、護理師），`tasks` 掛在這張表下面。`unique(pid,date,shift)`。
- `dialysis_tasks`：交班事項本身（類別、優先度、完成狀態、備注、誰新增/誰完成）。

### 權限模型（跟個人工時核對系統不同，請注意）

這套系統的本質是「同單位所有人共用同一份病人看板」，不是每人資料互相隔離。目前 RLS 規則是：

- `profiles`：只能讀寫自己的那一列。
- 其餘四張表：**任何已登入（`auth.role() = 'authenticated'`）帳號都能讀寫全部資料**，沒有依角色或單位再細分。

**安全性待辦**：這代表任何能註冊帳號的人都能看到全部病人資料。正式上線前建議至少擇一：

1. 在 Supabase Dashboard → Authentication → Settings 關閉「Allow new users to sign up」，改成由管理者用 Supabase Dashboard 或 Admin API 手動建立帳號（邀請制）。
2. 或加一張白名單表（例如允許的 email / 網域），在 `handle_new_user` trigger 或前端擋掉不符合的註冊。

我沒有自作主張加白名單邏輯，因為不知道貴單位實際帳號規則；請確認後再決定要不要加。

### 即時同步

四張核心表已加進 `supabase_realtime` publication，`work/index.html` 用 `postgres_changes` 訂閱，任何人新增/勾選/刪除事項，其他已登入裝置會在約 0.4 秒 debounce 後自動重新整理畫面（整批重抓，不是增量 patch，資料量小、單位內用途足夠）。

## 3. 還需要什麼才能部署

目前完全沒有為這個系統建立過 Supabase project 或 Netlify site（跟個人工時核對系統是兩個完全獨立的系統，不應共用同一個 project）。需要您提供以下其中一種方式，我才能實際建立/部署：

**Supabase：**
- 方式 A：您在 supabase.com 開一個新 project，把 Project URL、anon/publishable key 給我，我幫您在該 project 的 SQL Editor 貼上 `supabase/migrations/0001_dialysis_handoff.sql` 執行（或您自己執行也可以）。
- 方式 B：給我 Supabase Personal Access Token + 想用的 organization，我用 Supabase CLI/Management API 直接建立新 project 並套用 migration。

**Netlify：**
- 您在 Netlify 開一個新 site（或告訴我要用哪個既有 site 的 UUID），並提供可登入的方式（`netlify-cli login` 或 Personal Access Token）。我再用 `netlify deploy --site <UUID> --dir work --no-build` 部署，正式發布前一定先用 draft/alias 確認過再 `--prod`。

拿到上述資訊後，我會：
1. 把 `work/index.html` 開頭的 `SUPABASE_URL` / `SUPABASE_ANON_KEY` 換成真實值。
2. 套用 SQL migration、確認 RLS 生效（用測試帳號驗證未登入看不到資料、A/B 兩個帳號能互相看到彼此新增的病人與事項）。
3. 部署到 Netlify draft 網址給您確認，確認後才轉正式。

## 4. 尚未做／已知限制

- 沒有角色分級（護理長/護理師/其他單位）與白名單，見上方安全性待辦。
- 刪除事項是直接 DB 刪除，沒有留存歷史紀錄；如需保留稽核軌跡（誰在何時刪了什麼），需要另外加 log 表。
- 沒有離線模式；網路斷線時新增/勾選會失敗並跳出 alert，不會自動重試。
- 排班（`dialysis_schedule`）與交班紀錄（`dialysis_sessions`）的床號/護理師是各自獨立的欄位，目前修改排班時會盡量同步覆寫當日班次的床號/護理師，但不是交易（transaction），理論上有極小機率兩者不一致；資料量小、單位內使用風險可接受，但如需要嚴謹一致性可以改成 Postgres function 用 transaction 包起來。
- 沒有寫自動化測試；本次僅檢查過語法（Node 語法檢查）與程式邏輯比對原始 localStorage 版本，未實際連上 Supabase 跑過（因為還沒有可用的 project）。

## 5. 交給 Claude Code 的提示詞

「請先閱讀 CLAUDE.md 與 SYSTEM_HANDOFF.md，接手洗腎室交班系統。這是同單位共用資料的系統，不是個人資料隔離；修改前請先確認 Supabase project 與 Netlify site 資訊，未經我確認不要正式發布。」
