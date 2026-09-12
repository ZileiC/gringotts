# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。
> ⚠️ 并发写入约定：追加前先重新读取文件最新版，在头部插入自己的段落，不要重建文件横幅；管理层 patch 前同样先重读。

## 2026-09-12（T-11 执行层施工记录：快记页整体重设计 B+C 混合）
- 📌 **本票 commit = `17c135f`**（已 push；收工三连 WORKLOG → commit → push 完成）
### 做了什么
1. **`lib/pages/quick_entry_page.dart` 整页重构**（DESIGN_MAIN §4，用户定稿 B+C 混合）：
   - **两个输入**：新增「项目名称」输入行（`entry_name`，elevated + hairline，高 44，hint「项目名称 · 如 瑞幸咖啡」）；金额改由 4×3 键盘输入、单独显示（Playfair 600 / 42px + tabular）
   - **键盘补小数点**：`7 8 9 / 4 5 6 / 1 2 3 / . 0 ⌫`；**C 键移出**，清空 = 金额行右侧「清空」文字动作（金额 0 时隐藏，`entry_clear`）
   - **键盘重设计（§4.2）**：键高 56 · 圆角 17 · 横 gap 16 / 纵 gap 10；**数字键 = `elevated` 填充无描边，功能键（`.` `⌫`）= 透明 + hairline**（材质分层）；键面数字 **Playfair 600 / 26px + tabular**，符号 **sans 21px `inkSecondary`**；键区上下各留 12px
   - **类别 3×3 全显网格**（`category_grid`，9 格 58px 高、图标 19px + 标签 11.5px；键 `category_cell_<id>`）：**顺序固定 seed 序**（不按频率重排）；未选 = hairline + inkSecondary，**选中 = 金边 + 极淡金底（goldContainer）+ 金字**；**无任何横向滚动**
   - **移除**：sheen 扫光、发光、装饰性渐变、金渐变填充确认键 → 确认键改 **金边描边 + 极淡金底 + 金字**（高 54 / radius 16，`confirm_cta` 保留）
   - **额度联动行**（保留项）：有预算时显示「记这笔后，今天还能花 ¥X」（数值 `goldAccent`，上下 hairline，padding 6）；无预算整行隐藏
   - **顶栏**：`‹` 返回（`quick_back`）+「记一笔」+ **支出/收入 切换** + 紧凑 icon 入口 **回顾/资产/统计**（`quick_review/quick_assets/quick_stats`，T-10b IA 依赖全保留）
2. **`lib/services/smart_prefill.dart`**：新增纯函数 `QuickEntryDefaults.resolve(explicit, nameSuggestion, timeDefault, topFreq)`——**显式点选 > 名称解析建议 > 时段默认 > 近 14 天高频兜底 > 不预选**；名称联想复用既有 `SmartParser.parse(name, history)`（词典 / 历史 / 前缀，无新解析逻辑）
3. **tokens**：新增速记页几何/字号 token（`entryNameHeight/entryConfirmHeight/categoryCellHeight/keypadGapX/keypadGapY/categoryGap/linkRowPadding/keypadVertMargin/entryPagePadH/V`、`AppRadius.key=17`、`AppFont.amountEntry=42/keyNumber=26/keySymbol=21/categoryIcon=19/categoryLabel=11.5`）；新增 `lib/ui/category_icons.dart`（图标名→IconData，唯一的分类图标映射）
4. **测试 +20（153→173）**：`test/quick_entry_defaults_test.dart`（8：优先级/时钟规则）+ `test/quick_entry_layout_test.dart`（12：键位含小数点无 C、小数输入与清空、名称→类别、3×3 九类/固定序/无横向滚动、智能默认三种、午餐提示、点选覆盖、字体（金额/键面 Playfair，符号 sans）、确认键描边无渐变、顶栏四入口、reduce-motion）+ `test/home_page_test.dart` 补「预算不可行」专属单测（T-10b P3 顺带项）；`test/widget_test.dart` 适配新页（pump 二级页 + budget provider fake）
5. **受影响 integration 按新 IA/新形态更新**：t03（key 输入 + 金额清零断言 + 回顾入口 key）、t09a（帧①改 `entry_name`/`confirm_cta`/支出）、t09b/t09c/t09d（keypad 前 ensureVisible / 帧路径）、**t09c2 重写**（chip 条→3×3 网格 150ms 选中断言；sheen 断言改为**「sheen 已移除」显式断言**；reduce-motion/触感/P4 保留）、perf_scan 导航修复；回归帧统一落 **`evidence/regression/`**（不覆盖原票 evidence）
6. **新增 `integration_test/t11_quick_entry_test.dart`**：三帧（空态/输入态/收入态）+ 顶栏四入口 + 键盘布局 + 3×3 无横向滚动 + 名称→类别 + 小数点/退格 + **draft 入库**（DB 读回 amount/type/merchant 后墓碑清理）+ 前置条件声明

### 关键决策
- **名称建议优先于时钟规则**：`resolve` 中 `nameSuggestion` 排在 `timeDefault` 前——用户真打出的商户名比时钟更具体（例：午餐时段输入「滴滴」应得交通而非餐饮）；时段→高频的顺序即 §补口的「智能默认」
- **页面版式：中段可滚 + 确认键与顶栏固定**：设计目标 748px 免滚动；Windows 预览窗高实测 681，固定排版必溢出，故采用「顶栏固定 / 中段 `SingleChildScrollView` / 确认键固定」——748 上内容按 §4.1 让位表恰好落满（免滚动），更矮的窗口才滚动，且**确认键永远可达**（3 秒一笔）。实机键高上限按 §4.2 = 56（已实现固定 56）
- **「清空」只清金额**：C 键原语义是清金额+类别；新形态下类别由智能默认托管，清空只清金额并复位午餐提示（类别仍可一键改），避免把用户刚选的类别误清
- **sheen/chip 的类保留但页面不再消费**：`SheenSweep` / `MotionChip` 仍留在 `motion.dart`（后者 T-12 明细页的筛选 chips 会复用），本票只移除页面用法并在 t09c2 显式断言「已移除」——**不自作主张删公共动效件**；`SheenSweep` 现为无消费件，记入遗留待裁决
- **顶栏三入口改紧凑 icon**：§4.1 顶栏同时要放返回/标题/支出收入切换，T-10b 又要求三入口全保留；改 icon-only（key 不变）使单行可容，未新增第二行（守住垂直预算）
- **符号 21px / 金额 42px 以工单为准**：工单与 DESIGN §8 写 21px/42px，§4.2 表内仍写 22px/44px（旧值）——按工单执行并记遗留

### 遗留问题 / 待管理层裁决
1. **顶栏草稿徽章（「今日 N 笔待完善」）移除**：DESIGN §4.1 顶栏规格无此项（且新版顶栏已满），本票按规格移除；「回顾」入口仍在、draft 计数不再在快记页可见。若需保留请裁决（可放金额行下方细行）
2. **DESIGN §4.2 表内数字与工单不一致**：表内符号 22px / 金额 44px，工单与 §8 为 21px / 42px——本票按工单（21/42）
3. **`SheenSweep` 成为无消费件**（`MotionChip` T-12 将复用）：是否随 M1.x 清理 `SheenSweep` + `AppColors.sheen/sheenEdge`，请裁决
4. **Windows 预览窗 681 < 设计 748**：预览下面页中段会滚动（确认键固定不变）；「免滚动」在设计目标尺寸（748）成立——实机免滚动与否归用户目测
5. t09b 回归帧 01/04 md5 相同（同态同帧，T-10b 已裁定合法），本轮复现

### 下一步
- 等管理层验收 T-11；通过后按序 **T-12 明细页** 或 **T-13 字体回归 + M1.x**（管理层定序）

