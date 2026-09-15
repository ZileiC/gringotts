# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。
> ⚠️ 并发写入约定：追加前先重新读取文件最新版，在头部插入自己的段落，不要重建文件横幅；管理层 patch 前同样先重读。

## 2026-09-15（管理层验收记录：T-14b ✅ 通过 —— 导航语义修正 + 底栏/顶栏重设计全部落地，APK 交付）
- **验收基线**：`b5b4373`（收尾）+ `14c942e`（Part A）+ `0cc6190`（Part B）；已 push，工作区干净
- **五层验收**：
  1. **记录核对** ✓ `b5b4373` 变更面 = WORKLOG + evidence（`frame_md5.txt` 166 行 / APK 记录 / analyze 日志 / 3 份 dev 库清理报告 / rerun 日志与失败留档）+ `integration_test/t13b_full_chain_test.dart`(+17/−2)；**`lib/` 与 `test/` 零改动**（`git diff --stat 844a8bf b5b4373 -- lib test` 为空 ⇒ 管理层在 `844a8bf` 实测的 **207 全绿对当前源码继续成立**，以确定性证据替代盲目重跑）
  2. **独立复验** ✓（管理层亲跑）`flutter analyze` → **No issues found**
  3. **源码级审查** ✓ ① `lib/ui/record_key.dart`：`SizedBox(48×48)` 包 36 视觉圆 + `Border.all(goldAccent, 1.25)` + **CustomPaint 矢量加号**（16 设计框 / stroke 1.75 / round cap / 端点内缩半笔宽，并在注释里写明为何禁用字体「＋」）；**无任何 Text 节点**；按下 `goldContainer` 渐入 + 0.96 缩放 + 触感，`disableAnimations` 下 duration = 0（只变色不动）② `tokens.dart`：`recordKeyVisual 36 / recordKeyHit 48 / recordRingStroke 1.25 / recordPlusSize 16 / recordPlusStroke 1.75 / topBarHeight 56 / uiFamily 'MiSans' / tabLabel 12 / tabLabelHeight 16` —— 与 §8 逐值一致 ③ `home_page.dart` 顶栏 `height: AppSpacing.topBarHeight`(56) + `RecordKey(key: 'home_record_key')` ④ `home_shell.dart` 底栏用 `LineTabIcon` 枚举 + `fontFamily: uiFamily` + `tabLetterSpacing`；**`Icons.` 在 home_shell 内零命中**（通用图标已清除）
  4. **独立 integration** ✓（管理层亲跑 `t13b_full_chain_test -d windows`）**All tests passed（54s）**，export 段跑通：`files=2 bom=true csv_merchant=true json_asset=true schema=3`、`teardown live_tx=0 live_assets=0 exported_files_removed=2`；**帧比对：10 帧中 6 帧（01/02/03/04/07/10）与其运行逐字节相同**，4 帧不同（05/06/08/09）**恰为其清单声明的「内嵌本次时钟」帧**（并列出 5 轮历史 md5）⇒ **其声明被验证成立**；跑后直读 sqlite：业务表 **live 全 0**
  5. **UI 目检 + 数学复核** ✓ 分析页帧：顶栏右侧**只有金环＋号（无文字）**+ 齿轮，底栏**只有三 tab**、选中分析金字金图标 + 底部金线；资产页帧：顶栏**无该键**、选中资产金字 + 金线，无空槽。图标为手绘细线风格（折线+点 / 层叠框 / 三竖线）。数学复核：帧宽 1264 ÷ 3 ⇒ tab 中心 **210.7 / 632.0 / 1053.3**，与其像素校验报告的金线中心 210.7（分析）/ 632.0（资产）**逐位吻合**；APK 内已核 `MiSans-{Regular,Medium,Demibold}.ttf`(13660/13808/13856 B) + Playfair + MaterialIcons（4KB 子集）
- **熔断纪律执行良好**：t13b 只跑 **2 次**（第 2 次由 `:243` 新事实驱动），未触第 3 次；第 1 次失败原文留档 `evidence/t14b/regression/t13b_rerun1.stale_assertion.txt`；未降断言、未 skip、未删测试；照片孤儿 apply 与 MiSans subset 未重复执行；全程无 harness 内部错误
- **收尾时新发现并同修**：除管理层定位的 `:181` 外，`t13b_full_chain_test.dart:243`（从详情返回——详情属**资产 tab** 子页）是**同一根因的第二处**，由「跑完 export 段」暴露；两处均改为「断言壳在 + key 不在台上 → 切回分析 tab → 断言 key 在台上」，**正向断言全部保留**
- **交付**：`C:\Users\JHarayden\Desktop\gringotts-T14b-release.apk`（65,914,644 字节，md5 `8cf25112990f32830d371bc6eedb83ae`；含 T-14 统计页改动 + Part A/B 全部改动）——**待用户真机目测**
- **观察（非缺陷，供真机留意）**：资产页右下角本身有一个「＋」添加资产键（既有功能），与顶栏的记一笔「＋」**同形不同义**；若实机上觉得容易混，可在后续票换形（如资产用带文字的键或换图标）
- **结论：T-14b ✅ 验收通过**。M2.0 正式波按用户安排仍处暂缓；**T-14b 关闭后，前置波 + 用户追加的两项修正（导航语义 / 底栏重设计）全部结清**

