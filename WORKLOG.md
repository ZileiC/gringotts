# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。
> ⚠️ 并发写入约定：追加前先重新读取文件最新版，在头部插入自己的段落，不要重建文件横幅；管理层 patch 前同样先重读。

## 2026-09-12（管理层验收记录：T-12 ✅ 通过 —— 附 1 项 P1 缺陷立票 + 1 项口径裁决）
- **五层验收**：
  1. 记录核对：`e581909`（T-12 本体）+ `0e383f8`（hash 记录）双提交，工作区干净、已 push；收工三连完整 ✓
  2. 独立复验：flutter analyze → **No issues found**；flutter test → **All tests passed (184)**（174 +11 ledger +2 home −3 Sheen）
  3. 源码级审查：**`LedgerGrouping` 为纯函数**——`inMonth` / `groupByDay`（按 `occurredAt` 倒序）+ `LedgerDayGroup.netCents`（收入加、支出减）；**时间层级不变量以注释 + 单测锁定**（「筛选后再分组安全：排序键是时间戳，子集保持同日序列与维度」）；`updateTransaction` 文档明示「全字段显式写入，`is_draft`/`source` **故意不动**（草稿改完仍是草稿，转正式仍走回顾页）」✓；`SheenSweep` + `sheen/sheenEdge` token + 3 条单测已删、`MotionChip` 保留并被筛选 chips 消费 ✓；AGENTS.md 里程碑已订正为 M2.0 前置波 ✓
  4. **独立 integration（管理层亲跑）**：`t12_ledger_test.dart` → All tests passed；前置条件自声明（`live_tx=0 / seeded=4 / spent_this_month=2350`）；过滤帧 md5 与申报一致（`e734d790efa4`）；重跑后已 `git checkout` 还原证据
  5. **UI 目检两帧**：列表帧 —— 月份行 `‹ 2026-09 ›` + 全部/支出/收入 chips + **时间倒序日分组**（今天 +¥4984.5 / 昨天 −¥25 / 9月10日 −¥8）+ 条目（类别图标 + 商户/时间 + 金额配色 + 「待完善」草稿徽章；无商户时回落类别名）✓；编辑 sheet —— **金额/类型/类别/商户/备注/日期 2026-09-12/删除/保存** 全字段齐 ✓
- **✅ P1 缺陷实锤（管理层源码级确认，已立 T-12b 必修）**：`updateFields` 无条件写 `Value(merchant)`/`Value(note)`，而 `review_page.dart:54` 只传 `categoryId` ⇒ **回顾页批量补类别会清掉草稿的商户与备注**——用户主流程（快记输「瑞幸」→ 批量补类别 → 商户静默丢失）上的**数据丢失**。执行层本票未改（正确：未越工单范围），已立 T-12b：改 `Value.absent()` 语义区分「不动 / 清空」+ 审计全部调用点 + 回归断言
- **口径裁决（回应执行层提问）**：组头「该日合计」**保留 = 可见行净额（含草稿）**——明细页职责是如实呈现账本，口径唯一化归统计/预算引擎；该语义已**锁定写入 DESIGN_MAIN §5 第 9 条**（后人勿以「不一致」为由改写）
- **顺带（证据纪律，入 T-12b）**：本轮我复跑时列表/编辑帧跨 run md5 有差异，根因 = **证据脚本播种时间戳取自 `now`（now−2h 之类）⇒ 帧内时刻随 run 漂移**；约定证据脚本播种用**固定时间戳**，使帧可跨 run 比对
- **行为肯定**：执行层主动上报「t09c2 泄漏 live 草稿」并修复（基线快照 + `addTearDown` 墓碑，`t09c2_base_motion_test.dart:94-99`），且**主动隔离**了与本节无关的既有缺陷（不改工单外代码）——两项都符合本项目纪律
- **结论：T-12 验收通过 ✅**。下一票 **T-12b（P1 修复）→ T-13（资产字体回归 + 照片孤儿 GC + wordmark 裁决 + M1.x 清账）**