### DoD 证据
- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed（173）**，153 → **+20**（defaults 8 / layout 11 / home_page +1；widget_test 适配）
- **保留清单逐项断言**：键盘 3 秒一笔（键位/小数点/退格单测 + t11）· 解析器服务名称字段（瑞幸→餐饮，单测 + t11）· 时段默认类别（单测午间→餐饮、深夜→娱乐）· **午餐内联提示**（单测：周一 12:00 ¥15 → 「这是午餐吗？」）· 收入/支出切换（单测顶栏 + t11 收入帧）· draft 入库（t11：`amount=1500 type=income merchant=瑞幸` 读回后墓碑）· TouchedScale 触感 + reduce-motion 全退化（t09c2：`confirm_haptic=ok`）· 顶栏 返回+回顾/资产/统计（单测 + t11）
- **键盘/网格断言**：11 键含 `.`、**无 C**（单测+t11）；3×3 九类按固定序一次全显；`category_grid` 内 **无 Scrollable**（不可能横向滚动）
- **字体断言**：金额行 Playfair 600/42；键面数字 Playfair 600/26；符号（`.`/⌫）sans 21 `inkSecondary`（单测逐项）
- **移除断言**：确认键 `gradient == null` + 金边金底（单测 + t09c2）；t09c2 `find.byType(SheenSweep) findsNothing`（页面上确无 sheen）
- **T-11 Windows 实跑三帧（Dart PNG，magic 89504e47，md5 全唯一）**：`01_idle 441a1022e746` ｜ `02_input 50ac738e7c96` ｜ `03_income f72f833eab6c`（manifest `evidence/t11/.t11_frame_md5.txt`）
- **受影响 integration（Windows 逐个单跑，全绿）**：t03 ✅（`DB_DRAFTS 2→3→2`）｜ t09a ✅（3 帧）｜ t09b ✅（5 帧）｜ t09c ✅（8 帧，`rise=40.8 opacity=0.600` 与历史验收同值）｜ t09c2 ✅（2 用例 6 帧，`grid duration=150ms`、`confirm_haptic=ok`）｜ t09d ✅（2 用例 8 帧，`overlap=false`）；帧落 `evidence/regression/`，**原票 evidence 未被覆盖**（git status 仅新增 `evidence/regression/`、`evidence/t11/`）
- **release APK**：`build/app/outputs/flutter-apk/app-release.apk` **66,254,200 字节（63.2MB）**，md5 `3754a60a95b523c95e583e79bde0d8eb`；已复制桌面 `gringotts-T11-release.apk`（仓库外）
- **dev 库还原**：本轮残留 live 13 行（tx 5 / assets 1 / photos 7）按墓碑清理 → **live=0（分类 9 保留）**；备份 `gringotts.sqlite.pre-t11-20260912-210932.bak`
- **执行成本如实记录**：integration 共跑 **10 次**（t11 ×3：① 退格断言误算期望 → 改两次退格；② 顶栏漏渲染收入切换 → 补 SegmentedButton；③ 通过。t03 ×2：① 误把下拉菜单 scope 进 ReviewPage（菜单在 root overlay）→ 回退全局 `.last`；② 通过。其余 t09a/t09b/t09c/t09c2/t09d 各 1 次通过）。全部失败由**代码/断言的确定性缺陷**驱动，修完即绿，**零盲目重跑**

## 2026-09-12（T-10b 补记：提交遗漏闭环）
- 接管理层流程挂起项：`git add -A` 补交并 push —— **T-10b 提交 = `41ae607`**（新主页/IA 切换/今日饼图/固定底栏 + 8 个受影响 integration 按新 IA 更新 + 本票 WORKLOG + AGENTS.md 收工三连新规，同一次提交）
- AGENTS.md「工作流程约定」item 3 已改为**硬性三连**：① 先重读并更新 `WORKLOG.md` 顶部 → ② 本票 commit（`T-1x: <summary>`）→ ③ `git push`；**未 commit/push 的「完工」视同未完工，管理层不予验收**（教训：T-09C、T-10b 两次完工未提交）
- 补提交后工作区应干净；待管理层复核 `41ae607` 后补记终审

## 2026-09-12（管理层终审：T-10b ✅ **通过生效**，commit `41ae607`）
- **流程挂起项已闭环**：执行层补交 `41ae607`（T-10b 本体：新主页/IA 切换/今日饼图/固定底栏 + 8 个受影响 integration 按新 IA 更新 + 本次 WORKLOG + AGENTS.md 收工三连），随后 `e893851` 记录 hash；工作区干净、已 push
- **提交内容 = 我验收的状态（已证）**：`evidence/t10b/` 四帧 md5 与验收时**逐字符相同**（1bfa2878d01f / 0ea7d4c5c762 / 07fc568c0a5f / 9d77089fbfa1），且 `git status` 干净 ⇒ 工作区内容与 HEAD 一致 ⇒ HEAD 即受验状态。**据此不重跑测试**（无新事实的重跑违反反浪费铁律）
- **AGENTS.md 收工三连已落地（硬性）**：① 先重读并更新 WORKLOG 顶部 → ② 本票 commit → ③ push；并明确写「**未 commit 或未 push 的『完工』一律视同未完工，管理层不予验收**」，附 T-09C / T-10b 两次教训点名——该条为本次流程整改的正式成果
- **终审结论：T-10b 验收通过 ✅（生效）**。五层验收明细见下一条记录（实质通过），本条仅补生效依据
- **交付物**：release APK 重建并交付用户（`gringotts-T10B-release.apk`，桌面），供其真机查看新主页
- 下一票按序 **T-11（快记重设计，规格已定稿）** 或 **T-12（明细页）**


## 2026-09-12（管理层验收记录：T-10b 实质通过 ✅ —— 附 1 项流程挂起 + 5 项裁决）
- **⚠️ 流程挂起项（验收结论待生效）**：本票全部代码与证据**未提交**（`git status` 显示 home_page.dart / 8 个 integration / AGENTS.md / WORKLOG 等 16 个文件 modified + 5 个 untracked，均在 worktree）。按 Round-7 事故后本管理层自订铁律「**验收结论必须标注所依据的 commit hash，不得基于工作区瞬时状态**」，本次结论为**实质通过、待补提交后生效**——执行层补 `git add -A && git commit && git push`，管理层复核 hash 后补记终审。**这是第二次「完工未提交」（首次为 T-09C）**，建议在 AGENTS.md 收工清单加一条硬性三连：**WORKLOG → commit → push**
- **五层验收（基于工作区，全部通过）**：
  1. 记录核对：收工记录完整（做了什么/关键决策/遗留/DoD），主动上报 5 项遗留与 1 项文档矛盾——**其中「DESIGN §8 与 §4.2/§7 自相矛盾」是我的错，已当场修正**（见下）
  2. 独立复验：flutter analyze → **No issues found**；flutter test → **All tests passed (153)**（144 → +9：`chart_slices_test` 5 + `home_page_test` 4）
  3. 源码级审查：**同源落实**——`home_page` 饼图调用与统计页**同一个** `StatisticsService.chartSlices` + `expenseByCategory` + `AppColors.chartSliceColor`（差异仅在 `maxNamed`：主页 3 / 统计页全量），`CategorySlice.colorIndex` 保证同数据同色；固定底栏用 `Scaffold.bottomNavigationBar`（内容在其上滚动）；`预算 ≤ 0` 走专门分支（`home_page.dart:359/405`「本月预算已不可行：计划存款不低于收入」——**T-10a 管理层备注已消化**）
  4. **独立 integration（管理层亲跑）**：`t10b_home_test.dart` → All tests passed；**4 帧 md5 与执行层证据逐字符相同**（1bfa2878d01f / 0ea7d4c5c762 / 07fc568c0a5f / 9d77089fbfa1，确定性复现）；前置条件自声明（`live_today_expenses=0`）；固定底栏断言 `record_bottom=673.0 / screen=681.0`（在屏内）✓
  5. **UI 目检四帧 + 数学复核**：引导态（引导卡 + 进度位「设置预算后显示本月进度」**不放假数字** + 饼图位「今天还没有支出」不画空环）✓；已设置态 **¥186.65 = (5600−2000−53.6)÷19 天**、基准 **¥120 = 3600÷30**、比例 1% ✓、饼图 22.6+15+10+6 = 53.6 ✓ 四类金阶配色与统计页一致 ✓；超支态 Hero 归零、进度条满格转 `semanticExpense`、「已超支 ¥3.6」文案可读（预算 50 − 已花 53.6）✓；衬线金 Hero 数字与固定底栏（记一笔金渐变 + 明细金描边）全部到位 ✓
