# T-13 完工报告（M2.0 前置波收尾）

> 对照 `DESIGN_T09.md` §8/§9 + `DESIGN_MAIN.md` 逐页核对。结论分三档：**✓ 与 spec 一致** / **⚠️ 偏离（已记录，需管理层裁决）** / **N/A（spec 条目已被后续用户裁决取代）**。
> 依据标注：源码位置 · 证据帧 · 测试。

## 0. 交付与基线（2026-09-13）

| 项 | 值 |
|---|---|
| 测试基线 | `flutter analyze` → **No issues found**；`flutter test` → **All tests passed (194)**，整轮正常退出 |
| 全量回归 | `integration_test/*` **14/14 脚本通过**（t04/t05/t09a/t09b/t09c/t09c2/t09d/t09e/t10b/t11/t12/t12c/t13a/t13b），68 帧，重复 md5 分组逐条解释（`evidence/regression/.T13b_regression_summary.txt`） |
| 全链路实跑 | `integration_test/t13b_full_chain_test.dart`：三 tab 壳 → 记一笔压栈 → 立即入账（`is_draft=false`）→ 统计 → 资产 → 详情 → 编辑 → 明细（自统计页进入）→ 行内编辑 → 导出（CSV 带 BOM + JSON，逐字节断言含编辑后商户/金额与资产）；All tests passed，10 帧 |
| 交付物 | `C:\Users\JHarayden\Desktop\gringotts-T13b-release.apk`，65,877,476 字节，**md5 `e7c75551f5894e22e952df892de914f6`** |
| dev 库卫生 | 回归前后 `tool/clean_dev_db.py --apply`（报告 `evidence/t13b/dev_db_cleanup*.json`）；回归后直读 sqlite：transactions/assets/asset_photos/budget_months **live 全 0**，categories 9（seed 未动） |
| 未改动 | 启动画面 wordmark（用户裁决「不动」，§8.6 锁定）；`DESIGN_MAIN.md` / `DESIGN_T09.md` / `AGENTS.md`（管理层文档） |

## 1. DESIGN_T09 §8 逐页要点

| § | 页面 | 结论 | 依据 |
|---|---|---|---|
| 8.1 | 速记首页 | **N/A（IA 已被 T-12c 取代）** | 现结构：主页 = 分析页 + 三 tab 壳，「记一笔」压栈进快记页（`DESIGN_MAIN` §1 v3）。原条目逐项映射：顶栏 wordmark → 启动画面 wordmark（平涂 goldAccent，§7）；键盘键 `elevated` + 按下 **0.97** ✓（`quick_entry_page.dart:590/683`）；确认键按用户 T-11 裁决改为**金边描边**（非渐变，sheen 已随 T-12 删除）——见 §4 |
| 8.2 | 回顾页 | **N/A（T-12c Part B 删除）** | 快记即正式，回顾页/批量补类别/待完善徽章零残留（T-12c 验收④，本票回归复核 t09*/t10b/t12 全绿） |
| 8.3 | 资产列表页 | ✓ | 净值看板（eyebrow「总资产净值」+ 大数字 + 三 pill：服役/退役/已实现）——大数字 = Playfair 600/48 + 金渐变（T-13a，帧 `evidence/t13a/.t13a_01_assets_net_value.png`）；tile 按下 0.98 + Hero 接力（T-09B/T-09D，本票回归帧）；CPD 徽章 = goldContainer pill ✓（帧 `evidence/t13b/.t13b_07_assets_with_cpd.png`）；**服役进度条 = `LinearProgressIndicator` goldAccent/hairline，365 天基准** ✓（`assets_page.dart:240-298`） |
| 8.4 | 资产详情页 | ✓ | §6 全项 + 视差 B + 成组入场 D；本票链路段 08/09 帧（`evidence/t13b/.t13b_08_asset_detail.png`、`09_asset_edited`）+ T-09B/T-09D/T-09C2 回归帧；详情页数字与列表同源（`CpdCalculator`，`test/cpd_calculator_test.dart` + `test/asset_edit_test.dart`） |
| 8.5 | 统计页 | **⚠️ 两处偏离** | 净结余卡：eyebrow + 大字 ✓、趋势双线（支出 `semanticExpense` / 收入 `semanticIncome`）✓、金阶 donut ✓（帧 `evidence/t13b/.t13b_10_stats_exported.png` 目检：红/绿双线 + 金 donut + 图例）。**偏离 A**：净结余**负值未取 `semanticExpense`**（`stats_page.dart:138-147` 无颜色分支 ⇒ 暖白 ink）——spec 要求「负值 semanticExpense 大字」；**偏离 B**：导出键为 `FilledButton.tonalIcon`（goldContainer 实心 tonal pill，帧 10 目检），spec 要求 **hairline 金描边 outline 键** |
| 8.6 | 启动画面 | ✓（wordmark 去重按裁决不做） | canvas 纯色 + 徽标 38% + Playfair 600 wordmark ✓（T-09E 帧 + 本票回归 `t09e` 全绿）；**徽标内 wordmark + 下方独立 wordmark 的「重复」为有意保留**，`DESIGN_T09` §8.6 已锁，本票未触碰启动画面任何像素 |
| 8.7 | 应用内图标 | ✓ | Material 24 网格线性单色图标；未激活 `inkSecondary` / 激活 `goldAccent`（`home_shell.dart` `_TabButton`；帧 10 目检：统计 active 金字、分析/资产 灰字） |