## 2026-09-12（T-12 执行层施工记录：明细页「月→日→条目」+ 全字段编辑 + 草稿徽章迁主页 + SheenSweep 清理）
- 📌 **本票 commit = `e581909`**（已 push；收工三连 WORKLOG → commit → push 完成）
### 做了什么
1. **新增 `lib/pages/ledger_page.dart`（T-12 明细页，DESIGN_MAIN §5）**：
   - **结构铁律**：唯一默认层级 = 时间 `月 → 日 → 条目`。月份行 `‹ 2026-09 ›`（默认当月，未来月箭头禁用，与主页一致）；日期分组**时间倒序**（组内条目亦时间倒序，等时刻按 id 降序确定性打散），组头 eyebrow `今天 · 9月12日` / `昨天 · 9月11日` / `9月12日` 式 + 右侧**该日合计**（tabular）；条目行 = 类别图标 + 商户/备注（空则类别名）+ 金额（**支出 `ink` / 收入 `semanticIncome`**）+ 草稿「待完善」金底徽章。**无任何按类别/金额的分组或排序**。
   - **类型筛选 chips**（`全部/支出/收入`，复用保留件 `MotionChip`）置月份行右侧：**只过滤行，不改变分组维度与顺序**。分组/筛选是 `LedgerGrouping` 纯函数（`inMonth` / `applyFilter` / `groupByDay` / `dayLabel`），不变量可直接单测。
   - 空态 `这个月还没有记录`。
2. **点行 → 全字段编辑 sheet**（`ledger_edit_*` keys）：金额 / 类型（支出·收入 chips）/ 类别（未分类 + 9 类 chips）/ 商户 / 备注 / **日期（`showDatePicker`）**，加 **删除**（`AlertDialog` 二次确认 `ledger_delete_confirm` → 墓碑）。草稿编辑时显示「待完善 · 修改后仍为草稿」，**`is_draft` 不被触碰**（转正式仍只走回顾页批量确认）。
3. **仓库新增 `updateTransaction`**（`repositories.dart`）：全字段显式写入（`null` 即清空商户/备注/类别），保持 `is_draft`/`source` 不变，刷新 `updated_at`。既有 `updateFields`（局部）保留给回顾页，行为未改。
4. **入口打通**：主页 `_openLedger` 由占位 snackbar 改为真实 `push(LedgerPage)`。**草稿徽章迁址**：`_BottomActionBar` 改 `ConsumerWidget`，订阅 `watchTodayDraftCount()`，`>0` 时在「明细」按钮内显示 `今日 N 笔待完善`（key `home_draft_badge`）——旧快记页徽章能力在主页明细入口落地（T-11 验收裁决）。
5. **SheenSweep 死代码清理**：删 `lib/ui/motion.dart` 的 `SheenSweep`/`SheenSweepState`、`tokens.dart` 的 `AppColors.sheen/sheenEdge`、`test/motion_base_test.dart` 的 3 条 Sheen 单测；`integration_test/t09c2` 的 2 处 `find.byType(SheenSweep)` 断言改为注释说明（类已不存在，语义由既有 `confirm gradient == null` 断言承接）。**`MotionChip` 保留**并已被本票筛选 chips 消费。
6. **AGENTS.md 范围纪律订正**：「当前里程碑 = M1.0」→ **M2.0 前置波**（M1.0 已完成，存档 `TICKETS_M1.md`）。
7. **测试**：新增 `test/ledger_test.dart`（11：分组序/筛选子序列不变量/今天昨天标签/跨月过滤 + 页面层级与筛选 + 收支配色与草稿徽章 + 空态 + 真实内存库的全字段写/草稿保持/墓碑 raw 留存/编辑→统计与额度同源联动）；`test/home_page_test.dart` +2（明细入口真实跳转、草稿徽章文案）。
8. **新增 `integration_test/t12_ledger_test.dart`**（Windows 实跑 1 用例，3 帧）：播种 4 行（今日 2 含收入 / 昨日草稿 / 前日支出），收尾全部墓碑；断言层级与组序、筛选子序列不变量、全字段编辑落库、草稿保持、删除墓碑 raw 留存、编辑→额度/统计联动。

### 关键决策
- **「该日合计」= 该日**可见**条目的净额**（收入 − 支出，含草稿，带 `+/-` 号）：页面本就展示草稿与收入行，组头与所见行自洽优先；**注意这与统计/预算口径（草稿、收入排除）不同源**——组头是「当日流水净额」，不是「已花」。若管理层要求组头只算已确认支出，一行改动即可（`LedgerDayGroup.netCents`）。
- **未来月禁用**：与主页月导航一致，避免翻到恒空月份；月份切换保留「切换即换整月数据」。
- **编辑不提供「转正式」**：草稿态由 `updateTransaction` 结构性保证，转正式的唯一入口仍是回顾页（不绕过「先记后补」）。
- **筛选用 MotionChip**：T-11 已裁定保留该件并明确 T-12 筛选 chips 复用之，本票照此消费（不再是死代码）。
- **联动靠同源订阅而非复制算法**：明细页/主页/统计页都订阅同一个 `transactionRepositoryProvider.watchAll()`；编辑只写库，三处各自用既有 `BudgetEngine` / `StatisticsService` 重算——**无第二套算法**（单测直接对同一 list 调 `BudgetEngine.compute` 与 `StatisticsService.totals` 断言双端同步变化）。

