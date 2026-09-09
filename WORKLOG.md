# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。
> ⚠️ 并发写入约定：追加前先重新读取文件最新版，在头部插入自己的段落，不要重建文件横幅；管理层 patch 前同样先重读。

## 2026-09-09 00:30（T-03 执行层施工记录）

### 做了什么
- Design tokens（lib/ui/tokens.dart，T-03 起强制）：AppColors 黑金色板 / AppSpacing 4pt 网格 / AppRadius / AppFont 字阶 + buildAppTheme()；app.dart 与速记页/回顾页组件全部改走 tokens，零硬编码色值字号
- 管理层增补 A（混合输入 + A1 修复）：
  - SmartParser 金额 regex 扩展支持前导点形式，_toCents 前导点归一化（.5 → 0.50 → 50 分）；.5 纯金额不再漏入商户字段
  - 速记页新增混合输入框（hint：瑞幸 15 / 15.5 午餐 / .5），走 SmartParser 全链路，金额/商户/类别建议一体
- 管理层增补 B（收入模式）：支出/收入 SegmentedButton（默认支出）；收入不套时段预填、不触发午餐识别，类别仅 chip 手选；确认文案「已入账」
- T-03 工单本体：
  - 首页角标「今日 N 笔待完善」（金底 pill，0 笔不渲染；watchTodayDraftCount 流驱动）
  - 回顾页 ReviewPage：watchDrafts 按天分组（手动中文周几格式化，弃用 intl zh_CN — 未初始化 locale 会炸）、批量补类别 Dropdown + 确认 N 笔、超 7 天灰显（Opacity 0.45 + 超 7 天 标签，不删）
  - repository 增补：watchDrafts / watchTodayDraftCount / confirmedExpenseCentsInRange（T-03 统计口径用例）/ updateFields / watchRecent / distinctMerchants / merchantCategory
- 键盘物理键支持（0-9/小键盘/Backspace/Esc/Enter）— Windows 实跑可键盘驱动，移动端不受影响
- 测试：新增 6 条 A1 前导点用例 + 4 条 T-03 统计口径用例（draft 不进当日合计/确认后进、今日 draft 计数口径、超 7 天 draft 保留、收入不预填）+ integration_test 全链路（键盘→确认→角标→回顾→勾选→补类→确认→DB 流 12→13→12 断言）

### 关键决策
- intl zh_CN 陷阱定位：DateFormat 中文 locale 在未 initializeDateFormatting 平台抛异常，导致回顾页 _DayHeader 渲染崩溃、draft 列表静默消失（integration test 首轮 Multiple exceptions 线索）。改手动字符串格式化，移除 intl 依赖点
- integration test 用 UncontrolledProviderScope + repo 流断言替代 UI 像素断言（ListView 懒构建导致 find.byType(Checkbox) 只数到视口内 9/12，流断言才可靠）
- 回顾页空态文案「没有待完善的记录」；确认转正式后流自动刷新（drift watch 全自动）
- widget_test fake 补齐 4 个新 repo 方法签名

### 遗留问题
- integration_test 目录的测试不进 flutter test 常规跑批（Windows 需 -d windows 单跑）；管理层验收可用 flutter test integration_test/t03_flow_test.dart -d windows
- DB 现存 12 条历史 draft（各轮实跑产物）不影响验收；正式使用可在回顾页批量确认
- flutter_test 的 fake-async 与 integration_test 的真实时钟互斥，两套测试并存正常

### 下一步
- T-04 资产档案页（A1+B8）：列表 + 净值看板 + 录入（照片压缩+hash）+ CPD + 变现复盘

### DoD 证据
- flutter analyze → No issues found
- flutter test → All tests passed (63)
- integration test → 00:14 +1: All tests passed（全链路含 DB 流断言）
- Windows 实跑：.t03_final_home.png 显示「今日 10 笔待完善」角标 + 混合输入框 + 支出/收入切换 + 高频餐饮 chip + 12 键键盘
- DB 验证：4 条历史 draft 已转正式（category=餐饮 9698ccb7…）证明 draft→正式管线真实生效
- Android release APK：app-release.apk (54.7MB) 构建成功

---