- **管理层裁决（回应执行层 5 项遗留）**：
  1. **DESIGN §8 矛盾 → 已修**（管理层失误：§4.2/§7 按用户裁决改成键面 Playfair，§8 漏改仍写「不许衬线」）——现 §8 与 §4.2/§7 一致：键面 Playfair 600/26px、符号保持 sans、分类 3×3 全显、垂直预算让位表
  2. **IA 缺口（主页无 资产/统计 入口）→ 按帧实现正确，暂不改**；挂到 T-12：明细页落地时一并把 `资产/统计` 收进主页入口体系（避免现在自增范围外的图标）。**已向用户标注此 UX 观察，用户如要求立即补则改派**
  3. **t09e 未改未跑（注释过时）→ 归 T-13** 触碰时订正，不阻塞
  4. **t09b 回归帧 01/04 md5 相同 → 判定合法**：两者是**同一状态**（列表→详情→返回后的列表）在同一条件下拍摄，属「同态同帧」；本管理层此前的证据违规指的是**不同状态共用一帧**（T-03 假名事件），二者性质不同。执行层主动上报符合透明要求
  5. **CPD 459→460 天自然漂移 → 非缺陷**，随行演进
- **新增 P3（随 T-11/T-12 顺带）**：`预算不可行` 分支已实现但**无专属单测**（现有 4 条 home_page 测试未覆盖该分支）→ 补一条断言
- **结论：T-10b 实质验收通过 ✅（待补提交后终审生效）**。下一票按序 T-11（快记重设计，规格已完全定稿）或 T-12（明细页）

## 2026-09-12（T-10b 执行层施工记录：新主页 UI + IA 切换 + 今日饼图 + 固定底栏）
### 做了什么
1. **新主页 `lib/pages/home_page.dart`**（= 启动页 / 分析页，按用户确认的 `design/MAIN_preview.html` 第①屏）：
   - 顶栏：`Budget` eyebrow + `2026 年 9 月` + `‹ › ⚙`（上/下月 + 预算入口）；**未来月箭头在当前月禁用**；切到历史月 = 只读（点 ⚙ 提示「历史月份只读，仅可查看」）
   - Hero：eyebrow `今天还能花 · Today's Allowance` + **实时额度（Playfair 600 / 48px + 金渐变 + tabular）** + 副行 `基准 ¥X/天 · 剩余 ¥Y · 剩 N 天`
   - 进度卡：`本月已花 ¥x / ¥y` + 金进度条（**超支/预算不可行 → 满格 `semanticExpense`**）+ 百分比 + 构成 `收入 − 计划存款`；`预算 ≤ 0` 走「本月预算已不可行」文案（消化 T-10a 管理层备注：负天花板 + 零支出不再误报「已超支 ¥0」）
   - 今日行 `今日已花 ¥x · N 笔`；AI 卡位（`AI 分析与建议 / M2.0 上线`，无假数据）
   - **今日支出构成环形图**：外径 104 / 环宽 14（centerSpace 38 + section 14），中心「合计 ¥x」；图例右侧竖排最多 3 类 + 「其他」；**空态只一行「今天还没有支出」不画空环**
   - **引导态**（无预算）：Hero 换「先设置本月预算」卡 → 预算 sheet（收入 + 计划存款，数字键盘）+「沿用上月数值」一键（无上月记录则禁用）
   - **底部固定操作条**（`Scaffold.bottomNavigationBar`，内容区在其上滚动）：`记一笔` 金渐变实心（key `home_record_cta`）+ `明细` 金描边（key `home_ledger_cta`）
2. **IA 切换**：`app.dart` `home` 由 `QuickEntryPage` 改为 `HomePage`；新增 `budgetRepositoryProvider`；`QuickEntryPage` 降为二级（顶栏加返回键 `quick_back`），`回顾/资产/统计` 保留并加稳定 key（`quick_review/quick_assets/quick_stats`）
3. **同源切面/配色**：`StatisticsService` 新增 `CategorySlice` + `chartSlices(totals, {maxNamed})`（尾部合并为「其他」，`colorIndex` 即调色板位次）；`AppColors` 新增 `chartPalette/chartColor/chartSliceColor(neutral:)`；**统计页饼图改为同一函数 + 同一色映射**（行为不变，仍全量分类）。home donut 与 stats pie 数据/配色现由**单一函数**产出
4. **AGENTS.md 两处订正**（工单顺带项）：①工作流条款指向 `TICKETS_M2A.md`（注明 M1 存档）②UI 铁律「首页即速记键盘、无导航层」→「首页 = 分析页（A0），速记页为二级、[记一笔] 一键可达」
5. **测试**：新增 `test/chart_slices_test.dart`（5）+ `test/home_page_test.dart`（4，引导态/Hero 推导/超支文案/合并「其他」）；`test/widget_test.dart` 改为直接 pump 二级快记页（并断言 `quick_back`）；新增 `integration_test/t10b_home_test.dart`（四帧 + 固定底栏 + 月导航只读 + 同源图例断言 + 前置条件声明 + 自播种清理）
6. **受影响老 integration 按新 IA 更新**（导航改为 首页 →[记一笔]→ 二级页，或用稳定 key）：t03 / t04 / t05 / t09a / t09b / t09c / t09c2 / t09d；证据帧输出改落 `evidence/t10b/regression/`（**不覆盖原票 evidence**）

### 关键决策
- **按用户确认帧①落地顶栏**：帧里只有 `‹ › ⚙`，无「资产/统计」入口；故 `资产/统计` 仍由二级快记页顶栏进入（未自增首页图标）——此为 DESIGN §1 图示与§3/预审稿的不一致，已在「遗留」上报
- **历史月只读语义**：当前月用 `now` 计算实时额度；历史月用该月最后一天作 `asOf`（剩余=月末结余，`remainingDays=1`），预算编辑入口在历史月只提示不改数据
- **饼图「其他」用中性灰**：用户预审稿中「其他」画的是灰 `n1`，故 `chartSliceColor(neutral: true)` 走 `neutralChartScale`；命名切面仍按 `chartSlices.colorIndex` 取金阶——同源函数 + 同源色映射，禁彩虹
- **`明细` 为分阶段占位**：T-12 未开工，按钮按帧存在但点击只弹「明细页即将上线」snackbar（不放假页面、不自建范围外功能）
- **t09c 沉入断言改为自播种前提**：T-09E 已清空 dev 库，资产列表不再够长 → 断言前**播种 12 条资产**（收尾墓碑），而不是依赖历史累积数据（AGENTS 证据条款：先声明前提）
- **老 integration 的 finder 收紧**：被压栈的下层路由仍会被 finder 命中（非 Offstage），故 t09c 沉入/帧率拖动、t09c2 资产拖动与详情按钮计数全部**限定到可见页**（`find.descendant(of: 具体页)…`）

### 遗留问题 / 待管理层裁决
1. **DESIGN 文档内部不一致（T-11 用）**：§4.2/§7 明确「键面 Playfair 600 / 26px（用户裁决②-3）」，但 §8 仍写「键面用系统 sans（不许顺手改成衬线）」——T-11 开工前请管理层统一（本票未碰 T-11）
2. **IA 缺口**：DESIGN §1 图示把 `[资产]`/`[统计]` 画为主页分支，但用户确认的第①屏与 §3 顶栏只有 `‹ › ⚙` → 本票按帧实现，资产/统计经二级快记页可达；是否要在主页补入口（或随 T-12 明细页承载）请裁决
3. **t09e 未改未跑**：其断言 `find.text('记一笔')` 在新主页底栏仍成立，为避免覆盖 t09e evidence 未重跑；但文件内注释/reason 仍写「keypad home」已过时——建议下次触碰 t09e 时一并订正
4. **t09b 回归帧 01 与 04 md5 相同**（列表→详情→返回后的同一列表状态）；语义正确（同一状态同帧），非假证据，记录在案
5. **CPD 天数自然漂移**：t09d 由 459→460 天（日期跨天），数值随行演进非缺陷

### 下一步
- 等管理层验收 T-10b；通过后按序 **T-11 快记重设计（方向已定稿 B+C）** 或 **T-12 明细页**（管理层定序）