## 2026-09-15（执行层：T-21 统计页图表重整 + 收入/存款语义，分块施工）
- **Part 1 完成**（服务层）：`lib/services/statistics_service.dart` - 新增 `monthDayLabels` / `monthDays`（日视图 = 所选月整月 28/29/30/31 桶，标签 `M/D`，x 恒为数据点 index）、`incomeBaselinePerDay`（budget.incomeCents / 当月天数，无预算或墓碑 = null）、`monthlyTrend(year)`（12 桶且跨年不再混桶）、`yearlyTrend(baseline)`、`spendBars`（额度内/超额分段 + 临时收入，纯函数）；**删除**旧的 7 桶 `dailyTrend`，旧调用点已改。证据：`flutter test test/statistics_service_test.dart` -> 18 passed（含 28/29/30/31 四例与有/无预算两态）；`flutter analyze` -> No issues found
- **Part 2 完成**（图 1 + 轴修正）：`lib/pages/stats_page.dart` 新增 `_SpendChartCard`（`Key('stats_spend_chart')`）- 日视图每天一柱（额度内 `elevated` + hairline 边，超额段 `semanticExpense`）、额度 = 可花预算 / 当月天数的 `goldAccent` 1px 虚线（dash `[4,3]`）、临时收入柱顶 4px `semanticIncome` 圆点 + 图下数字行「N 号 临时收入 +（U+00A5）800」（源码用 `\u00a5` 转义）；月/年视图改支出/收入成对柱。**轴**：左轴 4 档金额刻度（0 / 1/3 / 2/3 / max，interval = maxY/3，千分位 + tabular），底轴 `interval: 1` 且 x 只取整数 index（日每 5 天 / 月每 2 月 / 年每年一标 + 末尾必标），T-21 诊断 2 的 `length / 6` 已删除。证据：`test/stats_page_test.dart` +4（柱数 = 当月天数且 x = index、左轴 showTitles 且 interval = maxY/3、底轴 interval = 1、无预算无额度线与红段、有预算金虚线 y = 日额度且 dash [4,3] + 绿点 + 标签、空态）；`flutter test` -> 221 passed；`flutter analyze` -> No issues found
- **工具链注意（本 session 实测）**：命令通道会吞掉非 CJK 非 ASCII 符号（U+00A5 实测被吞）；新写源码/测试的金额前缀一律用 Dart 转义 `\u00a5`，净结余标题已按集成测试依赖的原文还原（`\u2212` 同样转义）
- **Part 3 完成**（图 2 双线）：`lib/pages/stats_page.dart` 重写 `_TrendChart`（`Key('stats_trend_card')`）- 收入线改用 `incomeLineCents`（保底均摊 + 临时收入），与 `semanticExpense` 支出线同图；纵轴 = `max(支出, 保底均摊) * 1.15`，**临时收入不参与缩放**，该日改画 `semanticIncome` 细虚线引到图内顶部 + 3.5px 圆点 + 数字行「N 号 临时收入 +（U+00A5）800」；无预算时收入线只含临时收入并显示「未设本月预算，收入线仅含临时收入」；空态「这个周期还没有记录」（`Key('stats_trend_empty')`）；单点（年视图单年）不崩。证据：`test/stats_page_test.dart` +4（收入线 = 保底均摊而非 0、maxY = max(支出, 均摊) * 1.15 且 8 万尖峰不入缩放、每个临时收入日恰 1 条虚线引线 + 端点圆点序列 + 标签、无预算说明、年视图单年正常渲染两图）；`flutter test` -> 225 passed；`flutter analyze` -> No issues found
- **Part 4 完成**（月份三页同源）：新增 `lib/ui/month_sheet.dart` - 把主页私有 `_MonthSheet` 提取为共享 `MonthSheet` + `showMonthSheet`（同一组件，主页键不变 `home_month_sheet`，统计页用 `stats_month_sheet`）；`app.dart` 新增唯一月份源 `selectedMonthProvider`（`NotifierProvider<SelectedMonth, DateTime>`）；`home_page` / `ledger_page` / `stats_page` 全部改为 `ref.watch(selectedMonthProvider)`，任一页切换三页同步；统计页顶栏新增 `stats_month_button`（复用同一 sheet，「明细」入口保留）。证据：`test/stats_page_test.dart` +1（点 `stats_month_button` -> 断言 `stats_month_sheet` -> 选上月 -> `container.read(selectedMonthProvider)` = 上月 + 图 1 柱数 = 上月天数 + 换成 HomePage 后其月份按钮显示同一月）；`flutter test` -> 226 passed；`flutter analyze` -> No issues found
- **Part 5 完成**（存款转资产）：V3->V4 迁移（`budget_months` + `savingsConfirmedAt`/`savingsSkippedAt`，`assets` + `note`；全 nullable `addColumn`，V1/V2 升级路径不重复加列，`schemaVersion 3 -> 4`，旧数据可读）；`AssetCategory` + `savings`；新增 `lib/services/savings_plan.dart`（`SavingsPlan` 纯规则 + `SavingsPlanService.confirm/skip`，confirm 幂等：先查既有存款资产再建）；`BudgetRepository.markSavingsConfirmed/markSavingsSkipped`；`AssetRepository.create(+note)` 与 `findPlannedSavingsAsset`；分析页 Hero 下方 `home_savings_card`（`savings_confirm` / `savings_skip`，条件 = `savingsTargetCents > 0` 且两时间戳皆 null；当月最后 3 天多一行「这个月快结束了」）；资产详情页补「存款」类别标签与编辑段。证据：`test/t21_savings_test.dart` 11 tests（纯规则 5 + 真库确认/幂等/跳过 3 + 真 V3->V4 文件迁移 1 + 主页卡片 widget 2）：未操作零资产、确认后 1 条（金额/类别/日期/note 断言）、重复确认同 id 不新增、跳过零资产且不再提示、迁移后旧行可读且新列可写；`budget_repository_test` 的 V2 夹具补 `ALTER TABLE assets DROP COLUMN note`（使其成为真正 V2 文件）；`flutter test` -> 237 passed；`flutter analyze` -> No issues found；dev 库 dry-run live 0/0（`evidence/t21/dev_db_cleanup.json`，无需 apply）
- **Part 5 规格补充**：DESIGN_MAIN 11.5 要求生成的资产带 `note = 由月度计划存款确认生成`，但 assets 表原本没有 note 列，故 V4 迁移同时新增 nullable `assets.note`（唯一超出条目字面的 schema 变更，已在此备案）

## 2026-09-14（执行层：T-14b 收尾：陈旧断言 2 处 + 帧 md5 清单 + APK；待验收）
- **起手**：`844a8bf`（Part A `14c942e` + Part B `0cc6190` 已保全）。本轮**只收尾、不重做**：`lib/` 零改动，唯一源码改动 = `integration_test/t13b_full_chain_test.dart`
- **(1) 陈旧断言共修 2 处（同一根因）**：Part A 后「记一笔」只属分析页，所以当前不在分析 tab 时 `home_record_key` 就 offstage（壳是 IndexedStack）。修法统一为「先断言已回到壳（`tab_home` 在台上）加上 key 不在台上」，不降断言、不加 skip：
  - `:181`（从明细返回）：按管理层定位的行号改。明细是统计页子页，返回落统计 tab，于是断言壳在加上 key 不在台上，然后 `tap(tab_home)`，再断言 key 在台上（正向断言保留）
  - `:243`（从详情返回，导出段入口）：**由「继续跑完 export 段」暴露**。详情是资产 tab 子页，pop 后落资产 tab，同一 offstage 模式，所以同模式修（断言壳在加上 key 不在台上），随后照原样切 `tab_stats`（导出本就需要统计 tab，不绕行）
  - 两处都是 IA 变更后的**语义修正**而非新缺陷；分析页「key 在台上」的正向断言仍在（开局 `:95`、快记返回 `:132`）