## 2026-09-08（管理层记录：收入功能补票）
- 用户在 T-02 验收后指出关键空白：M1.0 工单从未要求「进账」输入入口——数据层 type=income 地基在（T-01 起就有），但功能层没有任何入口，统计也只围绕支出设计。管理层工单设计漏项，与执行层无关
- **已补票（用户确认）**：T-03 增补「收入模式」（支出/收入切换，默认支出，主流程零摩擦不变；收入不套时段预填/午餐识别）；T-05 增补「收支对称」（支出/收入双线趋势 + 净结余，独立单测）——为 M2.0 AI 财政平衡分析供数

## 2026-09-08（管理层验收记录：T-02 ✅ 通过，附 1 项强制增补）
- **五层验收**（用户要求核心功能从严）：
  1. 记录核对：执行层收工记录完整（做了什么/关键决策/遗留/DoD 证据），票号 commit `9d5a493` ✓；主动上报「混合输入 UI 入口缺口」，纪律加分
  2. 独立复验：flutter analyze → No issues found；flutter test → **All tests passed (53)**；APK 实存 50.7MB
  3. 源码级审查（smart_parser 206 行 / smart_prefill 97 行 全文）：五级解析链（类别词典→商户词典→历史全等→历史前缀→原文兜底）与工单语义吻合；字符串解析金额禁浮点 ✓；时段边界排他语义正确 ✓；纯函数零依赖可测性设计 ✓
  4. **对抗性测试**（管理层自写 27 用例，隔离副本执行，repo 只读）：26/27 通过。时段全边界（6:59/7:00/8:59/9:00/11:29/11:30/13:29/13:30/16:59/19:00/22:29/3:59/4:00）、午间 ±1 分容差、周末屏蔽、高频排序双维度、优先级链、永不抛出——全部扛住
  5. UI 实证：三张截图目检（¥0 初始 → ¥15 交互 → snackbar「已记 ¥15」+清零）；键盘 12 键完整；深色干净无霓虹 AI 味；截图时刻 21:54 不在预填窗口、chip 条正确留空
- **审计发现 A1（低级，不阻塞）**：输入 `.5` 时金额被解析为 ¥5.00（正则跳过前导点取 `5`），且原文 `.5` 整体落入商户字段。12 键盘无小数点入口，实际暴露面 = 将来的混合输入框。**已升格为 T-03 强制增补**：混合输入 UI 必须随 T-03 落地 + `.5` 类输入须按 ¥0.50 解析或明确拦截
- 挂账 M2.0（不阻塞）：千分位逗号、全角数字、词典大小写敏感
- 硬编码抽查：全库仅 app.dart 主题种子金 1 处（app 级单点，合理）；tokens.dart 未建 = T-02 中途生效规则，T-03 起查
- 结构备注：本文件因管理层/执行层并发写入出现过重复横幅与段落错位，已由管理层整体重排归位（内容零删改，仅顺序与标题修复）
- **结论：T-02 验收通过 ✅**。下一票 T-03（含强制增补：混合输入框 + A1 修复）

## 2026-09-08（管理层记录：品牌定版 + T-08 换肤票发布）
- 用户定版黑金 Gringotts 徽标 → `brand/gringotts-logo.png`（md5 44ff10f0… 校验一致入库）；T-08 将由它生成 Android 自适应图标 / Windows 图标 / 启动画面
- TICKETS_M1 增补 **T-08 品牌 UI 重构（M1.0 收官票）**：硬前提 = T-01~T-07 全部验收通过；设计语言 = 深黑层底 + 香槟金 accent + 品牌衬线仅品牌时刻
- **对执行层的即时影响**：自 T-02 起颜色/字体/间距一律走 `lib/ui/tokens.dart`（组件禁硬编码）；T-08 之前不铺品牌皮肤，避免每屏装两遍
- ⚠️ **操作失误备案（管理层）**：品牌提交 `7cd0348` 用了 `git add -A`，把执行层 T-02 的在制文件（smart_parser / smart_prefill / quick_entry_page / 配套测试 / .t02_*.png 截图）一并扫入。管理层未改动任何代码内容，仅提交时机错误。**T-02 验收以执行层自己的 WORKLOG 收工记录为准；`7cd0348` 中的 T-02 文件视为 WIP 快照，不计作执行层的正式票提交。**后续管理层提交改为白名单 `git add <files>`，杜绝再犯

## 2026-09-08 22:05（T-02 执行层施工记录）