### DoD 证据
- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed（153）**，144 → **+9**（chartSlices 5 / home 4；widget_test 2 条随 IA 改写）
- **T-10b Windows 实跑四帧（Dart PNG，magic 89504e47，md5 全唯一）**：`01_onboarding 1bfa2878d01f` ｜ `02_budget_set 0ea7d4c5c762` ｜ `03_overspent 07fc568c0a5f` ｜ `04_donut_empty 9d77089fbfa1`（manifest `evidence/t10b/.t10b_frame_md5.txt`）
- **饼图与统计页同源断言**：单测 `chart_slices_test`（空/≤3/恰好3/>3 合并/全量=stats 路径）+ t10b integration 用 `StatisticsService.chartSlices(expenseByCategory(...), maxNamed:3)` 反查图例（餐饮/交通/购物/其他 + 金额）全中；5 类 → 4 切面且 `其他` 为 600 分
- **固定底栏任意滚动位置可见**：t10b 断言底栏**不在 ListView 内**（`find.descendant(of: ListView)` = nothing）、底沿贴屏幕底（673 vs 681，差 8px = SafeArea）、滚动 240px 后 `getRect(home_record_cta)` **逐值不变**；`T10B_FIXEDBAR record_bottom=673.0 screen=681.0`
- **受影响 integration（Windows 逐个单跑，全绿）**：t03 ✅（`DB_DRAFTS_BEFORE=0→AFTER_CREATE=1→AFTER_CONFIRM=0`）｜ t04 ✅（4 帧）｜ t05 ✅（3 帧）｜ t09a ✅（3 帧）｜ t09b ✅（5 帧）｜ t09c ✅（8 帧，`rise=40.8 opacity=0.600` 与历史验收同值）｜ t09c2 ✅（2 用例 6 帧，`confirm_haptic=ok`）｜ t09d ✅（2 用例 8 帧，`overlap=false`）；帧全部落 `evidence/t10b/regression/`，**原票 evidence 目录未被覆盖**（git status 仅新增 `evidence/t10b/`）
- **release APK**：`build/app/outputs/flutter-apk/app-release.apk` **66,253,368 字节（63.2MB）**，md5 `abe5a2e3d619ab69176f38f29d3b0b2a`；已复制桌面 `gringotts-T10b-release.apk`（仓库外，供实机目测新主页）
- **dev 库还原**：本轮实跑残留 live 13 行（tx 4 / assets 2 / photos 7）已按墓碑模型清理 → **live=0（分类 9 保留）**；备份 `gringotts.sqlite.pre-t10b-20260912-191255.bak`
- **执行成本如实记录**：integration 共跑 **11 次**（t10b 首次因底栏底沿断言容差失败→修正容差后重跑；t09c 首次因 dev 库清空后资产列表不够长、沉入断言失败→改自播种前提后重跑；其余 7 个脚本一次过）。两次失败均由**前提/断言假设**驱动、修完即绿，**零盲目重跑**

## 2026-09-12（管理层验收记录：T-10a ✅ 通过 —— 含管理层独立对抗审计 21/21）
- **五层验收**：
  1. 记录核对：commit `6733f65` 已 push，工作区干净
  2. 独立复验：flutter analyze → **No issues found**；flutter test → **All tests passed (144)**（116 → +28：引擎 + 仓储两套新测试）
  3. 源码级审查：
     - `BudgetEngine`（222 行全文）：**`_floorDiv` 自实现数学向下取整**（Dart `~/` 向零截断，负数会错——这个细节抓得准）✓；闰年用完整 400/100/4 规则 ✓；`remainingDays` 有除零防御（`max(1,…)`）✓；口径铁律 `_countsAsSpending = !isDraft && deletedAt==null && type==expense`（收入/转账/草稿/墓碑全排除）✓；无预算/墓碑预算 → 预算派生字段全 `null`（**不显示假数字**）✓；`spentRatio` 对 `budget ≤ 0` 有专用分支 ✓
     - `BudgetMonths` 表：UUID 主键 / `year_month` 唯一 / 整数分 / 三时间戳 / 墓碑；**派生值不落库**（budget = 收入−存款 始终现算）✓；`schemaVersion = 3`
     - 迁移：累积式 `if (from < 2)` / `if (from < 3)` 分支（V1 可一次升到 V3）✓；V2→V3 建表**无回填**（符合 spec：历史月份无预算是正常态）✓
     - `BudgetRepository`：`upsert` 事务内建/改 + **复活墓碑行（清 deletedAt）避免唯一键冲突**（边界考虑到位）+ 月份格式与非负断言 ✓
  4. **管理层独立对抗审计（隔离副本 + 自写 21 用例 → 21/21 全过）**：世纪闰年陷阱（**2100 非闰 / 1900 非闰 / 2000 是闰**——naive %4 实现必错处）· 十二月天数全查 · `remainingDays` 边界（day1=全月 / 末日=1 / 非法 day 防除零）· **负数数学取整**（−100÷3 = −34 而非 −33）· 正数永不进位（360001÷31=11612）· live 额度负值钳 0 · 口径三重排除 · 跨月隔离（8/31→9/1→10/1 三笔各归其月）· 空/墓碑预算 → null · **手算整月复核**（收入 5600 / 存款 2000 / 已花 2340 → 预算 3600、基准 120/天、剩余 1260、实时 63/天、比例 65%）· 超支钳制 · 收入<存款（负天花板）· 零预算两种比例分支 · 比例上下钳 · 月份键补零（含 `0999-03`）
  5. 仓储测试覆盖复核：8 条（就地更新 / 整数分含零 / getByMonth null / listMonths 时序且排除墓碑 / watchByMonth / softDelete 保留 raw 行 / **upsert 复活墓碑月** / **迁移 V2→V3 无回填且不破坏既有数据**）——覆盖到位
- **给 T-10b 的界面备注（非缺陷）**：`isOverspent` 在「收入 < 存款」（负天花板）且**零支出**时也返回 true——逻辑上成立（计划本身已破），但主页 UI 需给出可读文案（如「本月预算已不可行」而非「已超支 ¥0」），请 T-10b 注意
- **结论：T-10a 验收通过 ✅**。下一票：T-10b（主页 UI，**等用户过目五屏稿第①屏**）或 T-12（明细页，可并行）；T-11 等用户选定快记方向

## 2026-09-12（T-10a 执行层施工记录：预算数据层 + 纯函数引擎）
### 做了什么
1. **新表 `budget_months`**（`lib/data/app_database.dart`）：`id` UUID（`clientDefault(_newUuid)`）/ `year_month` TEXT **唯一**（`uniqueKeys`）/ `income_cents` INT / `savings_target_cents` INT / `created_at` + `updated_at` + `deleted_at` 墓碑；金额一律整数分
2. **迁移 V2→V3**：`schemaVersion` 2→3；`onUpgrade` 增 `if (from < 3) await m.createTable(budgetMonths);`（**无历史回填**，历史月无预算=正常态）；V1→V2 分支原样保留。`build_runner` 重生成 `app_database.g.dart`
3. **`BudgetRepository`**（`lib/data/repositories/budget_repository.dart`）：`upsert(yearMonth, incomeCents, savingsTargetCents)`（唯一月键 → 同月为 update 而非 insert；命中墓碑则**复活同一行**并清 `deletedAt`，绝不违反唯一索引）/ `getByMonth` / `watchByMonth`（T-10b 响应式）/ `listMonths`（升序）/ `watchMonths` / `softDelete`（墓碑）
4. **`BudgetEngine` 纯函数**（`lib/services/budget_engine.dart`，无 DB 依赖）：`monthKey`（`YYYY-MM` 补零）/ `isLeapYear` / `daysInMonth` / `remainingDays`（含今天）/ `budgetCents = income − savings` / `fixedDailyCents`（**向下取整**）/ `liveDailyCents`（向下取整 + **负值钳 0**）/ `spentCentsInMonth`（draft、收入、transfer、墓碑一律不计 = T-05 口径）/ `todaySpending`（今日金额+笔数）/ `compute(...) → BudgetSnapshot`（**无预算记录时 budget/fixed/remaining/live 四字段为 null**，实际支出照常返回；含 `isOverspent` 与 `spentRatio` 供 T-10b 进度条）
5. **边界单测全套**（`test/budget_engine_test.dart` 20 条 + `test/budget_repository_test.dart` 8 条，**+28 条**）：闰年（2024/2023/2000/1900）/ 30-31 天月 / 首中末日与 2 月闰年末日 / 跨月重置 / 超支负值 / `budgetCents ≤ 0` 防御（0 与赤字）/ draft+收入+transfer+墓碑不计 / 编辑后即时重算 / 无预算返回 null / 墓碑复活 upsert / V2→V3 迁移（真实 DDL 降级重开验证）