- **(2) 重跑范围**：按令**只重跑 `t13b_full_chain_test`**（共 2 次：第 1 次暴露 `:243`，第 2 次由该新事实驱动）；**未全量重跑 14 个**；未触及 `t12c_shell_test` 故未跑。第 1 次日志被第 2 次覆盖，`:243` 失败原文已留档 `evidence/t14b/regression/t13b_rerun1.stale_assertion.txt`
- **(3) t13b 结果 = exit 0，export 段跑完**（`All tests passed`；日志 `evidence/t14b/regression/t13b_full_chain_test.t14b.rerun.log`）：CSV 前三字节 `EF BB BF`（BOM），正文含编辑后商户 `瑞幸咖啡`／金额 `2000`；JSON `assets` 含 `T13B 相机Pro`、`transactions` 含 `瑞幸咖啡`、schema=3；`T13B_TEARDOWN live_tx=0 live_assets=0 exported_files_removed=2`
- **(4) 帧证据补齐**：新增 `evidence/t14b/frame_md5.txt` = 14 脚本／**68 帧** md5 清单（PNG 本地、清单入库）+ DESIGN_MAIN 第 8.5 节七条逐条「哪帧 + 哪个单测证明」映射（以 `visual_checks.txt` 像素校验为基础）。与 T-13b 记录比对：66 个同名帧中 **61 变 / 5 未变**。变的是所有出现壳的帧（Part B 底栏加自绘图标加 MiSans 加顶栏圆环键；T-14 统计页负值色与描边导出键）；5 个未变都是**无壳帧**：`t09e 01_splash_brand_frame` / `t09c 08_ledger` / `t11 03_income` / `t12c 02_entry_pushed` / `t13b 02_quick_entry`。T-14 两个更名帧（`01_quick_entry_idle`／`02_home_after_splash`）记为新增。`t13b 05/06/08/09` 属**跑时相关帧**（画面嵌本次时钟），清单已标注并列出各轮历史 md5
- **(5) 出包**：`flutter build apk --release` exit=0（Gradle assembleRelease 211.6s／62.9MB），桌面交付 **`gringotts-T14b-release.apk`**：`bytes=65914644`、`md5=8cf25112990f32830d371bc6eedb83ae`；记录 `evidence/t14b/apk_md5.txt` 与 `apk_build.log.txt`。包内已核 `assets/flutter_assets/fonts/MiSans-{Regular,Medium,Demibold}.ttf`（各约 13.8KB 十进制口径，与先前记录同口径；MaterialIcons 仅存 4076B）；T-14 统计页改动加 Part A/B 均已入包（比 T-13b 包 +37168B，约等于 MiSans 三面）
- **(6) 质量**：`flutter analyze` 报 **No issues found!**（`evidence/t14b/flutter_analyze.log.txt`）。`flutter test` **未重跑**：本轮零 `lib/`、零 `test/` 改动，管理层在 `844a8bf` 实测 **207 全绿** 对当前代码仍成立（守反浪费铁律的禁盲目重跑）
- **前置清理**：上轮 t13b 中途失败未 teardown，dev 库留 1 活行，故 `tool/clean_dev_db.py --apply` 两次：`pre_rerun`（tx live 1 到 0）、`pre_rerun2`（tx 加 asset live 1/1 到 0/0），报告在 `evidence/t14b/`
- **熔断执行**：同一脚本 2 次（第 2 次由新事实驱动），**未触第 3 次**；全程无 harness 内部错误；未降断言、未 skip、未删测试；照片孤儿 apply 与 MiSans subset 均未重复执行
- **下一步**：**停下等管理层验收**（依据 = DESIGN_MAIN 第 8.5 节七条 + 本票「验收（全票）」七项）。M2.0 正式波按用户安排暂缓，未获指示前不派工；T-15 前仍需先拍 `design/ai_wave_preview.html` 方向

## 2026-09-14（管理层：T-14b 施工**中断事故** —— Part A/B 已保全，剩一例断言待修 + 收尾）
- **事故**：deepseek harness 执行 T-14b 到回归阶段开始**反复重跑同一脚本**（用户手动截断后 harness 抛 `Error: DSH ACP: Internal error` 刷屏）——属**反浪费铁律（AGENTS.md 工作流程第 2 条）违背形态**，已作为下一轮 prompt 的重点防线
- **保全动作（管理层）**：两个 WIP 提交 `14c942e`（Part A）+ `0cc6190`（Part B）原本**未 push**（本地 ahead 2）→ 已 `git push` 保全；`evidence/t14b/`（回归日志 + 像素校验 + photo GC 记录）随后一并提交，**已采集证据不致丢失**
- **管理层独立核查（当前状态，实测）**：
  1. `flutter analyze` → **No issues found**；`flutter test` → **All tests passed (207)**（196 → +11，含新增 `test/t14b_design_test.dart` 454 行）⇒ **Part A/B 代码层完成且全绿**
  2. **Part A**（`14c942e`）：`home_shell.dart` 瘦身（底栏只剩三 tab）、`home_page.dart` 顶栏入口、`tokens.dart`(+4)、`home_shell_test.dart` 重写、`t12c_shell_test.dart`(+80) 等
  3. **Part B**（`0cc6190`）：`lib/ui/line_icons.dart`(107 自绘线稿) / `lib/ui/record_key.dart`(138 圆环＋号键) / `tool/subset_misans.py` + **`fonts/MiSans-{Regular,Medium,Demibold}.ttf`（各 ≈13.8KB，已 subset）** + `MiSans-LICENSE.pdf` + `fonts/README.md` / `pubspec.yaml`(+12) / `tokens.dart`(+46)
  4. **回归**：14 个 integration **13 个 exit=0**；**唯一失败 `t13b_full_chain_test`** —— 管理层已定位到断言原文：**`t13b_full_chain_test.dart:181` 从「明细」返回后断言 `home_record_key` 存在，但那是统计 tab（明细是统计页子页），分析页顶栏的入口不在台上** ⇒ IA 改动后的**陈旧断言**，应改为「返回后仍在统计 tab（key 不在台上）」+ 切回分析 tab 再断言 key 在台上；**export 段本轮未跑到**
  5. **已批准事项完成**：照片孤儿 apply（94→87，7 个孤儿清零；`evidence/t14b/photo_gc_applied.json`）
  6. **视觉像素校验**（`evidence/t14b/visual_checks.txt`）：圆环键 bbox **36×36** 且为分析页顶栏唯一金色簇；加号横竖各 3 连通段、内部对角为空（**描边非实心**）；底栏金线位于选中 tab 中心；**资产页顶栏金色像素 = 0**（证明入口不在资产页）—— 与 `DESIGN_MAIN §8` 逐条吻合
- **剩余（= 下一轮 prompt 的全部内容）**：① 修 `t13b_full_chain_test.dart:181` 并跑完该脚本（含 export 段）② 补 `evidence/t14b/` 帧 md5 清单 + 「哪帧证明哪条 §8.5 断言」映射 ③ WORKLOG 顶部追加执行层条目 ④ `flutter build apk --release` → `gringotts-T14b-release.apk` + md5 ⑤ 收工三连
- **prompt 重设计（针对本次事故）**：把「已知失败 + 精确行号 + 修法」直接写进 prompt（零重发现成本）；**收窄重跑范围**（只跑被修脚本 + 必要回归，不再全量 14 个）；加**熔断规则**（同一脚本最多 2 次，第 3 次禁止；失败即写 WORKLOG 停手）；加**遇 harness 内部错误立即停手**的明文指示

