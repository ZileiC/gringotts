# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。
> ⚠️ 并发写入约定：追加前先重新读取文件最新版，在头部插入自己的段落，不要重建文件横幅；管理层 patch 前同样先重读。

## 2026-09-13（**执行层 T-13a 完工**：净值字体回归 + 照片孤儿 GC + M1.x 清账 + 月历 342dp 边界结论）
- **基线/结果**：`5595d4e`（T-12c 验收）→ 本轮 4 个 WIP 提交 `751509a`(P1) / `bf1ae2d`(P2) / `f90116f`(P3) / `4a943a3`(P4+证据)；`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (194)，整轮正常退出**（上轮 186 全绿）
- **① 资产页净值回归（Part 1）**：`lib/ui/tokens.dart` 新增两个唯一来源 `AppFont.brandNumber = 48` + `AppGradient.goldText`（goldAccent→goldDeep，DESIGN_MAIN §7 的两处文字渐变共用**一条**定义）；资产页净值改 `ShaderMask + Playfair 600 / 48 / tabular`；主页 Hero 同步改用同一对 token（**值与渐变逐字不变 ⇒ 主页像素不变**）；列表 / CPD / 天数未动。证据 = `test/brand_number_test.dart` 3 例（token 逐值 `[goldAccent, goldDeep]` + `48`；**主页 Hero 与资产净值 TextStyle 全等**——「逐值一致」的结构化证明；资产页仅 1 处 Playfair 节点）+ 真机帧 `T13A_NET_VALUE font=PlayfairDisplay weight=w600 size=48.0 gradient=goldAccent->goldDeep shader_masks=1`
- **② 照片孤儿 GC（Part 2）**：新增 `tool/photo_gc.py`（**先 dry-run 后 apply**）。判定规则 = ① 直接在 photos 目录内 ② 文件名为内容哈希 `<sha256>.jpg` ③ **无任何 DB 引用**（`asset_photos.path` + `assets.photo_path`，**含墓碑行**）；不满足 ② 的「外来文件」永不删。安全栏逐条断言（不靠假定）：删除集必须与引用集不相交、必在 photos 目录内、**引用集为空即中止**（需 `--allow-empty-references` 才可越过）、**apply 后复查每个原引用文件仍存在**（零误删）。**实测：67 文件 / 56 引用 / 0 外来 / 11 孤儿 → apply 后 56 / 56 / 0 / 0**（删 11 个共 47802 字节，保留 242831 字节；删前已副本到 `.ekko-tmp/t13a_orphan_backup/` 会话备份）。`--selftest` 9 项 PASS（墓碑引用保留 / 外来文件保留 / 删除集∩引用集=∅ / 引用文件存活 / 备份到位）。报告 `evidence/t13a/photo_gc_report.{dry-run,apply}.json` + `photo_gc_selftest.txt`
- **③ M1.x 清账（Part 3）**：`integration_test/t09e_brand_test.dart` 两处「keypad home」表述订正为 T-12c 后的三 tab 壳（**仅注释 / 失败 reason，断言未动**，analyze 覆盖）——关闭 `WORKLOG_ARCHIVE` 挂账的「下次触碰 t09e 时一并订正」
- **④ 月历 342dp 边界（Part 4，T-12c 挂账出账）**：**修好**。`_MonthSheet` 内容固定 342dp（手柄 4 + 年份行 48 + 4×52 格 + 间隙 + padding）；改为 `ConstrainedBox(maxHeight: 视口可用高) + SingleChildScrollView` ⇒ 视口够高时与原来**逐像素一致**，不够时网格滚动、**格高保持 52（≥48 触控线）**、12 个月全部可达。实测（widget 层与真机同值）：800×600 → 342/52/滚动 0；**800×360 横屏 → 342/52/0（仍全显，不白滚）**；640×300 → 300/52/42；360×280 → 280/52/62；真机 681 → 342/52/0；真机 800×300 → 300/52/42。**新发现（行为边界，已按实测分支断言）**：视口 ≤342dp 时 sheet 占满整屏 ⇒ **无遮罩可点**，退出路径 = 选中月份 / 下拉 / 系统返回——不假装遮罩一定存在
- **⑤ 证据**：新增 `integration_test/t13a_assets_sheet_test.dart`（真机：净值字体/渐变断言 + 月历常规 / 矮窗 / 末行可达）→ **All tests passed**，4 帧 md5 `820399573587 / 2afbe48722a3 / c06e46a4c2ba / fd5d410cb6d5`（run 内唯一）；`evidence/t13a/.t13a_frame_md5.txt` 入库、PNG 本地（沿用 `evidence/**/*.png` 忽略规则）。**回归**：t04（资产页像素因 Part 1 变化）/ t10b / t12c **逐个跑通**，日志 + 帧落 `evidence/regression/`（**原票记录未覆盖**），逐帧 delta 与两处 md5 重复已逐条解释（`.T13a_regression_frame_md5.txt` / `.T13a_regression_summary.txt`）
- **⑥ 测试数量申报**：**194 用例**（= 186 + 8：`brand_number_test` 3 + `month_sheet_viewport_test` 5）；**删除 0**；**新增单测文件 2 个**；**修改** = `integration_test/t09e_brand_test.dart`（仅注释/reason）；结果 **194/194 全绿**
- **文档**：除本条目外未改任何 .md；`DESIGN_MAIN.md` / `AGENTS.md` **未触碰**；**本票不含 APK**（T-13b 出包）
- **遗留问题（请管理层裁决/知悉）**
  1. **dev 库脏数据会污染证据帧（本轮新发现）**：`t04_assets_test` 播种「测试相机」后**不做墓碑清理** ⇒ 后续脚本（t12c）会渲染到同一屏 ⇒ 回归集内**两处 md5 重复**（`5480480ccf84` t04 state1 ≡ t10b 01；`8fa0b4ae1011` t04 state4 ≡ t12c 01）。建议全量回归（T-13b）前先 `python tool/clean_dev_db.py --apply` 退掉 dev 行；⚠️ 该脚本 report 路径硬编码 `evidence/t09e/development_db_cleanup.json`，**会覆盖 T-09E 证据**，需先加 `--report` 参数（本轮未改，属范围外）
  2. **另有两处同类过时表述未改**（工单 Literal 范围只到 t09e，缺口照规矩上报）：`lib/ui/splash.dart:9`「**page IS the keypad**, there is no navigation layer」（T-10b 起即失效）、`FEATURES.md:47`「首页『今日 N 笔待完善』角标；当日回顾页批量补全」（草稿链路已废除）；后者是 .md ⇒ 建议由管理层一并订正
  3. 证据帧含 Windows debug 版「DEBUG」角标（既有惯例，release 不显示）；`01/02` 帧跨 run 可复现，`03/04` 含 dev 库背景 ⇒ 只声明 run 内 md5 唯一
- **下一步**：**等验收**（本轮 = `751509a` + `bf1ae2d` + `f90116f` + `4a943a3` + 本条目所在收工 commit）→ T-13b（wordmark 裁决 + 全量回归 + APK + 完工报告）

## 2026-09-13（管理层验收记录：T-12c ✅ 通过 —— 续工完工，186 全绿；含 1 处诊断订正 + 1 项挂账出账）
- **验收基线**：`a394df6`（本轮施工 + 证据 + APK 记录）+ `ce43036`（收工 WORKLOG 条目）；`f26bc0e..ce43036` 已 push，工作区干净（仅证据 PNG 未跟踪 → 见裁决①）
- **五层验收**：
  1. **记录核对** ✓ 双提交存在、hash 与申报一致、已 push；`a394df6` 变更面 = `lib/pages/home_shell.dart`(+4) / `lib/pages/home_page.dart`(+4) / `test/home_shell_test.dart`(+75/-8) / `test/home_page_test.dart`(+35) / 新增 `integration_test/t12c_shell_test.dart`(185) / 证据与记录 8 文件
  2. **独立复验** ✓（管理层亲跑）`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (186)** 且**整轮正常退出**（上轮 179 passed/3 failed + 不退出不复现）——与申报逐位一致
  3. **源码级审查** ✓ ① `home_shell.dart` `_openQuickEntry` push 前 `setState(() => _index = 0)`（管理层裁决落地）② `home_page.dart` 仅 `_MonthSheet` 调用点加 `isScrollControlled: true` ③ 月历逐值对照 `DESIGN_MAIN §3.1`：格高 52 / `AppRadius.m`=12 / 当前月 goldAccent 边+goldContainer 底+goldAccent 字 / 未来月 `inkSecondary.withValues(alpha:0.4)` 且 `onTap: null` / 年份 48 圆钮+未来年禁用 / 把手 40×4 + `overlay` 面 + 顶部圆角 18——逐项符合
  4. **独立 integration** ✓（管理层亲跑 `t12c_shell_test.dart -d windows`，27s）**All tests passed**；前置自声明 `seeded=0 now=2026-9`；**我重生成的 4 帧 md5 与申报逐位相同**（`8e544e66869d / c9330abf629d / 497284de0898 / ab3efb6fd6cd`）⇒ 不仅 run 内唯一，**跨 run / 跨操作者可复现**；15 帧 md5 全局无碰撞（管理层独立 md5 复核：15 值全互异）
  5. **UI 目检 + 数学复核** ✓ 帧 01/03/04 逐项核对（资产 tab 高亮 + 记一笔 CTA 常驻不压栈 / 月历 3×4 + 9 月金边金字 + 10-12 月灰显 + 无裁切 / 历史月按钮「2026 年 1 月」+ 引导态）；**手算复核溢出结论**：sheet 内容 = 8(s)+4(把手)+16(m)+48(年份行)+16(m)+4×52(格)+3×6(categoryGap)+24(l) = **342dp**，600dp 画布 9/16 = **337.5dp** ⇒ 溢出 **4.5px**，与执行层结论逐位吻合
