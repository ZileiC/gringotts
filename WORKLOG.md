# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。
> ⚠️ 并发写入约定：追加前先重新读取文件最新版，在头部插入自己的段落，不要重建文件横幅；管理层 patch 前同样先重读。

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