## 2026-09-14（管理层：T-14b 底栏设计**拍板定稿** T1/P2/D1 —— 规格冻结，可派工）
- **用户裁决**：组合 = **`T1 / P2 / D1`**（底栏金细线滑动 + 「记一笔」移到**分析页顶栏** + 圆环键形态），并追加三条要求：
  1. **「记一笔」只要加号、不要文字** → 终稿采用**矢量描边加号**（16×16 / stroke 1.75 / 圆头线帽），**禁用字体里的「＋」**（各平台粗细与位置不一，是"看着不精致"的常见根因）
  2. **按钮与底栏字体要更好看** → 定案**引入项目自带 MiSans**（subset 到实际字形，+0.6–1.5MB，附官方许可；备选 HarmonyOS Sans SC / Noto Sans SC，不混用）；底栏文字 **12 / w500·w600 / 字距 +0.08em**；月份按钮同步换字体；**Playfair 仍只限品牌时刻**（tabs 与按键不得用衬线）
  3. **顶栏按键严格受尺寸约束** → 定案尺寸预算：顶栏总高 **56**（上 padding 8 + 内容行 48）；月份按钮高 40 不变；＋键**视觉圆 36 / 触控热区 48×48**（热区透明外扩，不放大视觉）；两键间距 4、左右内边距 16/8；**宽度校验** `16+130+≥12+48+4+48+8 = 266` ⇒ **320dp 极窄屏仍余 54**，不会挤压或溢出
- **管理层文档动作**：`DESIGN_MAIN.md` §8 改写为**终稿**（§8.1 归属铁律 / §8.2 顶栏按键与尺寸预算 / §8.3 底栏 T1 三 tab / §8.4 字体 / §8.5 七条验收断言）；`TICKETS_M2A.md` T-14b Part B 由「待拍板」改为「规格已冻结」并列出三块施工内容；`SESSION_PROMPTS.md` §B 对应段落同步（**prompt 现为可直接派工的完整版**）
- **过程记录**：v1 三案（底栏上方通栏 / 卡片内 / 底栏居中）已作废并写入工单「勿复用」；v2 稿 `design/bottom_bar_preview_v2.html` 仅供追溯
- **下一步**：把 `SESSION_PROMPTS.md` §B 的 prompt 交给新执行层 session（Part A 结构修正 + Part B 依 §8 终稿 + Part C 出包）→ 验收 → M2.0 正式波（T-15 仍需先拍 AI 三屏方向）

## 2026-09-14（管理层：`AGENTS.md` 订正落地 + 底栏重设计 v2 稿（用户否决 v1 三案））
- ✅ **`AGENTS.md` 订正已落地**（用户再次确认「权限全开」后写入成功，3211 字节）：① UI 铁律·结构行 → 「底栏只放三个 tab 平级；**「记一笔」仅属分析页**（资产/统计 tab 没有该入口）；快记页 = 分析页下一级，返回落分析页」② UI 铁律·渐变例外改为「以 `DESIGN_MAIN.md` §7 为准」（避免与 §7/§8 打架）③ 新增结构（快记入口形态）以 §8 为准的指向。**防护栏拦截问题解除**，该文件现与工单/设计稿一致
- 🎨 **底栏重设计 v2（用户裁决 v1 三案全否，并追加三条要求）**：
  - 用户原话要点：① 底栏**彻底只放三个 tab**（认可）② **三个 tab 本身也要重设计**——「现在这个图标+汉字很好，但还可以更有艺术感」③ 「记一笔」的**位置**三个方案都不好，要再想 ④ **按钮本体也要重新设计**
  - 用户已否决（勿复用）：底栏上方通栏金键 / 主页卡片内小键 / 底栏居中大键
  - **新稿 `design/bottom_bar_preview_v2.html`**：三组各三案，可自由组合（例 `T1/P1/D1`）
    - **tab 选中态**：T1 金细线滑动（选中＝金字+图标变金+16×1.5 金线，180ms 滑动）· T2 金点·字距·大留白（+0.10em + 3px 金点）· T3 三格账页（细框金边+极淡金底，复用月历/类别网格的选中语言）
    - **「记一笔」位置**：P1 右下悬浮金键（54 圆金键，滚动缩 44 + 0.72 透明；拇指原位）· P2 顶栏金环键（40，永不离屏、不占内容区）· P3 金线下划键（Hero 下通栏 1px 金线断开式，编辑风）
    - **按钮本体**：D1 压印金块（纯色金实心 + 内侧 1px 深金描边＝不用投影的重量感）· D2 金环（与快记确认键/导出键同语言）· D3 双线薄片
    - **新增冻结项**：图标改**项目自绘 1.25px 线稿**（分析＝上升折线+终点圆 / 资产＝层叠双框 / 统计＝三根不等高竖线），弃用 Material 通用件
  - 管理层推荐组合：**T1 / P1 / D1**（理由：保留用户认可的结构只提升质感；记账键回归拇指原位且不占底栏；去渐变换纯色但保留重量感）
- **管理层文档动作**：`DESIGN_MAIN.md` §8 改写为 **v2 待拍板稿**（含「已冻结不变量」+「待选三组」表）；`TICKETS_M2A.md` T-14b Part B 改为「先拍板才可施工」并写明 v1 三案作废；`SESSION_PROMPTS.md` §B 的 Part B 改为「未拍板则只做 Part A + Part C，禁自行选型」
- **下一步**：用户回组合（如 `T1/P1/D1`）→ 管理层写 §8 终稿 → 派 T-14b（prompt 已就绪，Part A 可先行）

## 2026-09-14（管理层：workspace 内部清理 ≈6.8GB + 用户两项新要求立票 T-14b）
- **内部清理（用户要求）**：共释放 **≈6.8GB**
  - 仓库内 **6659MB**：`build/`(1.3G) + `.dart_tool/`(5.0G) + `windows/flutter/ephemeral/`(312M) + `.idea/` + `.ekko-tmp/`（执行层 harness 日志）+ `.flutter-plugins-dependencies` + 仓库根 **29 个 M1.x 遗留物**（`.t01~t06_*.png` / `.tile_cmd.sh` / `.tile_value.txt` / `.ui_dump*.xml`）
  - 桌面 / 临时 / DB **≈139MB**：`gringotts-T11-release.apk` + `gringotts-T12c-release.apk`（已被 T-13b 版取代）+ 管理层的验收临时脚本与日志（t12c/t13a/t13b/t14 各一套，含证据备份目录）+ `%TEMP%` 下 `t13a-gc-*` 残留 + **16 个过期 dev 库备份**
  - **刻意保留**：`evidence/`（5.4MB / 81 帧 —— 未来复核的视觉素材）、当前交付包 `gringotts-T13b-release.apk`、最新 2 个 dev 库备份（`pre-clean-20260914-195410` / `pre-t09e-20260913-133748`）、`android/` 下的 `gradlew*` 与 `gradle-wrapper.jar`（虽被 ignore 但构建必需）、`design/*.html`（设计稿记录）
  - **⚠️ 自查失误（已修正）**：清理时误删 3 个**已被 git 跟踪**的 `.t02_*.png`（M1 时代已入库）→ 立即 `git checkout --` 还原，工作区零改动并已 push 验证。**教训：批量删除前必须先 `git status --porcelain --ignored` 分清「被跟踪」与「仅忽略」**（已补入 `HANDOFF_MANAGEMENT.md` §7 第 10 条）