- **✅ 诊断订正（管理层自我纠正，记录在案）**：我在续工 prompt 给的 `home_page_test` 月历失败根因「sheet pop 后 setState 时序」**不成立**；实测真因 = modal 默认高上限 9/16 ⇒ `RenderFlex overflowed by 4.5 pixels`（日志里的 `deactivated widget ancestor` 是 inspector 解释该溢出的二次报错）。**执行层推翻管理层判断且证据成立**（HANDOFF §7 第 4 条：分歧以源码+帧+数值裁决，不以角色服从）——后续票勿沿用旧结论
- **执行层行为肯定**：① 严格区分「产品语义改动」与「测试侧改动」——产品只动 2 处（均为工单字面/裁决），其余全在测试与 1 处布局修复 ② 挂死根因定位到 flutter_test 源码行号（`binding.dart:1960-1963`）+ drift `StreamQueryStore.markAsClosed`，并给出确定性修法（30 分钟挂死 → 2 秒全绿）③ 证据 03 帧保守声明「不跨 run 可复现」（实测可复现，宁少不虚）④ 未经批准不擅改 `.gitignore`，走提问——符合项目纪律
- **⚠️ 申报措辞不符（实质成立，已订正）**：申报称「沉淀为 skill `flutter-test-hang-triage`」——实测**该 skill 不存在**；知识实际落在 `flutter-drift-development/references/test-suite-triage.md`（+ `project-continuity/references/executor-dropout-recovery.md`），内容与本案一致（含 timeout 逐文件 bisect、sqlite3.dll 占用、CPU≈0 判死锁）。**结论：知识沉淀成立、命名不符**，后续申报请写实际路径
- **管理层裁决**：① **证据 PNG 不入 git（口径固定）**：新增 `.gitignore` 规则 `evidence/**/*.png`——帧本体只留本地供目检，入库的永远是 md5 清单 + 运行日志；把此前逐票加 ignore 的写法统一为一条通配，消除 `git status` 噪声 ② **P3 挂账出账**：月历 sheet 在可用高 < 342dp（真机横屏）仍会溢出 → **写入 T-13a 第 4 项**（按项目条款：挂账必须进工单才算数）
- **结论：T-12c ✅ 验收通过**（M2.0 前置波结构票全部关闭）。下一票 **T-13a**（资产字体回归 / 照片孤儿 GC / M1.x 清账 / 月历横屏边界）→ 随后 **T-13b**（wordmark 裁决 + 全量回归 + APK + 完工报告）

