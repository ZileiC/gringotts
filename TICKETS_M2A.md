# TICKETS_M2A.md — 工单（当前：T-12c 续工 → T-13a → T-13b）

> 规则：一次一票；不得收窄或改写工单语义，缺口记 WORKLOG 等管理层裁决；DoD 通用 = analyze 零错误 + test 全绿 + Windows 实跑证据（Dart PNG + md5 唯一）+ 受影响 integration 通过；**收工三连 WORKLOG → commit → push**。

## 已完成（索引，细节见 WORKLOG_ARCHIVE.md）
| 票 | 内容 | commit |
|---|---|---|
| T-10a | 预算引擎 + `budget_months`(V2→V3) + 边界单测 | `6733f65` |
| T-10b | 新主页 UI + IA 切换（今日饼图 / 固定底栏 / 引导态） | `41ae607` |
| T-11 | 快记页重设计（两输入 / 4×3 含小数点 / 3×3 类别 / 描边确认键） | `17c135f` |
| T-11b | 顶部证据帧 + 额度联动断言 | `25a4b32` |
| T-12 | 明细页（月→日→条目 / 全字段编辑 / 草稿徽章迁主页 / SheenSweep 清理） | `e581909` |
| T-12c | 导航壳（三 tab 平级 + 记一笔压栈）/ 快记即正式 / `updateFields` 移除 / 月历 sheet（**续工后验收通过**） | `cc26215`+`a394df6`+`ce43036` |
| T-13a | 资产净值衬线+金渐变（共享 token）/ 照片孤儿 GC（67→56，11 孤儿 0 误删）/ M1.x 清账 / 月历 342dp 边界修好 | `751509a`+`bf1ae2d`+`f90116f`+`4a943a3` |

---

## T-12c（结构+流程重构，P1，合并票）—— ✅ **已验收通过（2026-09-13，`a394df6`+`ce43036`）**，本节保留为施工记录

> **原票四部分语义不变**，见下方「原票正文」。上一轮执行层已把四部分**全部写完**（工作区未提交），掉线于验收前。管理层已完成源码级 + 实测核查并把 WIP 提交保全为 `cc26215`（已 push）。

### 现状（管理层 2026-09-13 核查，基线 `cc26215`）
**✅ 已完成，勿重做**（`flutter analyze` → 零问题）
- Part A 导航壳 `lib/pages/home_shell.dart`：单 Scaffold + IndexedStack 三 tab（`tab_home`/`tab_assets`/`tab_stats`）+ `home_record_cta` 金渐变主按钮压栈进快记页；`app.dart` 已切 `HomeShell`
- Part B 快记确认写 `isDraft: false`；`lib/pages/review_page.dart` 与 `integration_test/t03_flow_test.dart` 已删；主页徽章/双按钮无残留
- Part C `updateFields` **整方法已移除**（全仓零引用，仅存 `updateTransaction`）
- Part D 主页月历：`home_month_button` + `home_month_sheet`（年份 ‹ › + 3×4 宫格 + 未来月禁用）；左右箭头已移除
- 11 个 integration 脚本（t04/t05/t09a/t09b/t09c/t09c2/t09d/perf_scan/t10b/t11/t12）已完成级联源码适配；t10b 播种已改固定时间戳

**❌ 剩余（本票续工范围，全部要做完）**
1. **`test/home_shell_test.dart` 会挂死整轮 `flutter test`**（单独跑 90s 超时；全量跑时报告器停在 +179 −3 不再退出）：
   - `three peer tabs are siblings` 失败：`find.byType(AssetsPage)` 找不到——IndexedStack 非选中子页为 offstage，finder 需 `skipOffstage: false`（或先 tap 后断言）
   - `记一笔 pushes the speed-entry child and back returns to analysis` 失败：`A Timer is still pending even after the widget tree was disposed`（drift `StreamQueryStore` 未释放）→ 补 `addTearDown` / `close()` / `pumpAndSettle`