### 关键决策
- **“向下取整”实现为数学 floor**：Dart `~/` 向零截断，故 `_floorDiv` 显式对负数向下取（`-100 / 3 → -34` 而非 `-33`），由单测锁定——口径不靠默认运算符的隐患猜
- **墓碑月份的两种语义各司其职**：引擎层把 `deletedAt != null` 的预算当“无预算”（不显示假数字）；仓储 `upsert` 命中同月墓碑则复活该行——unique `year_month` 在墓碑模型下永不冲突
- **快照字段可空边界**：`BudgetSnapshot` 只让**预算派生**字段可空，`spentCents`/`todaySpentCents` 永远有值——引导态也能显示“本月已花”，但绝不显示假的每日额度
- **引擎不碰 DB**：以 `List<Transaction>` 入参，复用 T-05 口径且可纯单测；T-10b 用既有 `TransactionRepository.confirmedExpenseCentsInRange(start,end)` 取月区间即可，无需新查询

### 遗留问题 / 边界
- **本票零 UI 变更**：未动 `app.dart`/`main.dart`/任何 page（provider 注入与首页由 T-10b 承接，避免与本票拆分的边界混淆）
- **未重建 release APK**：本步无 UI/行为变更，APK 归 T-10b UI 落地后统一重建
- **dev 库**：t03 实跑触发真实 V2→V3 迁移（`user_version 2→3`、`budget_months` 建成空表、既有 48 行原样）；跑后已把 t03 新增的 1 行按墓碑模型清理，恢复 live=0 / categories 9（备份 `gringotts.sqlite.pre-t10a-20260912-151157.bak`）

### 下一步
- 等管理层验收 T-10a；通过后 **T-10b 主页 UI**（等用户过目 `design/MAIN_preview.html` 第①屏后开工）——需在 T-10b 接线：`budgetRepositoryProvider` + 当月预算 `watchByMonth` + 月区间支出流 → `BudgetEngine.compute` 单一真相源

### DoD 证据
- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed（144）**，116 → **+28**（引擎 20 / 仓储 8）
- **受影响 integration（Windows 实跑）**：`t03_flow_test` → **All tests passed**（`DB_DRAFTS_BEFORE=0 → AFTER_CREATE=1 → AFTER_CONFIRM=0`）——证明真实 V2 开发库经 V3 迁移后 app 正常启动且核心记账流不受影响；本步无 UI 变更故**不采帧**（语义优先单测，AGENTS.md 证据条款）
- **迁移实证（复算，非重跑）**：迁移后 dev 库 `PRAGMA user_version=3`、`sqlite_master` 含 `budget_months`、该表 0 行（无回填）、transactions 48→49（t03 新增）后已墓碑、categories 9 live 未动

## 2026-09-11（管理层验收记录：T-09E ✅ 通过 —— M1.0 功能与品牌全部验收完成）
- **五层验收**：
  1. 记录核对：三个 commit（`a8e9cbc` 主体 / `5e3be39` 品牌审阅表 / `ddd37e3` 完工记录）对版，已 push，工作区干净
  2. 独立复验：flutter analyze → **No issues found**；flutter test → **All tests passed (116)**（113 → +3）；APK 18:12 重建（66,073,000 字节）
  3. 源码级审查：`lib/ui/splash.dart`（SplashGate 做成 **overlay 而非路由**——首页即键盘铁律不破、品牌帧结束自移除、reduce-motion 整帧跳过）✓；`launch_background.xml` 改 `@color/ic_launcher_background`（**修掉原 v21 白闪**）✓；`tool/gen_brand_assets.py` 按**墨迹**而非画布取尺寸（墨迹占比实测 0.660/0.820 符合 66% 安全区）✓；**N1 `fullJson` 已删除**（全库 grep 0 命中）✓；AGENTS.md 过时表述已订正 ✓
  4. **独立 integration（管理层亲跑 t09e_brand_test）**：All tests passed；**确定性数值逐位一致**——`fraction=0.380`（258.8/681.0，38% 精确）✓ `canvas=#ff0c0b09` ✓ `wordmark=Gringotts font=PlayfairDisplay size=28.0` ✓ `hold=700ms fade=400ms splash_removed=true home=记一笔` ✓；**我跑出的帧 md5 与提交证据帧完全一致（45da58b2d03f）**；重跑后已 `git checkout` 还原证据
  5. **品牌资产入包实证（管理层解包核对）**：release APK 资源经 AGP 重命名（`res/as.png`、`res/o-.png`），**md5 逐字节指纹**证明 `ic_launcher_foreground.png` ≡ `res/as.png`（10f552b1aba8）、`ic_launcher.png` ≡ `res/o-.png`（24762c8cf290）；自适应 XML 含 `foreground`/`background` 字符串池 ✓；UI 目检：mipmap 全尺寸黑底金徽标、自适应透明底、48px 仍可辨、无拉伸无白边；启动帧暖黑无白闪 ✓
  6. **全量回归（执行层 9/9 全绿，管理层核对汇总与逐文件日志）**：t03/t04/t05/t09a/t09b/t09c/t09c2/t09d/t09e 全部 exit=0；**含 t09b 第二处 ensureVisible 段复跑通过（T-09C2 遗留关闭）**
  7. **profile 帧率采样（真实证据）**：三相位（首页键入确认/资产滚动/详情 Hero）build avg 0.95–1.12ms、raster avg 0.96–1.20ms、p99 最高 8.8ms、**missed frames = 0**——从「debug 耗时当证据」彻底转为 profile 数据
  8. **dev 库清理合规**：仅墓碑（行总数不变）、**先落时间戳备份**、categories 9 条 seed 保留不动 ✓
- **观察项（转 M1.1 / 用户裁决）**：
  1. **启动画面「Gringotts」出现两次**（徽标内含 wordmark + 下方独立 wordmark）——观感冗余，两选项：裁掉徽标内文字只留龙 G 标 / 去掉下方独立 wordmark；**归用户实机目测裁决**
  2. **照片孤儿文件**：dev 库行已墓碑，`gringotts/photos/` 余 46 个无引用 hash 文件（DB 只存路径）；清理无工单授权 → 交 M1.1 决定是否加文件 GC
  3. **证据帧被回归重跑覆盖**（t09a~t09d 帧 md5 与各轮验收记录旧值不同，因 dev 库内容变化而非代码变更）→ 约定：回归重跑须落 `evidence/regression/`，不得覆盖各票证据目录；M1.1 落实
  4. Android 自适应图标圆形蒙版极端情况可能擦到墨迹尖端（66% 恰为边界）→ 用户实机目测
  5. profile 数值为 Windows 桌面，不等于 Android 真机 → 真机 60fps 判定权归用户
- **结论：T-09E 验收通过 ✅。M1.0（T-01~T-09E）功能与品牌全部验收完成**；最终判定权移交用户实机 APK 目测。

## 2026-09-11（T-09E 执行层施工记录：品牌收尾 + 全量回归 + M1.0 完工报告）