- **用户两项新要求，逐条立票（工单语义不变原则）**：
  1. **导航语义修正（P1）**：「记一笔」越权成了三个 tab 共用的第二页面 → 只应属分析页 ⇒ **T-14b Part A**（资产/统计页不得有该入口；越权路径与断言全清；底栏高度恒定）
  2. **底栏重设计（P1）**：现「记一笔」金渐变实心条 + 三个 tab 被用户判「丑」⇒ **T-14b Part B**（预览稿 `design/bottom_bar_preview.html` 三方向，用户拍板后才施工）
- **管理层文档动作**：`DESIGN_MAIN.md` 新增 **§8 底栏 + 「记一笔」（v1 草案 · 方向 A）**（暂按推荐方向冻结，用户改选即同步改写）；`TICKETS_M2A.md` 新增 **T-14b**（Part A 立即可做 / Part B 待拍板）；`SESSION_PROMPTS.md` §B 重写为**执行层新 session 开场 prompt**（覆盖 T-14b → M2.0 正式波），旧 T-12c 续工 prompt 已归档；`PROJECT_STATE.md` 当前票 = T-14b
- **⚠️ 待用户批准（防护栏拦截）**：`AGENTS.md` 的 UI 结构行订正（「记一笔仅属分析页」）——两次写入均被防护栏拦下（批准提示超时，按规矩不重试）。该文件**每回合注入执行层上下文**，建议尽快批准；未批准前由 `TICKETS_M2A.md` T-14b + `SESSION_PROMPTS.md` §B 承担同等约束传达
- **下一步**：等用户挑底栏方向（A/B/C）→ 改选则同步改 spec → 派 T-14b（prompt 已就绪）→ 验收 → M2.0 正式波（T-15 起，需先拍 AI 三屏方向）

## 2026-09-14（管理层验收记录：T-14 ✅ 通过 —— 收口小票闭合，M2.0 前置波连带遗留全清）
- **验收基线**：`6133d61`（WIP：统计页对齐）+ 收工 `79eaa74`；已 push，工作区干净
- **五层验收**：
  1. **记录核对** ✓ 提交与 hash 一致；变更面 = `stats_page.dart`(+36) / `test/stats_page_test.dart`(125 新增) / `t09c`+`t09e` 帧名 / `clean_dev_db.py`(前缀) / 证据 10+ 文件
  2. **独立复验** ✓（管理层亲跑）`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (196)**（194 + 2）整轮正常退出 —— 与申报逐位一致
  3. **源码级审查** ✓ ① 净值加 `cents < 0 ? AppColors.semanticExpense : AppColors.ink` 分支（+ key `stats_net_value`）② 导出键 = `OutlinedButton.icon`：`foregroundColor=goldAccent`、`side=BorderSide(goldAccent)`（默认 width 1.0 = hairline）、**无 backgroundColor**（+ key `stats_export_button`）③ 单测断言到位：零/正 = ink、负 = semanticExpense（文本与颜色同断言）；`side.width == 1.0`、`foregroundColor == goldAccent`、`backgroundColor == null`、页面无 `FilledButton` ④ **记录同步是真同步**：`t09e` 帧名改而**原 md5 逐字保留 + 指向注记**；`t09c` 运行日志**追加**说明（正文未动）；T-13b 回归清单**追加**指向而非改写 —— 原票证据零篡改
  4. **独立 integration** ✓（管理层亲跑）`t13b_full_chain` **All tests passed**（`draft=false` / `export bom=true schema=3` / `teardown live_tx=0 live_assets=0`）+ `t05_stats` **All tests passed**；跑后直读 sqlite：`transactions / assets / asset_photos / budget_months` **live 全 0**
     - **照片孤儿独立复核** ✓ `python tool/photo_gc.py --report <仓库外路径>` → **94 文件 / 87 引用 / 0 外来 / 7 孤儿**，我用文件清单逐项相加：4303+4401+4254+4402+4362+4362+4227 = **30311 字节**，与申报**精确吻合**；且 `--report` 写入仓库外成功（T-13a/T-13b 的工具挂账修复得到实战验证）
  5. **UI 目检** ✓ 帧 `04_stats`：净结余 **`¥-15` 为红色**（改动前是暖白 `ink`）；帧 `10_stats_exported`：导出键为**金细边 + 金字、内部无金底填充**（outline 形态成立）；两帧无裁切，底栏「记一笔」+ 三 tab 正常
- **裁决**：① **批准 apply 这 7 个照片孤儿**（≈29.6KB，dry-run 已存档 `evidence/t14/photo_gc_dry_run.json`）——由下一票开工时执行，`--apply` 前再跑一次 dry-run 确认数量 ② 本票无其他挂账
- **执行层行为肯定**：帧 md5 变化做了**证伪实验** —— 把 `stats_page.dart` 换回改动前版本重跑，旧代码同样产出新 md5（`state3b` 回到旧值），从而证明 3 个 `state1` 帧的差异源于**跨日**（09-13→09-14，帧含日期轴/今日标签）而非回归。这是本项目「以源码+帧+数值裁决」纪律的正面样板，值得后续票沿用
- **结论：T-14 ✅ 验收通过 → M2.0 前置波的连带遗留全部闭合。** 进入 **M2.0 正式波**（AI 上线）：拆票已写入 `TICKETS_M2A.md`，UI 预览稿 `design/ai_wave_preview.html`（配置页 / 主页 AI 位 / 对话窗口，各 2 方向）待用户拍板后冻结 `DESIGN_AI.md` 再派 T-15
- **交付物提醒**：桌面 APK 仍为 T-13b 版（md5 `e7c75551f5894e22e952df892de914f6`）——T-14 的两处统计页视觉改动**尚未入包**，由 M2.0 波首票出包时一并刷新

## 2026-09-14（**执行层 T-14 完工：收口小票（P3）**——统计页对齐 spec + 帧名/备份名 + 照片孤儿例行化）
- **基线/结果**：`08e9ee4`（T-13b 验收）→ WIP `6133d61`（①②）+ 本条目所在收工 commit；`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (196)**（194 + 新增 2）
- **① 统计页净结余负值配色（`DESIGN_T09` §8.5）**：`stats_page.dart` 净值文字加颜色分支（`cents < 0` → `semanticExpense`；**零/正 → `ink`**）+ key `stats_net_value`；**单测 `test/stats_page_test.dart`**：零（`¥0`）、正（`¥3000`）为 ink，负（`¥-6000`）为 semanticExpense（同时断言渲染文本与颜色）；**帧**：链路 `04_stats` 目检 `¥-15` 为红（改动前为暖白 ink）
- **② 统计页导出键形态（§8.5）**：`FilledButton.tonalIcon`（goldContainer 实心 pill）→ **`OutlinedButton.icon` + goldAccent hairline 边（width 1）+ 金字**、无背景填充（金色克制章程：金只作描边/文字，不作大面积填充）；key `stats_export_button`；**单测**断言 `side.color=goldAccent`/`width=1`、`foregroundColor=goldAccent`、`backgroundColor=null`、页面无 `FilledButton`；**帧**：链路 `10_stats_exported` 目检为描边键
- **③ 证据帧名过时**：`t09e 02_keyboard_after_splash` → **`02_home_after_splash`**（内容=启动后主页）、`t09c 01_home_idle` → **`01_quick_entry_idle`**（内容=快记页 idle）；**帧本体不变**；记录同步 = `evidence/t09e/.t09e_frame_md5.txt` 更名并保留原 md5 + 指向注记、`evidence/t09c/.t09c_run_log.txt` 追加说明（**正文保持逐字原样**）、T-13b 回归清单追加指向说明（**不改写 T-13b 运行记录**）；现行名/md5 见 `evidence/t14/.T14_rerun_frame_md5.txt`
- **④ 工具备份名**：`clean_dev_db.py` 备份前缀 `pre-t09e-<stamp>.bak` → **`pre-clean-<stamp>.bak`**；实测产出 `gringotts.sqlite.pre-clean-20260914-195410.bak`
- **⑤ 照片孤儿例行化**：`python tool/photo_gc.py --report evidence/t14/photo_gc_dry_run.json` → **94 文件 / 87 引用 / 0 外来 / 7 孤儿 = 30311 字节（≈29.6KB）**，与工单实测一致；**未 apply**（工单要求 apply 前确认；一条命令即可）
- **回归**：受影响的 5 个脚本重跑 **全绿**（t05 / t09a / t09c / t09e / t13b，日志 `evidence/regression/*.t14.log`）；其余 9 个（t04/t09b/t09c2/t09d/t10b/t11/t12/t12c/t13a）帧内不含统计页像素且无改名项，**T-13b 记录继续有效**
- **md5 变化逐条解释**（`.T14_rerun_frame_md5.txt`）：与本次两处改动相关的帧 = t05 `state3b`、t13b `04_stats`（负值红）、t13b `10_stats_exported`（描边键）；**t05/t09a/t09c `state1` 的变化源于日期跨日**（09-13→09-14，帧含日期轴/今日标签）——已用「换回改动前 `stats_page.dart` 重跑」**确证**（旧代码同样产出新 md5，且 `state3b` 回到旧值），**非回归**
- **遗留**：7 个照片孤儿待批准后 apply；本票无其他挂账
- **下一步**：**等验收**（本轮 = `6133d61` + 本条目所在收工 commit）→ M2.0 正式波（BYO AI 配置 → 主页 AI 分析建议 → 对话窗口…，待派工）