### 做了什么
- SmartParser 一行混合解析器（lib/services/smart_parser.dart，纯函数/离线）：
  - regex 金额提取（15 / 15.5 / 15.55 → 整数分 1500/1550/1555，字符串解析禁浮点）
  - 金额前后文本解析：内置类别词典（早餐/午餐/打车/房租 等 27 词）+ 内置商户词典（瑞幸/星巴克/滴滴 等 13 家）+ 历史 merchant 全等联想 + 前缀联想（瑞 → 瑞幸 建议返回）
  - 解析失败不阻塞：任何输入至少金额可存，未知商户保留原文
- 智能预填服务（lib/services/smart_prefill.dart）：
  - TimeOfDayDefaults：7:00-9:00 早餐/餐饮、11:30-13:30 午餐/餐饮、17:00-19:00 晚餐/餐饮、22:30+（含 0:00-3:59 尾段）夜宵/娱乐，其余时段不预填
  - HighFrequencyCategories：近 14 天高频类别排序（频次 desc → 近期 desc），null 类别跳过
  - LunchPattern：工作日午间 ¥15±2（可配置 anchorCents/toleranceCents）内联提示匹配
- 速记首页（lib/pages/quick_entry_page.dart，替换 T-01 骨架页）：
  - 打开即数字键盘（1-9/C/0/⌫ 12 键弹性布局），无导航层，深色 M3
  - 金额大字显示 + 时段默认类别 chip 预填 + 高频类别 chip 横条（14 天窗口，watchRecent 流驱动）
  - 午间模式内联提示「这是午餐吗？」（Card 内联，绝不弹窗打断）
  - 大确认键「记一笔」→ draft 入库（type=expense, isDraft=true, source=manual）→ snackbar 反馈 → 自动清零
- TransactionRepository 增补：watchRecent(14d) / distinctMerchants / merchantCategory（历史联想数据源）
- 单测 46 条新增：解析器 27 条（乱序/小数/纯金额/未知商户/边界 0.01/12345.67/历史联想/词典）+ 时段默认 9 条（边界含 9:00/13:30/19:00 排他）+ 高频 4 条 + 午间模式 7 条（周末/窗口外/容差边界）+ widget 交互 2 条

### 关键决策
- 解析器纯静态函数、零依赖（无 network/AI/riverpod），历史联想通过参数注入保持可测性
- 键盘 C 键 bug 实测发现并修复：按键标签 C 走 default 分支把字母拼进金额（¥C15），case 从 clear 改 C
- 键盘布局从 GridView shrinkWrap 改为 Column+Expanded 弹性填充，修复 7/8/9 行在矮窗口被裁切
- 高频 chip 条双 StreamBuilder（transactions + categories）流式驱动，符合 Riverpod 响应式约定

### 遗留问题
- flutter run -d windows 的 VM service 偶发 Lost connection to device（VS/Impeller 环境噪音，exe 直跑稳定无碍，不影响 DoD）
- 一行混合输入的 UI 输入框（文本行解析入口）未上屏 — 当前键盘是纯数字金额流；工单语义「一行混合解析器」已实现且有单测，输入入口在 T-03 回顾页补全流程时自然落地（见下一步）；若管理层认为 T-02 必须含混合输入框 UI，请在验收时指出，下轮补

### 下一步
- T-03 先记后补机制：首页 draft 角标 + 当日回顾页（按天分组、批量补类别/商户/备注、转正式、7 天灰显）

### DoD 证据
- flutter analyze → No issues found
- flutter test → All tests passed (53)
- Windows 实跑：gringotts.exe 启动，截图 .t02_windows_screenshot.png（¥0 + 12 键完整键盘）；脚本化点击 1→5 金额变 ¥15（.t02_interaction.png）；点击「记一笔」snackbar「已记 ¥15」+ 输入清零（.t02_confirm.png）
- 数据库验证：sqlite 直查 transactions 表存在 (1500, expense, is_draft=1, source=manual, UUID 主键) 记录
- Android release APK：flutter build apk --release → app-release.apk (50.7MB) 构建成功

## 2026-09-08（管理层验收记录：T-01 ✅ 通过）
- 独立复验（管理层亲自执行，不信自报）：flutter analyze → No issues found；flutter test → All tests passed (7)；APK 实存 build/app/outputs/flutter-apk/app-release.apk (51.3MB on disk)；铁律抽查：无 account 字段（models.dart 有显式注释 B3 rejected）、lib/data+domain 无 double 存钱
- schema 逐项对照工单：UUID text 主键 / created_at/updated_at/deleted_at 三时间戳 / integer cents / 墓碑查询层 / 9 类 seed / assets sold 字段 — 全部吻合
- 结论：**T-01 验收通过**，无缺陷工单。下一票 T-02 智能速记核心
- 备注：drift_dev 2.34.6 的 int() 列解析 bug 定位与修复记录质量高，已存档于本文件 T-01 施工记录

