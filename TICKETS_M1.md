# TICKETS_M1.md — M1.0 派工工单（管理层发布）

> 执行层（Codex）按序施工。每张票完成即在 WORKLOG 记录并 commit（票号进 commit message）。
> 工单语义不得收窄或改写；有异议记 WORKLOG 等管理层确认。
> 完工定义（DoD）：`flutter analyze` 零错误 + `flutter test` 全绿 + Windows 桌面实跑截图/描述留 WORKLOG + Android APK 构建成功。

## 全局约定
- 版本目标 = M1.0；过程中修补记 M1.x
- 技术栈/数据铁律/UI 铁律/代码语言铁律见 AGENTS.md，全部适用
- **Design token 铁律（自 T-02 起）**：所有颜色/字体/间距一律经 `lib/ui/tokens.dart`（ThemeExtension 或常量表），组件内禁止硬编码色值/字号——为 T-08 整体换肤铺路
- 类别体系（v1 固定 seed，允许后补自定义）：餐饮 / 交通 / 购物 / 居住 / 娱乐 / 学习 / 医疗 / 人情 / 其他
- 资产分类体系（对标有数）：硬通货 / 数码 / 非标品 / 普通物品

---

## T-01 项目骨架与数据层
- `flutter create`（org 随意，app 名 gringotts）；接入 Drift + Riverpod + fl_chart
- Drift 表（全部：UUID text 主键 / created_at / updated_at / deleted_at 墓碑）：
  - `transactions`：id, amount_cents(int, 必填), type(收入/支出/转账占位)， category_id, merchant, note, occurred_at, is_draft(bool), source(manual 预留 future: screenshot/voice)
  - `categories`：id, name, icon, sort, is_custom(bool)；预置上面九类 seed
  - `assets`：id, name, category(硬通货/数码/非标品/普通物品), value_cents, purchased_at, photo_path, status(服役中/已退役/已卖出), sold_price_cents(可空), sold_at(可空)
- Drift 迁移文件从 V1 开始规范编号；金额列一律 int 存分
- 验收：`flutter analyze` 过；`flutter test` 覆盖「插入→墓碑→查询不含墓碑」与「金额分转换」两条用例

## T-02 智能速记核心（产品灵魂，最高优先级）
- 首页 = 速记页：打开 app 直接是数字键盘，无导航层；深色 M3 风格
- 金额 = 唯一必填；大确认键入库（draft 状态）
- 一行混合解析器（本地，离线）：`瑞幸 15` / `15 瑞幸` / `15.5 午餐` → 商户/金额/类别建议；regex + 内置词典 + 历史 merchant 联想；解析纯函数 + 单测全覆盖
- 时段默认类别：7:00–9:00 早餐(餐饮) / 11:30–13:30 午餐 / 17:00–19:00 晚餐 / 22:30+ 夜宵娱乐；其余时段不预填
- 高频类别 chip 条：金额输入后横向一排（近 14 天高频优先）；点选换类，不点则用预填
- 模式识别：工作日午间 ¥15±2（可配置容差）弹不弹窗都禁止——用内联提示「这是午餐吗？」一键确认，绝不打断
- 解析失败不阻塞：任何输入至少金额可存
- 验收：解析器单测 ≥ 20 条（含乱序/小数/纯金额/未知商户）；速记页 Windows 实跑通过

## T-03 先记后补机制
- draft 记录首页角标「今日 N 笔待完善」；当日回顾页：按天分组列出 draft，批量补类别/商户/备注后转正式
- 7 天前仍未补的 draft 在回顾页降级灰显（不删）
- 验收：draft→正式→统计只计正式（用例：draft 不进当日合计，确认后进）

## T-04 资产档案页（A1+B8）
- 资产列表 + 总资产净值看板（服役中资产现值合计；已卖出按卖出价计已实现）
- 资产录入：名称/分类/价值/购买日期/照片（拍照或相册；图片压缩 + hash 文件名，DB 存路径）
- CPD 日均成本：现值÷持有天数 持续计算；列表显示「¥8.8/天」式标签 + 服役进度条
- 变现复盘：填卖出价 → 自动算 买卖差价、总成本/天、保值率；卖出后进「已卖出」分区
- 验收：CPD 计算单测（跨天/当天/已卖出三种）；照片流程 Windows 实跑通过

## T-05 统计图表与导出
- 本地聚合统计页：日/月/年三档 + 类别占比（fl_chart 饼图）+ 趋势（折线）；只算非 draft
- 设置页：CSV / JSON 全量导出（Win 端存文档目录，Android 端存 Download）
- 验收：聚合口径与「draft 不计入」单测；导出文件可用 Excel 打开（CSV 带 BOM 防 Excel 中文乱码）

## T-06 直达入口（B10 前半）
- 长按桌面图标快捷方式「记一笔」（Android shortcuts + Windows 可忽略）
- 通知栏 Quick Settings tile「记一笔」（Android）
- 验收：真机或模拟器点按直达速记页（WORKLOG 留证据描述）

## T-07 M1.0 收尾整合
- 全量回归：速记→draft→补全→统计→资产→导出 全链路 Windows 实跑
- Android release APK 构建成功（`flutter build apk --release`）
- WORKLOG 写 M1.0 完工报告：功能清单 vs 工单逐条对照
- **不包含**：AI 任何能力、预算、周期账单、Widget、加密、截屏解析、账户、多币种

---

## 施工顺序与里程碑
T-01 → T-02 → T-03 → T-04 → T-05 → T-06 → T-07 → T-08（T-02 最重，允许在 T-01 后并行 T-04；T-08 为 M1.0 收官票）
每票一 commit：`T-0x: <summary>`；发现工单缺口 → WORKLOG 登记，不得自行改需求

---

## T-08 品牌 UI 重构（黑金体系，M1.0 收官票）
- **硬前提**：T-01~T-07 全部验收通过、全功能可用——功能不绿不换肤
- 品牌资产：`brand/gringotts-logo.png`（用户定版黑金 G 龙徽标，2026-09-08）
- 设计语言（管理层从徽标定调）：
  - 深黑层底（近 #0A0A0A，按层级微调明度，保持对比度）+ 香槟金 accent（从徽标取色；金色渐变允许但克制）
  - 品牌衬线字仅用于品牌时刻（app 名、总资产净值大数字等），数据与正文用高可读无衬线
  - 动画讲究有重量感（页面入口/微交互），干净有重量感为纲；**严禁深底霓虹渐变 AI 味**
- 范围：tokens 全量换肤 + 全部页面（速记/回顾/统计/资产/设置）+ 图标体系（金色单色系）+ Android 自适应图标与 Windows 图标（从徽标生成）+ 启动画面
- 硬约束：重构后全量回归——T-01~T-07 全部测试保持绿、关键流程 Windows 实跑证据入 WORKLOG、release APK 重新构建成功
- 验收：回归证据 + 无硬编码色值残留（管理层 grep 抽查）+ 用户目测通过