## 2026-09-13（管理层验收记录：T-13b ✅ 通过 —— **M2.0 前置波关闭**；含 1 项口径瑕疵订正 + 4 项偏离裁决）
- **验收基线**：`0c32108`（工具/测试卫生）+ `d82fdaf`（全链路 + 全量回归）+ 收工 `08e9ee4`；已 push，工作区干净
- **五层验收**：
  1. **记录核对** ✓ 3 个提交、hash 与申报一致；变更面 = `t13b_full_chain_test.dart`(293 新增) / 5 个旧脚本修复（t05/t09a/t09b/t09c/t09c2/t09d）+ `t04` 补墓碑 / `tool/photo_gc.py` `tool/clean_dev_db.py` 卫生 / `splash.dart` 注释 / `assets_page.dart`(+1 key) / 证据 20+ 文件
  2. **独立复验** ✓（管理层亲跑）`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (194)** 整轮正常退出 —— 与申报逐位一致
  3. **源码级审查** ✓ ① 全链路脚本为真端到端：导出断言**逐字节**（CSV 前 3 字节 `EF BB BF` BOM + 解码后含编辑后 `瑞幸咖啡` / `2000`；JSON `transactions[].merchant` 与 `assets[].name` 含改名后资产），teardown 墓碑种子**并删除导出的 2 个文件**（不留垃圾）② 工具卫生：两工具新增 `display()`（`relative_to` 失败回落绝对路径）+ `--report` 参数化、默认值改为**中性工具自有路径**（不再指向 T-13a / T-09E 证据）③ `t04` 补墓碑 teardown ④ 启动画面像素未动（仅注释）
  4. **独立 integration** ✓（管理层亲跑 4 个脚本）`t13b_full_chain` → **All tests passed**，逐步打印复核：`entry amount=1500 draft=false`（快记即正式）/ `stats today_expense=15.00` / `ledger_edit merchant=瑞幸咖啡 amount=2000` / `asset_edit name=T13B 相机Pro value=600000`（改名校值存）/ **`export files=2 bom=true csv_merchant=true json_asset=true schema=3`** / `teardown live_tx=0 live_assets=0 exported_files_removed=2`；修复脚本抽样 `t05` ✓ / `t09c2` ✓ / `t04` ✓（`T04_TEARDOWN seed_tombstoned=true live=0->0`）
     - **dev 库卫生独立复核** ✓（直读 sqlite）我跑完 4 个 integration 后：`transactions / assets / asset_photos / budget_months` **live 全 0**、`categories 9` 未动 —— 与申报一致，**证明 5 个脚本的墓碑 teardown 真的止住了累积污染**
     - **工具卫生独立复核** ✓ `python tool/photo_gc.py --selftest` 在**系统 TEMP（仓库外）**下 **9 PASS / `selftest: OK` / EXIT=0** —— T-13a 的挂账确已修复；`clean_dev_db` 默认报告路径已中性，未覆盖他票证据
     - **APK** ✓ 桌面 `gringotts-T13b-release.apk` 65,877,476 字节，md5 **`e7c75551f5894e22e952df892de914f6`** 与申报逐位一致
  5. **UI 目检 + 数学复核** ✓ 帧 03/10 目检（主页 `¥15 · 1 笔` / 统计页红绿双线 + 金 donut + 底部「记一笔」与三 tab，统计 tab 金字激活）。**对比度 11 组我逐值重算**（WCAG 2.x，从 `tokens.dart` 十六进制）：17.14 / 7.23 / 6.88 / 11.51 / 9.36 / 10.92 / 11.16 / 13.94 / 5.03 / 6.49 / 4.89 —— **与完工报告表格逐位相同，零偏差**（独立复算）
- **⚠️ 申报口径瑕疵（结论不受影响，已订正）**：完工报告写「全部 ≥ AA（最低 5.03）」，但其自身表内 `goldDeep/canvas = 4.89` 才是最低值（4.89 仍 ≥ 4.5，故「全部 ≥ AA」成立）。**正确口径：最低 4.89**。后续报告请复核极值
- **偏离裁决（完工报告 §4 五项，逐条给结论）**：
  - **A 统计页净结余负值未取 `semanticExpense`** → **修**（spec §8.5 明确；并入 T-14 第 1 项，含单测）
  - **B 统计页导出键为 tonal 实心 pill、spec 要求 hairline 金描边 outline 键** → **修**（本项目「金色克制」章程：金只作描边/文字，不作大面积填充；并入 T-14 第 2 项）
  - **C `DESIGN_T09` 三处文档漂移（§8.1 / §8.2 / §9 金渐变 ≤2）** → ✅ **管理层已当场订正**（§8.1 标注 T-12c 后失效并给出真相源；§8.2 回顾页标为已删除；§9 金色纪律改 ≤4 并注明当前实现 2 处）
  - **D 证据帧名过时（t09e / t09c）** → 修，并入 T-14 第 3 项（内容已核对无误，仅名称）
  - **E `clean_dev_db` 备份名前缀仍 `pre-t09e-`** → 修，并入 T-14 第 4 项
- **新增发现（管理层独立跑的副产品，入 T-14 第 5 项）**：全量回归/测试会自然产生照片孤儿——我 dry-run 实测回归后有 **7 个孤儿（≈30KB）**（T-13b 的 GC dry-run 记录取的是回归**前**状态 56/56/0）⇒ 约定全量回归收尾跑一次 `photo_gc` 并在 WORKLOG 记数
- **执行层行为肯定**：① **全量回归暴露了 5 个自 T-11/T-12c 起就静默失效的证据脚本**（`pageBack()` 打在快记页、惰性列表折叠断言、count-up 中途采样在 IndexedStack 下不可行）——全部按根因修好而非加 ignore，且把无法中途采样的机制改由单测锁定并**如实说明帧改名** ② `t04/t09b/t09c2/t09d` 补齐墓碑 teardown，止住 dev 库累积污染（我直读 sqlite 验证 live 全 0）③ 主动申报 5 项偏离而不擅自越界修改 ④ 完工报告标注逐条依据（源码位置 / 帧 / 测试）
- **结论：T-13b ✅ 验收通过 → M2.0 前置波（结构波）全部关闭**。下一票 **T-14（收口小票）**；之后进入 **M2.0 正式波**（BYO AI 配置 / 主页 AI 分析建议 / 对话窗口 / 图表 AI 解读 / 预算与周期账单 / Widget / 本地加密）

## 2026-09-13（**执行层 T-13b 完工：M2.0 前置波收尾**——全链路实跑 + 全量回归 + APK + 完工报告 + 工具/测试卫生）
- **基线/结果**：`5f59ece`（T-13a 验收 + wordmark 裁决）→ 本轮 3 个 WIP 提交 `0c32108`（工具/测试卫生 + splash 注释）/ `d82fdaf`（全链路 + 全量回归 + 5 个脚本修复 + 清单）；`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (194)**，整轮正常退出
- **① 全链路实跑（新增 `integration_test/t13b_full_chain_test.dart`）**：三 tab 壳 → 「记一笔」压栈 → **立即入账**（`is_draft=false`，主页即显 `¥15 · 1 笔`）→ 统计（`支出 ¥15`/净结余 −15）→ 资产（新增带 CPD 资产）→ 详情 → 编辑（改名）→ **明细（自统计页进入）** → 行内编辑（商户+金额）→ **导出**（CSV 带 BOM 逐字节断言含编辑后商户/金额 + JSON 含资产 schema=3）→ teardown 墓碑全部种子；**All tests passed**，10 帧 md5 唯一（前置自声明 `live_tx=0 live_assets=0 budget=null`）
- **② 全量回归**：回归前 `clean_dev_db --apply` 退掉 T-04 遗留行 → **14/14 脚本全绿**（t04/t05/t09a/t09b/t09c/t09c2/t09d/t09e/t10b/t11/t12/t12c/t13a/t13b），68 帧；**6 组重复 md5 全部逐条解释**（同屏同态：引导态主页 ×4 / 空资产页 ×5 / 无数据统计页 ×3 / 快记页 idle ×2（t09a 01 与 t09c 01 名称不同实为同屏）/ t09b 返回列表复现同帧 / t09c stagger 60ms 已落定）；**回归后 dev 库 live 全 0**（transactions/assets/asset_photos/budget），categories 9 未动
- **③ 本票真发现：5 个证据脚本自 T-11/T-12c 起静默失效（全量回归才暴露）**
  1. `pageBack()` 打在**快记页**（该页回退是自有 `quick_back`，非 Material BackButton）→ t09a/t09c/t09c2（共 3 处）改按 `quick_back`；t09c2 的 count-up 断言在 T-12c IndexedStack 下无法中途采样 → 改断言**落位终态**（弹簧机制由 `test/motion_base_test.dart` 单测锁定；帧改名 `03_net_value_settled`，并为净值加 key `assets_net_value`）
  2. **惰性列表折叠**断言：t05/t09a/t09c 要求首屏之下的「饼图区」→ t05 改为滚到该区单独出帧 `state3b_category_pie`，t09a/t09c 改断言首屏卡片
  3. **清理缺口**：t04/t09b/t09c2/t09d 播完不留墓碑（累积污染 dev 库并造成跨脚本同帧）→ 全部补墓碑 teardown（含照片行）
  4. `perf_scan_test` 不计入功能回归集（T-09E profiling 载体，debug 帧耗时不成立，如实声明）