### 做了什么
1. **启动画面**：新增 `lib/ui/splash.dart`（`SplashGate`）——canvas 纯色 `AppColors.canvas` + 品牌徽标 **38%**（短边）+ Playfair 600 wordmark「Gringotts」（平涂 `goldAccent`，不用渐变，护住金色纪律）；`MaterialApp.builder` 挂载 = **表现层 overlay**：速记键盘从第一帧就在位（首页即键盘、零导航层），品牌帧 700ms 停留 + 400ms easeOut 淡出后**自移除**；reduce-motion 下整帧跳过（§5 退化语义）。Android 原生侧同色兜底：`launch_background.xml`（drawable + drawable-v21，**修掉原 v21 用 `?android:colorBackground` = 白闪**）+ `values/values-night` 的 `NormalTheme.windowBackground` 均改 `@color/ic_launcher_background`（#0C0B09）
2. **Android 自适应图标 + 遗留图标**：新增 `tool/gen_brand_assets.py`（PIL，可复跑）从 `brand/gringotts-logo.png` 生成 10 张 mipmap——legacy `ic_launcher.png`（48/72/96/144/192，canvas 底板 + 徽标 66%）与自适应前景 `ic_launcher_foreground.png`（108/162/216/324/432 透明底板 + 徽标 **66% 安全区**）；新增 `mipmap-anydpi-v26/ic_launcher.xml`（`<adaptive-icon>`：`@color/ic_launcher_background` + `@mipmap/ic_launcher_foreground`）与 `values/ic_launcher_background.xml`
3. **Windows ico 多尺寸**：`windows/runner/resources/app_icon.ico` 重生成，**7 帧 16/24/32/48/64/128/256**（ICONDIR 实测 count=7，各帧 32bpp），canvas 底板 + 徽标 82%
4. **全量回归**：新增 `tool/run_regression.sh`，**9 个 integration 脚本逐个单跑**（t03/t04/t05/t09a/t09b/t09c/t09c2/t09d/t09e）→ **9/9 全绿、failures=0**；t09b **第二处 ensureVisible 段（卖出前回列表再进详情，源码 118 行）复跑通过**（T-09C2 遗留关闭）
5. **dev 库清理**：新增 `tool/clean_dev_db.py`（先 dry-run 后 `--apply`）——**墓碑** 48 transactions / 21 assets / 39 asset_photos，**categories 9 条 seed 一律不动**（app 数据，非测试数据）；写入前落时间戳备份
6. **文档订正 + N1**：AGENTS.md「UI 铁律」T-08 过时表述订正为「T-08 已退役并入 T-09A，黑金 tokens 为当前唯一皮肤」；`ExportService.fullJson` 死代码**删除**（grep 全库 0 命中）
7. **profile 模式帧率采样**：新增 `test_driver/perf_driver.dart` + `integration_test/perf_scan_test.dart` + `tool/perf_report.py`，`flutter drive --profile -d windows` 采三段真实交互（首页键入确认 / 资产列表滚动 / 详情 Hero 翻页）
8. **release APK 重建** + 本完工报告

### 关键决策
- **启动画面做成 overlay 而非路由**：不动导航结构（首页即键盘铁律），键盘始终在树内 → 既有 9 个 integration 脚本全部无需改断言即通过；品牌帧结束后节点自移除，不会在返回/换页时重播（单测锁定「每次 App 实例仅一次」）
- **品牌帧的证据用「同 widget + 延长 hold」采集**：真实时钟下 700ms 停留会被 pumpWidget/资源解码开销吃掉（run#1 实测品牌帧已消失），故帧采集用 `SplashGate(holdDuration: 30s)`（**只改时长**，底板/资源/38% 几何/wordmark 全部生产值），生产时序另用 `GringottsApp` 断言（hold=700ms/fade=400ms/splash_removed）——两段合一才是完整证据
- **图标按「墨迹」而非「画布」取尺寸**：源 PNG 带大片暗晕（alpha≥40 占 81%，亮金墨迹仅 848×912），若按整张画布缩放会让徽标视觉偏小；脚本按「不透明且亮度≥60」裁出金墨迹再居中缩放到目标比例 → 实测 ink fraction = **0.660**（legacy/自适应）/ **0.820**（ico），符合「66% 安全区」
- **dev 库清理只墓碑不退物理删除**（AGENTS.md 数据铁律），且只动 transactions/assets/asset_photos——categories 是 app seed，动了会破坏 app
- **帧率只认 profile**：debug 帧耗时不再作证据（历史 28.1ms/样本 = debug 构建 + 帧内 drag 派发成本）；本票只报 profile 数值，真机 60fps 判定权归用户实装 APK

### 遗留问题（非缺陷，交管理层/用户）
- **照片文件残留**：dev 库行已墓碑，`.../gringotts/photos/` 仍有 46 个 hash 命名文件成为孤儿（DB 只存路径，无引用即不可见）。未删：AGENTS.md「禁止物理删除」针对数据行，文件清理无工单授权，**交管理层裁决是否随 M1.1 加文件 GC**
- **证据帧被本轮回归覆盖**：t09a/t09b/t09c/t09c2/t09d 的帧已由本轮回归重跑覆盖，md5 与各轮验收记录中的旧值不同——**原因是 dev 库内容变化（同一脚本渲染的列表/数字不同），不是代码变更**；各票 WORKLOG 旧 md5 记录保留可查
- **安卓 icon 的圆形蒙版边界**：自适应前景墨迹长边恰好 66%（= 71.3dp），圆形蒙版最极端情况下可能擦到徽标尖端；已按工单数字执行，**实机观感归用户目测**
- profile 采样为 **Windows 桌面**数值，不是 Android 真机数值（桌面 ≠ 手机 GPU/热态）

### T-09 完工报告（M1.0 品牌收官）

**DESIGN_T09 §8 逐页对照**（证据帧见各票 evidence 目录，本轮全部重跑生成）

| §8 页面 | 规格要点 | 证据 |
|---|---|---|
| 1 速记首页 | wordmark 衬线金渐变小字 / 金额 display 56 tabular / 混合输入 elevated / 键盘键按下 0.97 / 确认键金渐变 + sheen | t09a_01、t09c_01/02（按下帧）、t09c2_02（sheen 中帧）、t09e_02 |
| 2 回顾页 | 日期头 eyebrow / draft 卡 surface / 7 天灰显 / 滚动物理 A | t09c_08 |
| 3 资产列表页 | 净值看板 tabular + 三 pill / tile 0.98 + Hero 进详情 / CPD 金容器徽章 / 服役进度条 | t09a_02、t09c_03（stagger 中帧）/04/05（看板沉入）、t09d_01→07（封面切换） |
| 4 资产详情页 | §6 全项 + 视差 B + 成组入场 D | t09b_02/03/05、t09c2_04（Hero 接力）、t09d_06（编辑后） |
| 5 统计页 | 净结余卡（负值 semanticExpense）/ 双线趋势 + 金阶 donut / 导出 hairline 金描边 outline | t09a_03、t09c_06/07 |
| 6 启动画面 | canvas 纯色 + 徽标 38% + Playfair 600 wordmark；Android 自适应（前景 66% / canvas 底）+ Windows ico 多尺寸 | **t09e_01（本轮新增）**、brand_assets_manifest.json（11 资产）、APK res 10 PNG 实测 |
| 7 应用内图标 | 1.8px 描边 24 网格线性单色（未激活 inkSecondary / 激活 goldAccent） | 各帧导航/tab 图标（T-09A 落地，本轮回归帧复核） |

**动效清单对照**（§4 基础 + §5 高级）

| 动效 | 规格 | 证据 |
|---|---|---|
| count-up spring 400ms 临界阻尼 | 净值/净结余，进入与数值变化触发 | 单测数值断言（T-09C2：settled=13089900）+ t09c2_03 中帧 |
| 确认键 sheen 600ms 一次性 | 禁循环，reduce-motion 跳过 | t09c2_02 + 一次性/尺寸三段单测 |
| chip 选中 150ms | goldContainer/onGoldContainer | t09c2_01 + 时长单测 |
| A 惯性滚动 physics | 资产/统计/回顾三页统一 | t09c_05/07 |
| B 视差 0.5x + 看板沉入（≤48px） | 详情 hero + 净值卡 | t09c_05、本轮 perf detail_hero 相位 |
| C TouchedScale 微缩放 + 触感 | 全 app 复用，reduce-motion 触感保留 | t09c_02、T-09C2 P4 单测 |
| D 成组入场 60ms stagger | 列表 fade+12px | t09c_03 |
| E Hero 接力 350ms easeOutCubic | 列表↔详情双向 | t09c2_04、t09b_02/04 |
| 无障碍 | disableAnimations 全退化 + 触感保留（**含启动画面跳过**） | t09c2_05/06 + 本轮 splash reduce-motion 单测 |