## 2026-09-13（**执行层 T-12c 续工完工**：3 失败用例清零 + 返回落分析页 + 月历断言重建 + t12c 证据 + APK）
- **基线/结果**：`cc26215`（管理层 WIP 保全）→ 本轮 WIP 提交 `a394df6`（本地）；`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (186)，整轮正常退出**（上轮：179 passed / 3 failed 且挂死不退出）
- **① 三个失败用例全部清零**（产品语义只按 ②/③ 工单字面改动，其余只改测试与一处布局）
  1. `home_shell_test: three peer tabs…`：`find.byType(AssetsPage/StatsPage)` 缺 `skipOffstage: false`（IndexedStack 非选中子页 offstage）→ 改 finder + 补「选中在台上 / 未选中在台下」双向断言
  2. `home_shell_test` 其余 3 例（含工单点名的「记一笔压栈」）**与整轮挂死同源**：drift `StreamQueryStore.markAsClosed` 在**卸载 StreamBuilder** 时排一个 0ms Timer，而 flutter_test 在 body 之后才卸载 widget 树、且只做一次不带 elapse 的 `pump()`（`flutter_test/src/binding.dart:1960-1963`）⇒ Timer 永不过期 ⇒ `!timersPending` 失败，**失败后每例再挂 10 分钟**（4 例 ≈ 30 分钟 = 管理层观察到的「整轮不退出」）→ 在 body 内显式卸载（`pumpWidget(SizedBox)` + `pumpAndSettle`）冲掉 Timer；**单文件 30 分钟挂死 → 2 秒全绿**
  3. `home_page_test` 月历切换：**原诊断「sheet pop 后 setState 时序」不成立**——真因是 sheet 内容 342dp 超过 modal 默认上限 9/16（600dp 高画布 ⇒ 337.5dp）⇒ `RenderFlex overflowed by 4.5 pixels`；日志里的「deactivated widget ancestor」只是 inspector 解释该溢出时的二次报错（红鲱鱼）→ 改 `showModalBottomSheet(isScrollControlled: true)`（格高 52/radius 12 规格不变）；**窗口高 <337.5dp 或横屏真机同样会中招**，非仅测试画布问题
- **② 「记一笔」返回落分析页（工单字面 + 管理层裁决）**：`_openQuickEntry` push 前 `setState(() => _index = 0)`；补双向导航断言：分析 tab 进→返回 `_index=0`、**统计 tab 进→返回 `_index=0`**；push 期间 shell 处于 offstage 也断言（`skipOffstage: false`）作为「切换不压栈」的对拍基线
- **③ 月历禁用断言重建**（sheet 上重建，不靠实现）：未来月 = `inkSecondary` 40% 灰显 + 点击不关 sheet + 主页月份不动；当月金边金字；历史月 primary ink；`home_month_prev`/`home_month_next` **零残余 key**（sheet 打开态也断言）
- **④ 证据**：新增 `integration_test/t12c_shell_test.dart`（tab 切换不压栈 / 记一笔压栈 / 月历切换 + 历史月只读）；Windows 实跑 **All tests passed**，4 帧 md5 `8e544e66869d / c9330abf629d / 497284de0898 / ab3efb6fd6cd`（与回归 11 帧共 **15 帧全局无碰撞**）；帧因「02 曾与 t11 idle 帧字节相同」重跑 1 次（新事实驱动）并在 02 键入「瑞幸」使其成为本 run 专属。回归 **t10b / t11 / t12 逐个跑通**，帧与日志落 `evidence/regression/`，**原票 md5 记录未覆盖**；回归帧与原记录不同值（T-12c IA 改动 + dev 库行集不同）已逐条对照标注
- **⑤ 测试数量申报**：**186 用例**（静态计数与运行时报数一致 = 上轮 185 + 1）；**删除 0 个测试**；**修改**：`test/home_shell_test.dart` 4→5 例（新增「统计 tab 进快记返回落分析页」）、`test/home_page_test.dart` 6 例不变（月历例内新增灰显/不可点/零残余 key 断言）；结果 **186/186 全绿**
- **⑥ 交付**：`gringotts-T12c-release.apk`（`flutter build apk --release`，62.8MB，md5 `8e508b6b83d138ec8eac9e818c2d8e03`）已复制到桌面；构建日志 + md5 记录见 `evidence/t12c/.t12c_apk_*`
- **文档**：本轮除本 WORKLOG 条目外未改任何 .md；`AGENTS.md` / `DESIGN_MAIN.md` 未触碰（管理层已于 `f26bc0e` 按用户授权订正——本轮开工时该 commit 尚未出现，中途落地，故原文「跳过 AGENTS.md 并记一笔」的挂账**已由管理层自行出账，无需再跳过**）
- **遗留问题（请管理层裁决/知悉）**
  1. **证据 PNG 未入库**：`evidence/t12c/` 4 帧 + `evidence/regression/` 11 帧留在本地供目检，入库的是 md5 记录 + 运行日志（沿用「PNG 不入 git」惯例）；仓库无 `evidence/**/*.png` 忽略规则 ⇒ `git status` 会列出未跟踪 PNG——加 ignore 属策略决定，本轮未擅自改 `.gitignore`
  2. **月历 sheet 高度边界（P3）**：`isScrollControlled` 修掉 9/16 上限后按内容 342dp 布局；真机横屏可用高 < ~342dp 仍会溢出（本票未含；要彻底解需可滚动 grid）
  3. `.t12c_03_month_sheet` 帧含 dev 库背景 ⇒ 只声明「run 内 md5 唯一」，不声明跨 run 可复现（01/02/04 可复现）
- **下一步**：**等验收**（本轮 = `a394df6` + 本条目所在收工 commit）→ T-13a

## 2026-09-13（管理层事故记录：执行层 T-12c 掉线 → WIP 已保全 + 续工票重开 + T-13 拆票）
- 📌 **保全 commit = `cc26215`**（WIP T-12c parts A–D，已 push；**未验收**，不得当作完工）
- **事故**：执行层在 T-12c 施工中途掉线，工作区留下**整票未提交**的施工（24 文件改/删 + 2 新增 `lib/pages/home_shell.dart`、`test/home_shell_test.dart`），零 commit、零 push、无 WORKLOG、无证据、无 APK——本项目最脆弱状态（第 1 条教训翻版：一次误 reset 即全丢）
- **管理层核查（源码级 + 实测，基线 `cc26215`）**：
  1. `flutter analyze` → **No issues found**，四部分源码完整：Part A 导航壳（单 Scaffold + IndexedStack + `home_record_cta` 压栈）；Part B 快记确认 `isDraft: false`、`review_page.dart` 与 `integration_test/t03_flow_test.dart` 已删；Part C `updateFields` 整方法移除（全仓零引用）；Part D 月历 sheet 已实现、左右箭头已移除；11 个 integration 脚本完成级联源码适配（t10b 播种改固定时间戳）
  2. `flutter test` → **179 passed / 3 failed，且整轮不退出（挂死）**；确定性定位（逐文件 90s 上限）：**`test/home_shell_test.dart` 超时挂起**（EXIT=124），其余可疑文件单独跑全绿（quick_entry_defaults / smart_parser / smart_prefill / statistics_service / tombstone / quick_entry_layout）。失败根因已定：Finder 未设 `skipOffstage: false`（IndexedStack 非选中子页 offstage ⇒ `AssetsPage` 找不到）、drift `StreamQueryStore` 流未释放（pending Timer）；另 `test/home_page_test.dart` 月历切换 1 例失败（sheet pop 后 setState 时序）
- **保全动作**：管理层立即 `git add lib test integration_test` → commit `cc26215` → push（工作区随即干净，执行层可无缝续工）；**未改动任何代码**
- **管理层裁决（技术）**：① 原 T-13 拆为 **T-13a**（资产字体回归 + 照片 GC + M1.x 清账）/ **T-13b**（wordmark 裁决 + 全量回归 + APK + 完工报告）——掉线风险下小票更省、损失面更小，原票语义不变仅分两轮 ② 「记一笔」从统计/资产 tab 进入后返回**必须落回分析页**（工单字面：快记页 = 分析页下一级）⇒ push 前 `_index = 0` + 补断言 ③ 月历「未来月禁用」断言随箭头删除而丢失 ⇒ 必须在 sheet 上重建，不得只靠实现
- **管理层文档订正（本轮已做，仅 .md）**：`DESIGN_MAIN.md` §1 IA 升 v3（导航壳 + 三 tab 平级 + 快记即正式）、§4.1 保留清单、§5 草稿标记、§7 金渐变处（新增底栏「记一笔」主按钮，仍 ≤4）、§8 新增 T-12c 验收条目；`TICKETS_M2A.md` 重开为续工票 + 拆 T-13；`SESSION_PROMPTS.md` §B 改续工 prompt；`AGENTS.md` 数据铁律订正（draft → 快记即正式）首次写入被防护栏拦下，**已由用户在当轮「权限全开」授权后落地**（见下条）
- **~~待用户决策~~（已裁决）**：① `AGENTS.md` 该行订正 → 已批准落地 ② 「每完成一个 Part 立即 `WIP T-xx: Part N` 提交」条款 → 已批准并写入 `AGENTS.md` 工作流程第 4 条 ③ T-13b「启动画面 wordmark 去重」→ 用户延后裁决（不阻塞）
- **下一步**：派 T-12c 续工（prompt = `SESSION_PROMPTS.md` §B）→ 验收 → T-13a → T-13b
- **用户裁决（2026-09-13 当轮，三项）**：① **权限全开** → `AGENTS.md` 已按授权订正完毕（数据铁律 draft → 快记即正式；UI 结构行 → 三 tab 平级 IA；补金渐变例外处；**工作流程新增第 4 条「掉线保险」= 每完成一个 Part 立即 `WIP T-xx: Part N` 提交**）② 批准该 WIP 提交条款（已入 `AGENTS.md`，`HANDOFF` §7 第 9 条同步）③ 启动画面 wordmark 去重裁决**延后**（不阻塞 T-12c / T-13a）

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