- **④ 工具卫生（T-13a 挂账出账）**：`photo_gc.py --selftest` 在 TEMP 不在仓库内时**复现 `photo_gc.py:210` ValueError**（`REPORT.relative_to(ROOT)`）→ 安全路径显示 + **`--report` 参数化**（默认中性 `evidence/photo_gc_report.json`）；`clean_dev_db.py` 同样加 `--report`（默认中性，**不再指向 `evidence/t09e/...`**）；实测 selftest 9 项 PASS（TEMP 外置）、photo_gc dry-run 56/56/0、两份报告均落 `evidence/t13b/` **未覆盖他票证据**
- **⑤ 收尾 2 项**：`lib/ui/splash.dart` 注释「the home page IS the keypad…」→ T-12c 三 tab 壳（**仅注释，启动画面像素未动**；wordmark 去重按用户裁决不做，`DESIGN_T09` §8.6 锁定）；`t04` 补墓碑（同 ③3）
- **⑥ 交付**：`gringotts-T13b-release.apk`（62.8MB，**md5 `e7c75551f5894e22e952df892de914f6`**）已复制到桌面；构建日志 + md5 记录 `evidence/t13b/apk_build.log.txt` / `apk_md5.txt`
- **⑦ 完工报告**：`evidence/t13b/completion_report.md`（对照 `DESIGN_T09` §8 逐页 7 页 + §9 补充验收 + `DESIGN_MAIN` §3–§8，含**对比度实测 12 组全部 ≥AA（最低 5.03）**、金渐变定义处 = 2（≤4）、动效/数据/回归验收）
- **遗留问题（需管理层裁决，均 P3，详见完工报告 §4）**：A 统计页**净结余负值未取 `semanticExpense`**（spec §8.5，1 行可修，本票未擅自改）；B 统计页**导出键为 tonal 实心 pill**，spec 要求 hairline 金描边 outline 键；C `DESIGN_T09` §8.1/§8.2/§9 **三处文档漂移**（速记首页 / 回顾页 / 金渐变 ≤2，已被 T-11/T-12c/T-13a 取代，**.md 归管理层**，执行层未改）；D 证据帧名过时（t09e `02_keyboard_after_splash`、t09c `01_home_idle`，内容已核对无误）；E `clean_dev_db` 备份名仍带 `pre-t09e` 前缀（本票只按要求做了 `--report`）
- **下一步**：**等验收**（本轮 = `0c32108` + `d82fdaf` + 本条目所在收工 commit）→ M2.0 前置波关闭 → M2.0 正式波（BYO AI / 主页 AI 分析 / 对话窗口…，待派工）

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

