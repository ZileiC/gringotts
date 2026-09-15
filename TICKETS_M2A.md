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
| T-13b | **M2.0 前置波收尾**：全链路实跑（含导出逐字节）/ 全量回归 14/14 脚本 68 帧 / 修复 5 个静默失效脚本 / 工具卫生 / APK / 完工报告 | `0c32108`+`d82fdaf`+`08e9ee4` |
| T-14 | 收口小票：统计页负值语义色 + 导出键改描边 / 帧名与备份名 / 照片孤儿例行化（196 全绿） | `6133d61`+`79eaa74` |

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

## T-13b（收尾 II：全量回归与交付）—— ✅ **已验收通过（2026-09-13，`0c32108`+`d82fdaf`+`08e9ee4`）**，M2.0 前置波就此关闭
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

## T-14（收口小票，P3）—— ✅ **已验收通过（2026-09-14，`6133d61`+`79eaa74`）**；7 个照片孤儿已批准 apply（下一票开工执行）
> 来源：T-13b 完工报告 §4 的偏离项（管理层 2026-09-13 验收逐条裁决：A/B/D/E 修，C 已由管理层订正）。
> 拆成小票的理由：四项都是「1 行级」改动，合并一次跑避免多轮 session 成本。
1. **统计页净结余负值配色对齐 spec（原报告 A）**：`stats_page.dart:138-147` 无颜色分支 ⇒ 负值仍暖白 `ink`；`DESIGN_T09` §8.5 要求负值 `semanticExpense` 大字 → 改为 `color: net < 0 ? AppColors.semanticExpense : AppColors.ink`，补单测（负值红 / 零与正值暖白）
2. **统计页导出键形态对齐 spec（原报告 B）**：现 `FilledButton.tonalIcon`（goldContainer 实心 tonal pill）→ spec 要求 **hairline 金描边 outline 键**（`OutlinedButton` + goldAccent fine 边 + 金字）——按「金色克制」章程：金只作描边/文字，不作大面积填充
3. **证据帧名过时（原报告 D）**：`t09e 02_keyboard_after_splash`（内容 = 启动后主页）、`t09c 01_home_idle`（内容 = 快记页 idle）→ 更名为与实际内容一致，md5 清单同步
4. **工具备份名（原报告 E）**：`clean_dev_db.py` 备份前缀仍 `pre-t09e-<stamp>.bak` → `pre-clean-<stamp>.bak`
5. **照片孤儿例行化**：全量回归/测试会自然产生孤儿（T-13b 回归后管理层 dry-run 实测 **94 文件 / 87 引用 / 7 孤儿 ≈30KB**）→ 约定：全量回归收尾跑 `python tool/photo_gc.py`（dry-run 报数；apply 前确认），WORKLOG 记一行
**验收**：① 两项 spec 对齐有单测断言 + 帧（负值大数字为 `semanticExpense`、导出键为描边式）② 帧名/备份名改后全量回归仍全绿且 md5 记录同步 ③ analyze 零错 + test 全绿（194 + 新增）④ 孤儿清理报数留档

# T-14b（M2 前置修正票，P1：导航语义 + 底栏重设计）

> 用户 2026-09-14 实机反馈两条：① **「记一笔」越权成了三个 tab 共用的第二页面**——它只应是**分析页的第二页面**，资产/统计页不该有它；② **底栏丑**：现在的「记一笔」金渐变实心条 + 三个 tab 需要重新设计。
> Part B 设计稿 = `design/bottom_bar_preview.html`（管理层出，用户拍板后冻结进 `DESIGN_MAIN.md`）。