## 2. DESIGN_MAIN 逐页核对

### §3 主页规格（10 项）
1. 顶栏月份按钮 `2026 年 9 月 ▾` + 预算 ⚙，**无 ‹ › 箭头** ✓；月历 sheet（拖拽把手 + overlay + 圆角 18 / 年份 `‹ 2026 ›` / 3×4 宫格 / 当前月金边金字 / **未来月灰显不可点** / 选中即切换 / reduce-motion 淡入）✓ — 断言：`test/home_page_test.dart`（灰显=`inkSecondary` 40%、点击不动、`home_month_prev/next` 零残余 key）、`test/month_sheet_viewport_test.dart`（4 视口无溢出 + 格高 52 ≥48 + 末行可达）；帧 `evidence/t13a/.t13a_02/03/04_*.png`
2. Hero：eyebrow「今天还能花」+ 实时额度（**Playfair 600 / 48 + 金渐变 + tabular**）+ 副行「基准 / 剩余 / 剩 N 天」✓（`test/brand_number_test.dart` 断言 Hero 与净值 TextStyle 全等；帧 `evidence/t13b/.t13b_03_home_after_entry.png`）
3. 进度区（本月已花 / 预算可花 + gold 进度条，超支转 `semanticExpense`）✓（`test/home_page_test.dart` 超支用例 + 帧 `evidence/regression/.t10b_03_overspent.png`）
4. 今日行（今日已花 + 笔数）✓（帧 03：`¥15 · 1 笔`，链路断言）
5. 今日支出构成 donut（外径 104 / 环宽 14 / 中心合计 / 图例 ≤3 类 + 其他 / 金阶+灰兜底 / 空态「今天还没有支出」不画空环）✓（`test/home_page_test.dart` donut 合并用例、T-10b 帧 `04_donut_empty`）
6. 底栏固定条：**T-12c 改版** = 底栏上方「记一笔」金渐变实心 + 三 tab；原「明细」按钮移入统计页顶栏（§1 v3 / §8 T-12c 条目）✓
7. AI 卡位（M2.0 填充，无假数据）✓（`_AiCard`，帧 03 末尾）
8. 引导态（无预算 → 「先设置本月预算」卡 + 预算 sheet + 沿用上月）✓（帧 `evidence/regression/.t13b_01_shell_home.png`；`test/home_page_test.dart` onboarding 用例）