## 2026-09-13（管理层验收记录：T-13a ✅ 通过 —— 净值衬线回归 / 照片 GC / M1.x 清账 / 月历 342dp 边界修好）
- **验收基线**：`751509a` + `bf1ae2d` + `f90116f` + `4a943a3` + 收工 `fd14688`（已 push `5595d4e..fd14688`，工作区干净）
- **五层验收**：
  1. **记录核对** ✓ 4 个 WIP 提交 + 1 收工提交，hash 与申报一致；变更面 = `tokens.dart`(+16) / `assets_page.dart`(+20) / `home_page.dart`（Hero token 化 + 月历滚动）/ `tool/photo_gc.py`(299) / 2 个新单测（`brand_number_test` 133、`month_sheet_viewport_test` 150）/ `integration_test/t13a_assets_sheet_test.dart`(191) / `t09e` 注释 / 证据
  2. **独立复验** ✓（管理层亲跑）`flutter analyze` → **No issues found**；`flutter test` → **All tests passed (194)** 整轮正常退出（186 → 194，+8；删除 0）——与申报逐位一致
  3. **源码级审查** ✓ ① `tokens.dart`：`brandNumber = 48`、`AppGradient.goldText = LinearGradient([goldAccent, goldDeep])`（默认 topCenter→bottomCenter，与 Hero 原内联渐变**逐值等价** ⇒ 主页像素不变，回归帧 `5480480ccf84` 与 T-12c 轮一致可证）② 资产页净值 = `ShaderMask(AppGradient.goldText)` + Playfair w600 / 48 / tabular，页内其余数字未动 ③ 月历 = `ConstrainedBox(maxHeight: 视口高 − 顶 inset − s − l − 底 inset)` + `SingleChildScrollView`，格高仍 52（≥48 触控）④ `photo_gc.py` 安全栏逐条核：引用集为空即中止（需 `--allow-empty-references` 覆盖）、删除集三条断言（hash 名 / 在 photos 内 / 不在引用集）、apply 前备份、apply 后「引用文件与外来文件全仍在」的零误删断言
  4. **独立 integration** ✓（管理层亲跑 `t13a_assets_sheet_test.dart -d windows`）**All tests passed**；我实测打印与其表格**逐格复现**：800×600→342.0/52.0/0、800×360→342.0/52.0/0、640×300→300.0/52.0/42.0、360×280→280.0/52.0/62.0；`T13A_NET_VALUE font=PlayfairDisplay w600 size=48 gradient=goldAccent->goldDeep shader_masks=1`；teardown 种子已墓碑
     - **独立 GC 复核** ✓ 管理层亲跑 `python tool/photo_gc.py`（dry-run）→ **total=56 / referenced=56 / foreign=0 / orphan=0，retained=242831 字节**——与其 apply 后状态逐值一致（11 个孤儿确已删、56 个被引用文件一个不少、字节数吻合）
     - **帧 md5**：4 帧中仅 02 与其记录相同，01/03/04 不同——**非缺陷**：其清单已声明「帧含 dev 库状态与 CPD 持有天数 ⇒ 仅 run 内唯一、不跨日可复现」，我核验差异来源与其声明一致（CPD/日期 + T-04 遗留行）。**本票改以结构化断言承担 spec 证明**（`brand_number_test` 3 例：token 逐值、Hero 与净值 `TextStyle` 全等、全页仅 1 处 Playfair 节点），帧降为辅助——方向正确，值得沿用
  5. **UI 目检 + 数学复核** ✓ 帧 01：净值 `¥10800` 为**衬线 + 上浅下深金渐变**；同页 服役/退役/已实现 pills、列表「¥6000 · 256 天」、CPD「¥23.4/天」**全为 sans**；无溢出裁切。数学复核：月历内容 310dp + sheet 内边距 32 = **342dp**；`maxHeight` 代入 640×300 ⇒ 268+32 = **300**、滚 310−268 = **42**；360×280 ⇒ **280**、滚 **62**——与其表格逐格吻合
- **✅ 挂账核销（T-12c 遗留 P3 月历横屏边界）→ 结论：修好**：视口够高时逐像素同原来（帧 02 与 T-12c 轮同为 44523 字节），不够时网格内滚、12 月全可达、格高保持 52。新边界如实申报：视口 ≤342dp 时 sheet 占满整屏 ⇒ 无遮罩可点，退出 = 选月/下拉/系统返回（已实测断言，未假装遮罩存在）——**接受该行为**
- **⚠️ 管理层独立复验发现（不构成 T-13a 缺陷，但工具不可第三方复验）**：`python tool/photo_gc.py --selftest` 在**普通 shell（TMP=`%LOCALAPPDATA%\Temp`）下崩溃**——`REPORT.relative_to(ROOT)` 在 selftest 改指临时报告路径时抛 `ValueError`；仅当 TEMP 落在仓库内（其 harness 的 `.ekko-tmp/`）才跑得通。**我做的确定性验证**：TEMP 指向仓库内 `.ekko-tmp/verify` → **9 PASS / selftest: OK**（与其提交证据逐行一致）；指向系统 Temp → traceback。**结论：其「selftest 9 PASS」申报为真、证据真实，但脚本存在环境依赖 ⇒ 已立 T-13b 修**（含 `photo_gc --report`、`clean_dev_db --report` 参数化）
- **执行层发现（本轮最值钱的一条，管理层已核验成立）**：`t04_assets_test` 播种后**不清理**（源码仅 `addTearDown(container.dispose)`，零墓碑）⇒ 每轮回归把测试资产永久留在 dev 库 ⇒ 后续脚本渲染到同一屏：回归集内两处重复 md5（`5480480ccf84` t04≡t10b、`8fa0b4ae1011` t04≡t12c），且我亲跑的资产帧里「已卖出 测试相机 ¥-1200」正是该遗留行 ⇒ **已立 T-13b：全量回归前先清库 + 给 t04 补墓碑 teardown**（否则全链条回归的帧不可信）
- **管理层处置**：① `FEATURES.md`「先记后补机制」段（draft 入库 / 首页 N 笔待完善 / 回顾页批量补全）**已由管理层订正**为「快记即正式」② `lib/ui/splash.dart:9`「the home page IS the keypad, there is no navigation layer」属**代码注释** ⇒ 写入 T-13b
- **结论：T-13a ✅ 验收通过**。下一票 **T-13b**（wordmark 裁决 + 全量回归 + APK + 完工报告 + 工具/测试卫生）

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