2. **`test/home_page_test.dart: month button opens the calendar sheet and switching a month works` 失败**（日志伴随「Looking up a deactivated widget's ancestor is unsafe」）→ 查 sheet pop 后 `setState` 时序 / `pumpAndSettle`
3. **「返回落分析页」语义（管理层裁决，按工单字面实现）**：`_HomeShellState._openQuickEntry` 当前不改 `_index`，从统计/资产 tab 进快记返回后停在原 tab → 改为 push 前 `setState(() => _index = 0)`，并补导航断言
4. **月历禁用断言重建**：原 `home_month_next` 未来箭头断言随 Part D 删除 → 语义须在月历 sheet 上重建（未来月灰显不可点 + 箭头无残余 key）
5. **证据**：受影响 integration 逐个跑通（t10b/t11/t12 属回归，帧落 `evidence/regression/`，不覆盖原票 evidence）；新增 t12c 专属 integration（tab 切换不压栈 / 记一笔压栈 / 月历切换）+ 帧 md5 唯一
6. **`AGENTS.md` 数据铁律订正**：✅ **管理层已于 2026-09-13 按用户授权完成**（draft → 快记即正式 + UI 结构行 + 金渐变例外 + 工作流程新增第 4 条掉线保险），执行层勿重复改。`DESIGN_MAIN.md` §1/§4.1/§5/§7/§8 **同样已由管理层订正完毕，勿重复改**
7. **收工**：release APK 重建（`gringotts-T12c-release.apk`）交付用户；申报「删了哪些测试 / 改了哪些 / 各自结果」与测试数量变化

### 原票正文（Part A–D，语义不变）
- **Part A 导航层级重构**：顶级 = 底部 tab bar 三页平级（`分析`/`资产`/`统计`，切换不压栈，各带独立 key）；「记一笔」= 底栏上方居中主按钮（金渐变实心），点击压栈进快记页（快记页 = 分析页下一级，返回回分析页）；明细页 = 统计页子页（统计页顶部「明细 ›」入口，原分析页底栏 `明细` 按钮删除）；快记页顶栏三入口删除（`quick_review`/`quick_assets`/`quick_stats`）；分析页底栏 `[记一笔][明细]` 双按钮取消
- **Part B 快记即正式（废除草稿链路）**：快记确认直接写正式记录（`is_draft = false`），立即进统计/预算/明细；删除回顾页及其入口、批量补类别（`_applyBulkAndConfirm`）、主页「今日 N 笔待完善」徽章与 `watchTodayDraftCount`、明细页草稿标记分支；保留 `is_draft` 列与统计/预算的草稿排除逻辑（不迁移、不删列）；dev 库残留 live 草稿墓碑清理；`t03_flow_test` 删除、`draft_workflow_test` 草稿用例删除但保留统计口径断言、`widget_test`/`home_page_test` 依赖徽章/草稿的断言同步删改，不留死引用
- **Part C 隐患收口**：`updateFields` 审计——无调用则整方法删除（优于留陷阱），有调用则改 `Value<String?>`（absent=不动 / null=清空）；顺带证据脚本播种改固定时间戳
- **Part D 月份选择**：主页左上月份标题改「月份按钮」→ 弹出月历 sheet（严格照 `DESIGN_MAIN.md` §3 第 1 条：年份 `‹ 2026 ›` + 月份 3×4 宫格、当前月金边选中、未来月灰显禁用、选中即切换、与类别网格同语言、禁渐变投影）；删除右上左右箭头，只留预算设置 ⚙

**验收（全票）**：① 三 tab 平级切换 + 「记一笔」压栈进快记页 + 返回落分析页（导航断言）② 统计页可达明细页 ③ 快记一笔后立即可在明细/统计/主页额度中看到（不再需要确认）④ 回顾页/批量补类别/徽章相关代码与测试全部清除（无死引用）⑤ `updateFields` 无陷阱残留 ⑥ 月份按钮 + 月历弹窗可用、箭头已移除、未来月禁用 ⑦ analyze 零错误 + **test 全绿且整轮退出**（申报数量变化）⑧ Windows 实跑帧（Dart PNG + md5 唯一）⑨ release APK 交付用户

---