### 现状与剩余（⚠️ 施工中断后管理层核查，2026-09-14 —— **先读本节**）
- **Part A + Part B 代码已完成且全绿，不要重做**：WIP `14c942e`（Part A）+ `0cc6190`（Part B）**已 push**；管理层实测 `flutter analyze` 零问题、`flutter test` → **All tests passed (207)**（196 → +11）。**严禁重构、严禁重做**
- **唯一失败（管理层已定位到行号与修法）**：`integration_test/t13b_full_chain_test.dart:181` —— 从「明细」返回后断言 `home_record_key` 存在，但返回落点是**统计 tab**（明细是统计页子页），分析页顶栏的入口不在台上 ⇒ **陈旧断言**。改法：① 先断言「已回到壳 + `home_record_key` 不在台上」② `tap(Key('tab_home'))` 后断言 `home_record_key` 在台上 ③ 继续跑完 export 段（CSV BOM + 编辑后商户/金额 + JSON 资产，逐字节）
- **回归现状**：14 个 integration 中 **13 个 exit=0**（日志 `evidence/t14b/regression/*.t14b.log` + `.run_status*.txt`）⇒ **只重跑被修脚本 + 受影响脚本，禁止全量重跑**
- **剩余五项**：① 修上述断言并跑通该脚本 ② 补 `evidence/t14b/` 帧 md5 清单 + 「哪帧证明哪条 §8.5 断言」映射（`visual_checks.txt` 已有像素级校验可作基础）③ WORKLOG 顶部追加执行层条目 ④ `flutter build apk --release` → 桌面 `gringotts-T14b-release.apk` + md5 ⑤ 收工三连
- **已完成勿重复**：照片孤儿 apply（94→87，7 orphan→0，`evidence/t14b/photo_gc_applied.json`）；MiSans subset（`fonts/MiSans-*.ttf` 各 ≈13.8KB + 许可 PDF）

## Part A 导航语义修正（用户指令①，规格已定，不等设计稿即可做）
- **「记一笔」入口归属分析页**：**仅当分析 tab 选中时出现**（入口位置与形态以 `DESIGN_MAIN.md` §8 终稿为准 = **分析页顶栏的圆环＋号键**，P2）；**切到资产/统计时该入口不存在**（底栏仅三 tab，不留空槽、不压栈、不置灰）
- **快记页 = 分析页的子页**：唯一入口是分析页的 CTA；返回必落分析页（保留现有 `_index = 0` 归零作双保险）
- **清理越权路径**：全仓审计「从资产/统计进入快记」的路径与断言——`integration_test/t12c_shell_test.dart` 的 `T12C_ENTRY pushed_from_stats=2 landed=0` 用例须改为「统计 tab **无 CTA**」（键存在性断言）；`test/home_shell_test.dart` 同步
- **底栏高度恒定**：三个 tab 间切换时底栏总高不变（内容区高度可有差，底栏不许跳动）
- 文档（管理层已做）：`DESIGN_MAIN.md` §1 IA 与 `AGENTS.md` UI 结构行已改为「记一笔仅属分析页」

## Part B 底栏与「记一笔」重设计（**规格已冻结**：`DESIGN_MAIN.md` §8 终稿 = **T1 / P2 / D1**）
- **用户拍板（2026-09-14）**：T1（底栏金细线滑动）+ P2（「记一笔」移到**分析页顶栏**）+ D1（圆环键形态）；追加三条：**只要加号、不要文字** / **字体要更好看** / **顶栏按键严格受尺寸约束**。v1 三案已作废，勿复用
- **施工内容**：
  1. **分析页顶栏**改造：右侧新增 `home_record_key` —— 视觉圆 **36**（1.25px `goldAccent` 环 + **矢量描边加号** 16×16 / stroke 1.75 / 圆头线帽；**禁用字体「＋」**）、**触控热区 48×48**；顶栏总高 **56**；宽度校验见 §8.2（320dp 极窄屏不溢出、不挤压月份按钮）；**无文字、无首次引导**；按下环内渐入 `goldContainer`（120ms 一次性；reduce-motion 仅变色）
  2. **底栏**只放三个 tab：图标改**自绘 1.25px 线稿**（分析＝上升折线+终点圆 / 资产＝层叠双框 / 统计＝三根不等高竖线；**源码不得再引用 `Icons.*` 对应件**）；选中＝图标+文字 `goldAccent`、w600、**下方 16×1.5 金线**（切 tab 180ms 位移过渡；reduce-motion → 无位移直接切）；未选中 `inkSecondary` w500；tab 高 56；总高恒定
  3. **字体**：引入项目自带 **MiSans**（官方下载 → subset 到实际用到的字形，预计 +0.6–1.5MB → `pubspec.yaml` 声明 family；**附官方许可说明文件**；若体积/授权异常，备选 HarmonyOS Sans SC 或 Noto Sans SC，**不混用**）；底栏文字 12 / w500·w600 / **字距 +0.08em**；顶栏月份按钮**同步换 MiSans**；Playfair 仍只限品牌时刻（tabs 与按键**不得**用衬线）