### DoD 证据
- `flutter analyze` → **No issues found**（最终态，含新文件/integration/perf 脚本）
- `flutter test` → **All tests passed（116）**，113 → +3（品牌帧生命周期与 38%/Playfair/纯色断言、reduce-motion 跳过、每实例仅一次）
- **全量回归（Windows 实跑，9 脚本逐个单跑）**：`failures=0 of 9`，明细 `evidence/t09e/regression/.regression_summary.txt`；**32 帧全 Dart PNG + 每票 md5 全唯一**（t09a 3/3、t09b 5/5、t09c 8/8、t09c2 6/6、t09d 8/8、t09e 2/2），帧 md5 汇总 `evidence/t09e/regression/.regression_frames_raw.txt`
- **启动画面证据（Windows 实跑）**：`T09E_LAUNCH hold=700ms fade=400ms splash_removed=true home=记一笔`；`T09E_BRAND_FRAME canvas=#ff0c0b09 window_shortest=681.0 logo_edge=258.8 fraction=0.380 wordmark=Gringotts font=PlayfairDisplay wordmark_size=28.0 logo_decoded=true`；`T09E_BRAND_ASSET bytes=1581774 magic=89504e47`（= 源文件字节数，证明资产真进 bundle）；品牌帧 md5 **45da58b2d03f**——两次独立运行**逐字节一致**（纯品牌帧不含 DB 内容，可复现）
- **品牌资产（11 项，可复跑脚本 + manifest）**：`tool/gen_brand_assets.py` + `evidence/t09e/brand_assets_manifest.json`；ink fraction 实测 0.660（legacy 48–192px / 自适应 108–432px）、0.820（ico）；透明度实测 legacy/ico 角像素 = canvas (12,11,9)，自适应前景角像素 alpha=0（蒙版安全）；ico ICONDIR count=7
- **profile 帧率（`flutter drive --profile -d windows`，`tool/perf_report.py`）**：`evidence/t09e/profile_frame_timings.json`

| 相位 | 帧数 | build 均值 | build p99 | raster 均值 | 超 16.67ms 预算 |
|---|---|---|---|---|---|
| home_keypad_confirm | 10 | 1.081ms | 2.154ms | 1.196ms | **0 / 0** |
| assets_scroll | 21 | 0.952ms | 8.815ms | 1.111ms | **0 / 0** |
| detail_hero | 15 | 1.117ms | 4.679ms | 0.955ms | **0 / 0** |

  （前提声明：`PERF_PRECONDITION live_assets=21 target=T09D资产802935 photos_at_target=4` —— 选中**有照片**的资产，保证 Hero PageView 相位真实可测）
- **release APK**：`build/app/outputs/flutter-apk/app-release.apk` **66,073,000 字节（63.0MB）**，md5 `5c26de355ebd265c176f935f704c9879`；包内实测 `res/` 10 个 PNG（= 生成的 10 张图标，资源收缩改名）+ `resources.arsc` + 品牌资产 1,581,774 字节 + Playfair 两字体（**图标 XML/色资源通过 AAPT 校验**，否则 release 构建会失败）
- **dev 库清理实证**（`evidence/t09e/development_db_cleanup.json`，写入后另开只读连接复验）：transactions 48→**live 0**（48 墓碑）、assets 21→**live 0**（28 总）、asset_photos 39→**live 0**（42 总）、categories **9 live 未动**；备份 `gringotts.sqlite.pre-t09e-20260911-180934.bak`
- **N1/文档**：`fullJson` grep 0 命中；金色 gradient 实测 3 处 `LinearGradient` = **2 处金**（首页 wordmark ShaderMask + 确认键填充，均消费 `AppColors`）+ 1 处白 alpha sheen（非金）；tokens 外硬编码色值 **0**
- **执行成本如实记录**：本轮 integration 共跑 **13 次**（品牌 2 + perf 2 + 回归 9）。两次失败均由**脚本假设**驱动、修完即绿：① 品牌帧 run#1「真实时钟下 700ms 停留被启动开销吃掉」→ 改延长 hold 采集 + 生产时序另测；② perf run#1「选中的首个资产无照片 → 详情无 PageView」→ 改「按 DB 前提挑有照片资产」。**零盲目重跑**

### 下一步
- 用户目测拍板（M1.0 最终验收权在用户）：实机装 release APK 看 3 件事——① 桌面图标（自适应 + 圆形蒙版是否吃边）② 冷启动品牌帧观感 ③ 滚动/键盘实感帧率
- 验收通过后：管理层做 WORKLOG 归档整理（备忘录已记）+ M1.1 候选（D1 已关；剩 dev 照片文件 GC、编辑 sheet 状态字段、真机帧率）

> 本票 2 个 commit：`a8e9cbc`（主体：splash + 图标 + 回归 + 清理 + 报告）+ `5e3be39`（后补的品牌资产审阅图 `tool/brand_preview.py` / `evidence/t09e/brand_assets_preview.png`，供用户目测）。APK 已复制到桌面 `gringotts-T09E-release.apk` 便于实机安装（仓库外，不入 git）。

## 2026-09-11（管理层验收记录：T-09D ✅ 通过，附 2 项观察）
- **五层验收**：
  1. 记录核对：commit `8008d60` 对版，已 push；工作区干净
  2. 独立复验：flutter analyze → **No issues found**；flutter test → **All tests passed (113)**（108 → +5）
  3. 源码级审查：`nextSort`（活行最大 sort+1，空表归 0）✓；`setCover`（事务内交换 + 相等 sort 防御分支 `cover.sort−1` + 返回改写行数）✓；**`displayPaths`（rows 优先、legacy 仅无行兜底）= 列表与详情共用的单一真相源** ✓；照片三操作 UI 齐全（相册/拍照增、缩略图 `onDelete`→`softDelete` 墓碑、`设封面`）；AGENTS.md 证据条款三条落档 ✓
  4. **独立 integration（管理层亲跑）**：All tests passed（2 用例）；**确定性数值逐位一致**：`purchased=2025-06-10 days=459 cpd=1590 label=¥15.9/天`、`DELETE live=3 raw_rows=34 tombstoned=01ca9a1a`（墓碑语义：raw 行留存）、`SNACKBAR behavior=floating inset=88.0 bar_bottom=593.0 cta_top=609.0 overlap=false`（零重叠）；数学复核：含头含尾 459 天 ✓、1590 分/天 × 459 天 = ¥7,298.10 自洽 ✓；**重跑后已 `git checkout` 还原证据帧**（8 帧全 Dart PNG + md5 唯一 8/8）
  5. **UI 目检**：编辑 sheet 全项齐（购买日期行 / 照片区含「封面」标注与「设封面」入口 / 三类选择 / 金渐变保存键）；列表 tile 封面 + CPD 徽章 ¥15.9/天 与数值读回一致 ✓；**目检同时看到 dev 库累积的测试资产**（T09B/T09C2/T09D 各轮产物）——正对应 T-09E 清理项
- **本票亮点：DoD 链路逼出两个既有真 bug**：①详情页 hero 墙把 `snapshot.data` 丢成空表 → **创建后新增的照片永远不显示**；②列表缩略图只读 legacy `photo_path` → **设封面在列表零效果**（即 DoD「列表主图更新」原本不可达）。两处统一到 `displayPaths()`——修法正确
- **行为肯定**：AGENTS.md 写入被系统防护拦截（授权超时）时**没有绕过、没有重试，等用户当场批准后才落盘**——对防护边界的正确尊重（管理层 session 同受此约束）
- **观察项（非缺陷，转 T-09E）**：①dev 库测试资产继续累积（本轮管理层复跑又 +2 行，raw_rows 30→34），T-09E 统一走墓碑清理；②AGENTS.md「UI 铁律」仍写「T-08 将整体换肤」属过时表述（换肤已在 T-09A 完成），T-09E 订正
- **管理层备忘**：WORKLOG 已增长至 ~690 行 / 90KB——M1.0 收官（T-09E 验收后）由管理层做一次归档整理（旧轮次移入 `WORKLOG_ARCHIVE.md`，主文件保留近若干轮 + 全部里程碑决策），保持新 session 的必读量恒定
- **结论：T-09D 验收通过 ✅**。下一票 T-09E 品牌收尾（M1.0 收官票）

## 2026-09-11（T-09D 执行层施工记录：编辑补完 — 购买日期 + 照片增删/设封面 + snackbar + 证据条款）