## T-13a（收尾 I：资产与存储）—— ✅ **已验收通过（2026-09-13，`751509a`+`bf1ae2d`+`f90116f`+`4a943a3`+`fd14688`）**
> 拆票理由：2026-09-13 掉线事故后按「小票更省、掉线损失更小」原则，把原 T-13 拆成两张；内容与原票语义一致，只是分两轮交付。
1. **资产页字体回归**：净值大数字恢复 **Playfair 衬线 + 金渐变**（`DESIGN_MAIN §6`）；其余数字保持 tabular sans；列表/CPD/天数不变
2. **照片孤儿文件 GC**：`gringotts/photos/` 中无 DB 引用（含墓碑）的 hash 文件清理；**先 dry-run 后 apply**，输出清理前后数量；断言：被引用文件零误删
3. **M1.x 清账**：`t09e` 内注释「keypad home」等过时表述订正（如再触碰）
4. **月历 sheet 横屏/矮窗边界（P3 挂账，来自 T-12c 验收）**：`isScrollControlled` 已修掉默认 9/16 高上限，但按内容 342dp 布局 ⇒ **可用高 < 342dp（真机横屏）仍溢出**；彻底解 = 月历 grid 可滚动或横屏下改用紧凑格高（须保持格高 ≥ 触控 48）；**真机判定权归用户**
**验收**：① 净值大数字字体/渐变与 spec 逐值一致（源码 + 帧）② GC dry-run 与 apply 数量自洽、引用文件保留（单测/脚本断言）③ analyze 零错 + test 全绿 ④ 帧 md5 唯一 ⑤ 横屏 342dp 边界有结论（修好 或 给实测数据 + 建议，不得留空）

## T-13b（收尾 II：全量回归与交付）
1. ~~启动画面 wordmark 去重~~ → **用户 2026-09-13 裁决：不动**（维持现状；徽标内 wordmark + 下方独立 wordmark 的「重复」为有意保留，已锁进 `DESIGN_T09.md` §8 第 6 条）——**本项关闭，无施工内容**
2. **全量回归**：快记 → 立即入账 → 统计 → 资产 → 详情 → 编辑 → 明细 → 导出 全链路实跑（覆盖新导航：三 tab + 记一笔压栈 + 明细从统计页进入）；**回归前先 `python tool/clean_dev_db.py --apply` 清掉 T-04 遗留行**，否则帧不可信
3. **release APK 重建** + `gringotts-T13b-release.apk` 交付
4. **T-13 完工报告**：对照 `DESIGN_T09.md` §8 + `DESIGN_MAIN.md` 逐页核对
5. **工具与测试卫生（T-13a 验收挂账）**：
   - `tool/photo_gc.py`：`--selftest` 在 TEMP 不位于仓库内时崩溃（`REPORT.relative_to(ROOT)` 抛 ValueError，普通 shell 无法独立复验）→ 报告路径安全化；并加 `--report <path>` 参数化（现固定 `evidence/t13a/photo_gc_report.json`，dry-run 会覆盖 apply 报告，本轮靠人工改名规避）
   - `tool/clean_dev_db.py`：报告路径硬编码 `evidence/t09e/...` → 加 `--report`，**禁止覆盖 T-09E 证据**
   - `integration_test/t04_assets_test.dart`：播种后无墓碑清理（源码仅 `addTearDown(container.dispose)`）⇒ 每轮回归把测试资产永久留在 dev 库、后续脚本渲染到同一屏造成**回归帧重复 md5** → 补墓碑 teardown
6. **过时表述收尾**：`lib/ui/splash.dart:9` 注释「the home page IS the keypad, there is no navigation layer」→ 改为 T-12c 后的三 tab 壳（代码注释，执行层范围）；`FEATURES.md` 已由管理层订正，勿重复改
**验收**：① 全链路 integration 通过且前置条件自声明，**回归帧无未解释的重复 md5** ② 完工报告逐页核对无遗漏项 ③ APK md5 交付 ④ analyze 零错 + test 全绿 ⑤ 工具在普通 shell 下可独立跑通（selftest / dry-run 各一次，且报告不覆盖他票证据）

## 后续（M2.0 正式波，待管理层派工）
BYO AI 配置（provider/baseURL/key/model）+ 主页 AI 分析建议 + 对话窗口 + 图表 AI 解读 + 预算与周期账单 + Widget + 本地加密。路线图详情见 `HANDOFF_MANAGEMENT.md` §6。