### §4 快记页
- §4.1 结构 7 项：顶栏 `‹` + 「记一笔」+ 支出/收入切换 ✓ / 项目名称输入（elevated + hairline + radius 12 + 高 44 + hint）✓ / 金额行 **Playfair 600 / 42** ✓ / 额度联动行（上下 hairline + padding 6 + 数值 goldAccent）✓ / **3×3 类别全显不横滑** ✓ / 键盘 4×3 键高 56 ✓ / 确认键「金边描边 + 极淡金底 + 金字」（用户保留项，非渐变）✓ — 断言：`test/quick_entry_layout_test.dart`、`test/quick_entry_defaults_test.dart`、`test/widget_test.dart`、`t11` 回归帧
- §4.2 键盘：4×3 含小数点、C 移出、键高 56 / radius 17（`AppRadius.key`）、数字键 elevated 无描边 + 功能键透明 hairline、键面 **Playfair 600 / 26**、符号 sans 21、按下 **0.97** + `selectionClick`、禁投影/渐变/发光/循环动画 ✓（`quick_entry_page.dart:590/683/689/692`；`test/quick_entry_layout_test.dart` 断言无 C 键）
- §4.3 保留清单：混合输入解析 / 时段默认类别 / 高频 chip / 午餐内联提示 / 收入切换 / **快记即正式** / 触感 + reduce-motion 退化 ✓（`test/smart_parser_test.dart`、`test/smart_prefill_test.dart`、`t11` 回归）

### §5 明细页（9 项）
时间层级「月 → 日 → 条目」+ 月份行 `‹ 2026-09 ›` + 日期分组（今天/昨天/日期 + 该日合计）+ 条目行（含历史草稿「待完善」标记）+ 类型筛选 chips（只过滤不改分组）+ 禁止按类别/金额分组 + 行内编辑 sheet（全字段 + 墓碑删除）+ 空态 + 日合计 = 可见行净额（口径锁定）✓ — T-12 已验收；本票回归 `t12` 全绿 + 链路 05/06 帧（`evidence/t13b/.t13b_05_ledger.png`、`.t13b_06_ledger_edited.png`）

### §6 资产页字体（T-13a 落地）
净值大数字 = **Playfair 衬线 + 金渐变**；其余数字保持 tabular sans ✓ — 唯一来源 `AppFont.brandNumber = 48` + `AppGradient.goldText`；`test/brand_number_test.dart` 断言（token 逐值、Hero≡净值 TextStyle、页面仅 1 处 Playfair）

### §7 字体与金色章程
- 衬线允许处 5 处 ✓：主页 Hero 额度 / 资产净值 / wordmark（启动画面，顶栏 wordmark 已随 §8.1 失效）/ 快记金额行 / 键盘数字键面
- **金渐变定义处 = 2** ✓（≤4）：`lib/ui/tokens.dart:183` `AppGradient.goldText`（消费方：主页 Hero + 资产净值）+ `lib/pages/home_shell.dart:94` 底栏「记一笔」；饼图金阶为色板非渐变；快记确认键为描边（不计入）
- 金色禁止项 ✓：正文/分隔线/大面积底均未用金（`AppColors.hairline` 为暖灰金描边色非金色填充）；无发光/霓虹/循环动画（`SheenSweep` 已于 T-12 删除）

### §8 验收补充（各票）
T-10b / T-11 / T-12 / T-12c / T-13a 条目均已在各自票验收通过；本票复核 = 全量回归 14/14 + 194 单测 + APK。

## 3. DESIGN_T09 §9 补充验收实测