### 遗留问题 / 待管理层裁决
1. **`updateFields` 局部更新会清空未传字段（既有缺陷，本票未改）**：`repositories.dart` 的 `updateFields` 对 `merchant`/`note` 用 `Value(null)` 写入，而 `ReviewPage._applyBulkAndConfirm` 只传 `categoryId` → **批量补类别时会连带清掉草稿的商户/备注**。与本票无关但属真实缺陷，建议单独立票（T-13 或新票）；本票只新增互不干扰的 `updateTransaction`。
2. **`t09c2` 曾泄漏 live 草稿（本票已修）**：该脚本点确认会建草稿且从不清理，导致后续 integration 的**主页新徽章**多显示 1 笔（t10b 帧 md5 首次复跑偏离即此因）。已在该脚本加 `captureDraftsForCleanup`（收尾墓碑本测试新建的草稿），复跑后 dev 库 live=0；同时清理了历史遗留的那 1 行草稿（墓碑，非物理删除）。
3. **T-12 证据帧 01/03 跨 run md5 抖动**：`02_filter_income` 两次逐字符相同（`e734d790efa4`），`01_list`/`03_edit_sheet` 两次不同（内容经目检一致）——判断为滚动条/水波纹等覆盖层动画中间态，与 T-09C2/T-11 已裁定的「动画中间态抖动」同类，非内容不一致。
4. 编辑 sheet 的**日期**字段已实现并单测（`occurredAt` 落库断言），但 integration 未驱动原生 `showDatePicker`（避免平台选择器不确定性）；如需帧证据可另派。

### 下一步
- 待管理层验收 T-12；通过后按序 **T-13 资产字体回归 + M1.x 小项**（含照片孤儿 GC、回归帧目录约定、启动 wordmark 待用户裁决），并顺带处理遗留 1。

### DoD 证据
- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed（184）**：174 → +11（ledger）+2（home）−3（SheenSweep 单测随死代码删除）
- **integration `t12_ledger_test.dart` → All tests passed**（Windows 实跑）：`T12_PRECONDITION live_tx=0 seeded=4 spent_this_month=2350`；`T12_EDIT id=… amount=2000 cat=交通 merchant=滴滴 note=打车`；`T12_SNAP 01_list md5=8a80c3dc6eb3 ｜ 02_filter_income md5=e734d790efa4 ｜ 03_edit_sheet md5=de1ab9eddf27`（三帧互异，manifest `evidence/t12/.t12_frame_md5.txt`）
- **层级/筛选不变量**：单测断言 `applyFilter` 后 `groupByDay` 的日序列为未筛选序列的**子序列**（顺序不变、仅成员减少）；integration 断言 `全部/支出/收入` 三态下组头集合与序一致且仅行增删
- **全字段编辑**：单测逐字段（金额/类型/类别/商户/备注/日期）落库 + `is_draft` 保持；integration 落库读回 `amount=2000 categoryId=transport merchant=滴滴 note=打车`
- **删除墓碑语义**：单测 + integration 均读 raw 行 `deleted_at != null`、live 流不再返回、`restore` 可复活
- **编辑→联动**：`spent_this_month` 2350→2800（+450，1550→2000），同一 list 上 `StatisticsService.totals.expenseCents` 同步 +450 —— 两端消费同一编辑结果
- **回归（受本票触碰）**：`t09c2` 2 用例通过（帧落 `evidence/regression/`，原票 evidence 未覆盖）；`t10b` 4 帧 **md5 与已验收值逐字符相同**（1bfa2878d01f / 0ea7d4c5c762 / 07fc568c0a5f / 9d77089fbfa1），证明主页渲染未被徽章改动影响
- **dev 库**：跑后 live=0（t09c2 泄漏草稿已墓碑）；备份 `gringotts.sqlite.pre-t12-<ts>.bak`
- **执行成本如实记录**：integration 共跑 6 次（t12 ×2：① 联动基线误在播种前采样 → 改为播种后读回；② 通过。t09c2 ×2：① 无清理泄漏草稿 → 加墓碑清理；② 通过。t10b ×2：① 受 t09c2 泄漏草稿影响帧含徽章 → 清库后复跑；② 通过）。全部失败由**前提/断言缺陷**驱动，修完即绿，零盲目重跑。

> 📦 更早轮次（T-01 ~ T-12 全部验收与施工记录）已归档至 `WORKLOG_ARCHIVE.md`——追溯历史时再读，日常开工只读本文件顶部两条。