## 2026-09-08 19:10（T-01 执行层施工记录）

### 做了什么
- flutter create（org dev.jharayden，platforms android+windows）+ 接入依赖：drift 2.34.4 / flutter_riverpod 3.4.3 / fl_chart 1.2.0 / sqlite3_flutter_libs / uuid / path / path_provider
- Drift 数据层（lib/data/app_database.dart + codegen app_database.g.dart）：
  - transactions：id(UUID text) / amount_cents(int) / type / category_id / merchant / note / occurred_at / is_draft / source + created_at/updated_at/deleted_at
  - categories：id / name / icon / sort / is_custom + 三时间戳列；onCreate 注入 9 类固定 seed（UUID 常量 lib/domain/seed_ids.dart）
  - assets：id / name / category / value_cents / purchased_at / photo_path / status / sold_price_cents / sold_at + 三时间戳列
  - schemaVersion = 1（V1 起规范编号）；repository 层（transactions/categories/assets 三个 repository，含 softDelete/restore/confirmDraft/markSold）
- Riverpod wiring（lib/app/app.dart）：databaseProvider + 3 个 repositoryProvider；骨架页（深色 M3，验证 9 类 seed 从 DB 渲染）
- 测试 7 条：金额分整数断言 / 9 类 seed UUID 格式+唯一性 / 枚举序列化 / 墓碑测试（插入→墓碑→查询不含墓碑，物理行保留）/ categories seed 顺序 / assets 整数分插入 / widget smoke

### 关键决策
- drift_dev 2.34.6 + Dart 3.13 analyzer 兼容性问题定位：IntColumn get amountCents => int()() 的 int 被 drift_dev 列解析器误判为 dart:core 类型（InstanceCreationExpressionImpl cast bug），导致整表解析失败、codegen 生成空 schema。改用 integer() 修复。textEnum 是标准 API 无问题（中途误改成不存在的 textNamed，已回滚）
- 金额列一律 integer() 存分（工单铁律）；主键 UUID text（clientDefault _newUuid() 顶层函数，drift_dev 不能解析 lambda 内的 const Uuid().v4()）
- 墓碑列全表标配 deleted_at（nullable DateTime）；查询层只暴露 liveTransactions/liveCategories/liveAssets（deleted_at IS NULL）
- widget_test 用 fake CategoryRepository override（真实 drift 流在 fake-async zone 留 pending timer 导致测试失败）

### 遗留问题
- 无阻塞。build.yaml 的 generate_connect_constructor 选项在 build_runner 2.16 中已忽略（无影响，仅提示）
- flutter create 生成的默认 README.md 未做品牌化（低优先级，后续工单覆盖）

### 下一步
- T-02 智能速记核心（产品灵魂）：速记首页 + 一行混合解析器 + 时段默认类别 + 高频 chip 条 + 模式识别

### DoD 证据
- flutter analyze → No issues found
- flutter test → All tests passed (7)
- Windows 实跑：flutter run -d windows 成功启动（Impeller GL），窗口显示 Gringotts / 数据层已就绪 · 已加载 9 个内置分类 + 9 类 seed chips（餐饮/交通/购物/居住/娱乐/学习/医疗/人情/其他），DB seed 渲染验证通过
- Android release APK：flutter build apk --release → build/app/outputs/flutter-apk/app-release.apk (48.9MB) 构建成功

## 2026-09-08（管理层，非施工记录）
- B 区裁决入档：B3/B9 否决，其余采纳；手动速记改向为主 artery，截屏转备选池
- 版本编号制确立：M1.0–M4.0
- GitHub 仓库建立：github.com/jharayden/gringotts（private）
- **前置任务完成**：M1.0 工单 TICKETS_M1.md 发布（T-01~T-07）；执行层环境验证通过（Flutter 3.47.2 / Dart 3.13.2 / Codex CLI 0.152.1 / gh auth jharayden）；AGENTS.md 挂工单入口；Codex 登录流程启动
- 尚无执行层施工；Codex 登录授权完成后即可按 T-01 开工