- **对比度抽查（WCAG 2.x，实测比值，阈值 AA 正文 4.5）**：ink/canvas 17.14 · inkSecondary/canvas 7.23 · inkSecondary/surface 6.88 · goldAccent/canvas 11.51 · goldAccent/overlay 9.36 · onGold/goldAccent（主按钮文字）10.92 · onGoldContainer/goldContainer 11.16 · ink/overlay 13.94 · semanticExpense/canvas 5.03 · semanticIncome/canvas 6.49 · 渐变低端 goldDeep/canvas 4.89 ⇒ **全部 ≥ AA（最低 5.03）** ✓
- **金色纪律 grep**：仓库 `LinearGradient` 出现处 = 2 处（见 §7），与 `DESIGN_MAIN` §7 的「≤4」一致；`DESIGN_T09` §9 的「≤2（确认键 + 饼图金阶）」口径已过时（确认键改描边、饼图为色板）→ 见偏离 C
- **动效验收帧**：Hero 接力 / 视差 / 微缩放 / stagger 各留帧（T-09B/T-09C/T-09C2 原票帧 + 本票回归帧 `evidence/regression/.t09c_*`、`.t09c2_*`）；`CountUpNumber` 弹簧机制由 `test/motion_base_test.dart` 单测锁定（单调、无过冲、精确落位、值变重启）
- **数据验收**：`asset_photos` 迁移用例（`test/asset_photo_and_migration_test.dart`）✓；详情页数字与列表同源（`CpdCalculator` 单测 + `test/asset_edit_test.dart`）✓；净成本口径（CPD/保值率）单测 ✓
- **回归**：`flutter test` 194 ✓ / Windows 实跑 14 脚本 ✓ / release APK ✓ / **用户目测 = 待用户**（交付包见 §0）
- **T-01~T-07 保持绿**：相应能力的运行载体在 Windows 回归集内为单测 + t04/t05/t09* 脚本；T-06（快捷设置磁贴）/T-07（导出）的专项载体为模拟器期资产（`t07` 导出证据 + `test/export_service_test.dart`），导出流程本票已由 t05 步骤 4 + 链路步骤 10 逐字节复核

## 4. 偏离与文档漂移（需管理层裁决，均 P3）

| # | 项 | 现状 | spec | 影响/建议 |
|---|---|---|---|---|
| A | 统计页净结余负值配色 | 暖白 `ink`（`stats_page.dart:138-147` 无颜色分支） | `DESIGN_T09` §8.5「负值 `semanticExpense` 大字」 | 1 行可修（`color: net < 0 ? semanticExpense : ink`）；本票工单未列，未擅自改 |
| B | 统计页导出键形态 | `FilledButton.tonalIcon`（goldContainer 实心 tonal pill，帧 10） | §8.5「导出 = hairline 金描边 outline 键」 | 改 `OutlinedButton` + hairline 金边即可；属 T-09 期 spec 与后续统一风格之争 |
| C | `DESIGN_T09` 文档漂移 | §8.1 速记首页 / §8.2 回顾页 / §9「金渐变 ≤2（确认键+饼图）」 | — | 三者已被 T-11/T-12c/T-13a 的用户裁决取代；**.md 归管理层**，执行层未改 |
| D | 证据脚本帧名过时 | t09e `02_keyboard_after_splash`（内容=启动后主页）、t09c `01_home_idle`（内容=快记页 idle） | — | 内容已逐帧核对无误（见回归 manifest 的重复 md5 说明），仅名称沿用 M1.x 说法；建议 T-14 或下次触碰时更名 |
| E | 工具备份文件名 | `clean_dev_db.py` 备份仍带 `pre-t09e-<stamp>.bak` | — | 本票只按要求参数化了 `--report`；建议改为 `pre-clean-<stamp>` |

## 5. 证据索引

| 内容 | 位置 |
|---|---|
| 全链路 10 帧 + 运行日志 | `evidence/t13b/.t13b_*.png` · `evidence/t13b/full_chain_run.log.txt` |
| 全量回归 68 帧 md5 + 逐条解释 + 各脚本日志 | `evidence/regression/.T13b_regression_frame_md5.txt` · `.T13b_regression_summary.txt` · `*.t13b.log` |
| dev 库清理（dry-run / apply / 回归前 / t09d 重跑前） | `evidence/t13b/dev_db_cleanup*.json|.log.txt` |
| 工具卫生（selftest 复现→修复、dry-run、manifest） | `evidence/t13b/photo_gc_selftest*.txt` · `photo_gc_dry_run.json` · `.tool_hygiene_manifest.txt` |
| T-13a 证据（净值字体/渐变 + 月历边界） | `evidence/t13a/` |
| APK 构建日志 | `evidence/t13b/apk_build.log.txt` |