- **验收（Part B）**：`DESIGN_MAIN.md` §8.5 七条 —— ① 键存在性（分析有 / 资产·统计无）② 该键无文字节点 ③ 顶栏高恒定 56 + 键 36/热区 ≥48 + **320×640 无溢出** ④ 底栏高度恒定 + 选中金线 key ⑤ 字体断言（tabs 与月份按钮 = MiSans；Playfair 仅在品牌时刻）⑥ 自绘线稿图标 ⑦ analyze 零错 + test 全绿 + Windows 实跑帧

**验收（全票）**：① 分析 tab 有 CTA、资产/统计 tab **无 CTA**（键存在性断言 + 帧）② 底栏高度恒定（尺寸断言）③ 快记页仅从分析页可达（无第二条路径）④ 受影响的 `home_shell_test` / `t12c_shell_test` 断言同步改（删改须说明）⑤ analyze 零错 + test 全绿 ⑥ Windows 实跑帧（Dart PNG + md5 清单入库、PNG 本地）⑦ 收工三连；**本票末出 APK**（`gringotts-T14b-release.apk`，把 T-14 的统计页改动一并入包）

---

# M2.0 正式波（AI 上线）—— 拆票

> **前置（管理层，已做/在做）**：UI 预览稿 `design/ai_wave_preview.html`（配置页 / 主页 AI 位 / 对话窗口，各 2 方向）→ **用户拍板后冻结为 `DESIGN_AI.md`**，再按下方顺序派工。
> **波内铁律（叠加 `AGENTS.md`）**：① **只喂聚合统计 JSON，禁喂原始流水**（隐私 + 成本双保险）② API key 只进 `flutter_secure_storage`，禁硬编码 / 禁进 git / 禁进 log ③ AI 调用必须**可失败可降级**（无 key / 网络失败 / 超时 → 引导态或缓存，绝不留白屏或假数据）④ 每次调用要有**成本闸**（同数据缓存命中则不重复请求）
> **顺序**：T-15 是硬前置（其余全依赖它）；T-16 是本波价值兑现票（优先做）；T-17/T-18 可并行；T-19 独立；T-20 收尾。

| 票 | 内容 | 依赖 | DoD 要点 |
|---|---|---|---|
| **T-15 AI 基座** | BYO 配置页（provider / baseURL / apiKey / model，OpenAI 兼容）+ key 存取 + 客户端 + 「测试连接」+ 设置入口 | 预览稿拍板 | key 不落日志/不进 git（grep 断言）；连接成功/失败/超时三态文案；配置页从任一 tab 可达 |
| **T-16 主页 AI 分析与建议** | AI 位落地：喂**聚合统计 JSON**（本月预算/已花/剩天/top 类别/环比）→ 2–4 条建议；缓存 + 刷新 + 降级 | T-15 | 请求体断言「**无原始流水字段**」；同数据缓存命中不重复请求；失败降级文案；无 key → 引导去配置 |
| T-17 对话窗口 | 随买随问：带当前预算/资产上下文的多轮对话 + 本地历史 | T-15 | 上下文注入断言；历史本地存 + 一键清空；长对话成本提示 |
| T-18 周期报表 AI 解读 | 图表本地出（fl_chart 已有），AI 只写解读文字（日/月/年） | T-15 | 解读与图表**同源**（同一聚合 JSON）；长文可读性（行高/字阶） |
| T-19 预算与周期账单 | 订阅/固定支出登记 + 月度提醒 + 预算系统强化 | — | 固定支出不污染统计口径；派生值仍不落库；通知权限与降级 |
| T-20 Widget + 本地加密 | 桌面小组件（今日可花 / 最近一笔）+ 本地库加密 | T-16 | 加密对既有数据迁移兼容（Vn→Vn+1）；Widget 只读快照 |

**每票通用 DoD**：analyze 零错 + test 全绿 + 本票证据（结构化断言优先，帧按需；帧 md5 清单入库、PNG 本地）+ 受影响 integration 跑通 + 收工三连 + **APK 重建**（T-15 起每票末出包，用户随时可装可测）。

> 原路线图表述（`HANDOFF_MANAGEMENT.md` §6）与本表一致；细节冲突以本表为准。