### 做了什么
- **购买日期编辑（P1 必做）**：编辑 sheet 重写为 `_EditAssetSheet`（ConsumerStatefulWidget），新增日期行（`Key('edit_date_button')` → Material `showDatePicker`，firstDate 2000 / lastDate 今天）；保存走既有 `AssetRepository.updateAsset`（刷新 `updated_at`），CPD 与持有天数由**同一个 `CpdCalculator`** 派生（无第二套算法），详情页数字随行流即时刷新
- **照片管理（P2 必做）**：编辑 sheet 照片区 = 相册（`pickMultiImage`）/ 拍照（`pickImage`）+ 缩略图横排；复用 `PhotoService.saveCompressed`（压缩 + sha256 内容命名）与 `asset_photos` 仓储。仓储新增 `nextSort()`（新增 = 末位 sort）与 `setCover()`（设封面 = sort 交换，含「相等 sort」防御分支：新封面压到旧封面之下）；删除沿用既有 `softDelete`（墓碑）。**未做拖拽排序**（工单负范围）
- **列表主图 = asset_photos 首图**：新增 `AssetPhotoRepository.displayPaths()` 作为唯一真相源 → 列表 tile 新增 `_AssetCover`（StreamBuilder 读 cover）＋详情 hero 墙同源调用；`_AssetTile` 增 `photoRepo` 依赖
- **顺带项 snackbar（T-09C2 裁决）**：新增 token `AppSpacing.snackBarCtaInset = 88`；速记页 snackbar 显式 `SnackBarBehavior.floating` + 底部 margin（位于确认键上方）；CTA 加 `Key('confirm_cta')` 供几何断言。采用**首选方案**（floating + margin），未启用备选（延迟 250ms）——理由见「关键决策」
- **顺带项 AGENTS.md**：「证据脚本先声明前提」条款落档（元素可见性 ensureVisible / DB 状态前置断言 / 语义优先单测）。该写入先被系统防护拦截（等待授权超时），**经用户当场批准后落盘**（未绕过、未重试）
- 新增 `test/asset_edit_test.dart`（5 条）+ `integration_test/t09d_edit_flow_test.dart`（2 用例）；`pubspec.yaml` dev_dependencies 增 `image_picker_platform_interface: ^2.11.1`（测试用 fake picker；transitive → dev，版本零漂移）

### 收尾中发现并修掉的真 bug（既有实现缺陷，由本票 DoD 链路暴露）
1. **详情页 hero 墙丢弃照片流**：`_DetailBody.build` 的 `StreamBuilder` 把 `snapshot.data` 丢成 `const <AssetPhoto>[]` → 详情 hero 只显示 legacy `assets.photo_path` 单张，**创建后新增的第 2..n 张照片永远不显示**。修法：喂真实 snapshot，统一走 `displayPaths`
2. **「首图 = 主图」未落到列表**：列表缩略图只读 legacy `photo_path` → **设封面在列表零可见效果**，DoD「列表主图更新」本不可达。修法：`_AssetCover` 读 asset_photos（sort 最小），legacy 仅在**无行**时兜底
- 两处均为 T-09D 工单语义（照片增删/设封面 + 列表主图更新）的必要前置 → 属修 bug，不属扩范围

### 关键决策
- 照片操作**即时落库**（增/删/设封面各自立刻走仓储），不做「暂存 → 保存时统一提交」：工单明写「删除 = 墓碑 / 设封面 = sort 交换」，即时语义与仓储动作一一对应，sheet 内 StreamBuilder 直接反映真实 DB
- 列表主图与详情 hero 墙**共用一个 `displayPaths()`**：两处永不发散；legacy photoPath 仅作无行兜底（顺带消除 T-09B 遗留的「同图重复两次」路径）
- snackbar 选首选方案而非备选：`floating` 是全 app 一致的（tokens 主题层），仅**下边距**按页不同（只有速记页有底部 CTA）——不构成「与其它页一致性冲突」，故不触发备选（延迟 250ms）
- 假 picker 走官方注入点 `ImagePickerPlatform.instance`：integration 里真的跑「字节 → 压缩 → sha256 命名 → 入库」全管线，不 mock 自己的业务代码

### 遗留问题（非阻塞，交管理层裁决）
- **证据脚本观察（非缺陷，记录在案）**：PhotoService 的 sha256 去重只对「同一份输入字节」成立。假 picker 交出的文件本身已是压缩产物（jpg），再压一次 = 二次编码 → 新 hash。真实链路（相册原图 → 压缩一次）不受影响；但**把本 app 导出的照片再导入会产生第二份文件**（语义可接受，未改代码）
- dev 库残留：本轮两次运行播种的 `T09D资产*`（1 个 abort 运行未清理）+ 速记 draft，归 T-09E 清理
- 编辑 sheet 未含「状态」编辑（退役/卖出仍走操作区按钮）——工单未要求，未自作主张扩范围

### 下一步
- 等管理层验收 T-09D；验收后 T-09E（品牌收尾 + 全量回归）

### DoD 证据
- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed（113）**，108 → +5（购买日期 → CPD/持有天数重算 + `updated_at` 刷新；照片新增落末位；删除墓碑语义（raw 行留存）；设封面 sort 交换精确值；displayPaths 兜底）
- integration（Windows 实跑，`flutter test integration_test/t09d_edit_flow_test.dart -d windows`）→ **All tests passed**（2 用例）；**8 帧全 Dart PNG（magic 89 50 4E 47 逐帧核验）+ md5 全唯一（8/8）**，清单见 `evidence/t09d/.t09d_frame_md5.txt`：
  - 01_list_cover_before 264fb5efe41d ｜ 02_edit_sheet 7bc6afbad34f ｜ 03_date_picked c52e19e2d866 ｜ 04_photos_added dcffac475bcc ｜ 05_cover_swapped 82660a86e5dd ｜ 06_detail_after_save 4bac9281cc3b ｜ 07_list_cover_after 43abe77d7923 ｜ 08_snackbar_above_cta 22c6dfd1679d
- **链路断言（工单要求：改日期 + 加照片 + 删照片 + 设封面 → 列表主图更新）**，均为 UI 操作后从 DB 读回：
  - 改日期：`T09D_CPD purchased=2025-06-10 days=459 cpd=1590 label=¥15.9/天`（730000/459 = 1590.4 → 1590，同源 CpdCalculator）且 `updated_at` 断言刷新
  - 加照片：`T09D_ADD rows=0,1,2,3 seeded=[0:5a7717b6,1:41119c9e] added=[2:b62ae66f,3:8ad4de1d]`（新增落末位，前两位原地不动）
  - 删照片：`T09D_DELETE live=3 raw_rows=30 tombstoned=8ad4de1d`（live 排除、raw 行仍在且 `deleted_at` 非空 = 墓碑语义）
  - 设封面：sort 表 `{photoB:0, photoA:1, added:2}`（精确互换，未整体重排）
  - **列表主图更新**：返回列表后 `asset_cover_<id>` 的 `FileImage` 路径 before=seedA → after=seedB（列表缩略图跟随新封面，且 legacy photoPath 不干扰）
- **snackbar 非遮挡（几何实证）**：`T09D_SNACKBAR behavior=SnackBarBehavior.floating inset=88.0 bar_bottom=593.0 cta_top=609.0 overlap=false`（snackbar 下沿 593 < 确认键上沿 609 = 零重叠，sheen 不被遮）；同时断言 `margin` 等于 token（非魔法数字）
- **执行成本如实记录**：本票 integration 共跑 **2 次**。run#1 失败由「新增照片路径断言过严」驱动（假 picker 二次编码 → 新 hash，属**断言假设错误**而非代码缺陷），run#2 修断言后全绿——**零盲目重跑**（期间无代码改动即重跑的行为）
- 证据脚本前提声明（AGENTS.md 新条款本票首次生效）：全程 tap 前 `ensureVisible`；播种行/照片读回断言后才交互；脚本收尾墓碑清理自己播种的资产

> 📦 更早轮次（T-01 ~ T-09C2 的全部验收与施工记录，含 D2 事故处置与 T-06b 返工）已归档至 `WORKLOG_ARCHIVE.md`——需要追溯历史时再读。
