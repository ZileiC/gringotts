# DESIGN_T09.md — T-09 品牌 UI 换肤 + 资产详情 + 高级动效设计细则（管理层发布，用户已确认基调 2026-09-10）

> 依据：apple-design.skill（动效/材质/字体优先级最高）+ designer（色彩系统/单强调色纪律/反模式）+ claude-design（反 slop）。
> 动效参照系：charlesleclerc.com（Apart Collective）——Lenis 惯性平滑滚动 + scroll-driven 视差层 + 电影感转场；本文档第 5 节给出其 Flutter 转译。
> 色板来源声明（IRON LAW 合规）：色板非模板——从用户定版的黑金徽标（brand/gringotts-logo.png）与「巫师银行/金库」内容域反推：vault 的深黑 + gold 的光。情绪目标 = 沉稳、可信、有重量感的财富感，克制的高级。
> 用户裁决（2026-09-10）：①金额数字字体保持现状（tabular 无衬线，勿换衬线数字）②新增资产详情页（每资产可点入）③资产创建必须有**多张照片上传**④动画全面升级：视差滚动 + 微缩放反馈，参照 Leclerc 站质感

## 1. 色板 tokens（替换现 tokens.dart 数值）

| token | 值 | 用途 | 现值→新值说明 |
|---|---|---|---|
| canvas | `#0C0B09` | 页面最深底 | 0F0F12 → 暖调近黑（金库暗部），永不用 #000 |
| surface | `#14120E` | 卡片/列表面 | 1A1A1F → 暖调 |
| elevated | `#1D1A13` | 键盘键/浮层件 | 24242A → 暖调 |
| overlay | `#262117` | sheet/对话框面 | 新增 |
| hairline | `#2C271C` | 描边/分隔线 | 新增（金调暖灰，**非金色**） |
| ink | `#F4EFE2` | 主文字（暖白） | F4F4F5 → 暖调，永不用纯白 |
| inkSecondary | `#A69C86` | 次要文字 | 9E9EA6 → 暖调 |
| goldBrand | `#D4AF37` | 品牌种子/徽标复现 | 保留（主题 seed） |
| goldAccent | `#E3C36B` | 交互金（暗底上更亮更可读） | 新增 |
| goldDeep | `#9C7A24` | 按压态/渐变深端 | 新增 |
| goldContainer | `#2A2314` | 金调容器底（选中 chip/徽章） | 3A301B → 微调 |
| onGoldContainer | `#EDD9A3` | 金容器上文字 | 新增 |
| onGold | `#171204` | 金填充上的文字 | 新增 |
| semanticExpense | `#E5484D` | 支出/亏损 | 沿用语义红 |
| semanticIncome | `#46A758` | 收入/盈利 | 沿用语义绿 |

对比度已验：ink/canvas ≈ 15:1；goldAccent/canvas ≈ 9:1；onGold/goldAccent ≈ 8:1（均 WCAG AA 以上）。

## 2. 字体系统
- **主字体**：平台系统 sans（Roboto/SF），数据与正文
- **金额数字 = 现状保留**（用户裁决①）：tabular figures 无衬线，禁止改衬线数字——列表/看板/速记金额一律 `fontFeatures enableTabularFigures` 防跳动
- **品牌衬线**：**Playfair Display**（google_fonts 打包，仅 600/700）——仅品牌时刻：app wordmark、启动画面。**注意：不含净值大数字**（大数字保持 tabular sans，用户已认可现状）
- **字阶（Perfect Fourth 1.333，base 16）**：12 caption / 14 body-sm / 16 body / 21 lead / 28 h4 / 38 h3 / 50 h2；速记金额 56（display）
- **字距**：≥28px 标题负字距（-0.02em~-0.05em）；正文 0；eyebrow 小标签 +1.6px 字距 + 大写
- **行高反转**：字号越大倍率越小（display 1.0 → body 1.5）

## 3. 层次与材质
- **深度 = 表面阶梯 + hairline 描边，不用投影**：canvas → surface → elevated → overlay 四级，卡片一律 1px hairline
- **半透明顶栏**：BackdropFilter blur(20) + canvas 60%，内容从其下滚过；底缘 1px 亮 hairline
- **金渐变仅限两处**：①确认键「记一笔」（gold→goldDeep 垂直）+ 一次性 sheen 600ms ②饼图金阶（§7）。净值大数字用暖白 tabular（非金渐变，用户裁决①的延伸：数字保持素净）
- **禁**：卡片投影、霓虹饱和、纯黑纯白、循环动画、一屏多个金填充控件

## 4. 基础动效规格（apple-design 转译 Flutter）
| 交互 | 规格 |
|---|---|
| 键盘键按下 | pointer-down 即时 scale 1.0→0.97，120ms easeOut + selectionClick 触感 |
| 确认「记一笔」 | sheen 扫过 600ms 一次性 + mediumImpact 触感 + snackbar（goldContainer 底） |
| 数字变化 | count-up spring 400ms 临界阻尼（仅页面进入与数值变化时） |
| chip 选中 | AnimatedContainer 150ms |
| sheet | 上滑 320ms easeOutCubic + 遮罩 fade 200ms |
| 无障碍 | disableAnimations 时全部退化为透明度渐变；触感保留 |

原则：动效服务层级，可中断，反馈发生在按下而非抬起；不为装饰而动。

## 5. 高级动效层（Leclerc/Apart 转译——用户最看重项，工单核心）
参照系调研结论：charlesleclerc.com 的质感 = Lenis 惯性平滑滚动打底 + 滚动进度驱动的多层视差（背景慢前景快）+ 编辑式 reveal 节奏（内容成组入场，非逐元素乱入）+ 双模式转场。**全部可 Flutter 转译，不引 web 技术**：

- **A. 惯性平滑滚动（Lenis 转译）**：自定义 ScrollPhysics（高 stiffness spring + 摩擦曲线），全列表统一手感——滚动带「配重」，停止带余韵。资产页/统计页/回顾页统一挂载
- **B. 滚动驱动视差层**：基于 ScrollController 的速度插值
  - 资产详情页 hero 照片：滚动时照片以 0.5x 速率上移（背景慢），文字内容 1x（前景快）→ 经典 depth parallax
  - 净值看板卡：滚动离开时内容 0.85x + 轻微 scale 1.0→0.98 + opacity 1→0.6（「沉入」感）
  - 幅度铁律：**视差位移 ≤ 48px**，禁止整屏视差——账本是工具，电影感要有、工具性不能丢
- **C. 微缩放反馈**（用户点名「按钮适时略微放缩」）：所有可点卡片/tile 按下 scale 0.98 + 回弹 spring（240ms）；键盘键 0.97；确认键 0.96 + 触感。TouchedScale 统一组件实现，全 app 复用
- **D. 成组入场（编辑式 reveal）**：列表进入时按 60ms stagger 依次 fade+上移 12px（EaseOutCubic 280ms）——成组而非逐个，页面有节奏感不散乱
- **E. 共享元素转场（Flutter Hero）**：资产列表 tile 照片缩略图 → 详情页 hero 大图 **Hero 接力**（350ms easeOutCubic 曲线）——这是 Leclerc 站「页面间不换频道」的 Flutter 答案，资产详情页的灵魂动效
- **F. 转场语义**：进详情 = Hero 接力 + 详情内容 stagger；返回 = 逆向 Hero；页内 sheet 保持既有规格
- **性能红线**：视差/Hero 全部走 Transform/Opacity（不触发重布局）；列表用 ListView.builder 懒构建；60fps 底线，integration 证据需含滚动帧率描述
- **无障碍**：disableAnimations 时 A–E 全部退化为直接呈现；触感保留

## 6. 资产详情页（新增功能，用户裁决②③）
- **入口**：资产列表任意 tile 点入（含已卖出），Hero 接力转场
- **布局**：
  - hero 区：照片大图（多张可横滑 PageView + 页点），背景 canvas，上滑时照片 0.5x 视差
  - 信息区：名称（h4）、四类 badge、状态徽章（服役中/已退役/已卖出）
  - **数据区**：价值、购买日期、持有天数、CPD（¥X/天 徽章）、服役进度条；已卖出另加：卖出价、买卖差价（红绿）、保值率、净成本/天（**D1 口径随本票一并修正**：净成本 =（买−卖)÷天数）
  - 操作区：编辑 / 卖出（未售）/ 退役 / 删除（墓碑二次确认）
- **多照片上传（用户裁决③）**：
  - 创建/编辑表单：照片区支持**多选（image_picker multiImage）+ 拍照**，缩略图横排可删（删除=从待传列表移除，未入库即无成本）
  - 存储：沿用 PhotoService（压缩 + sha256 内容命名 + 幂等去重）；DB 新表 `asset_photos`（id UUID / asset_id FK / path / sort / created_at / updated_at / deleted_at 墓碑）——**首图 = 主图**（列表缩略图取 sort 最小）
  - 迁移：schemaVersion V1→V2 规范迁移脚本，旧资产单张照片自动落 asset_photos sort=0
- **数据规则**：详情页所有数字与列表页同源（CpdCalculator），不得出现第二套计算

## 7. 图表配色
- 趋势双线：支出 `semanticExpense` / 收入 `semanticIncome`；网格线 hairline 40%
- 饼图：**金系 6 阶**（goldDeep→goldAccent→#F0E0AC→…）+ 中性灰阶兜底未分类——金色的图表唯一豁免，不做彩虹
- tooltip：overlay 底 + ink 文字 + 金色数值

## 8. 逐页要点
1. **速记首页**：顶栏 wordmark（衬线金渐变小字）；金额 display 56 tabular 暖白；混合输入框 elevated；键盘键 elevated + 按下 0.97；确认键金渐变填充 onGold 文字 + sheen 600ms 一次性
2. **回顾页**：日期头 eyebrow（inkSecondary+字距）；draft 卡 surface；7 天灰显 Opacity 0.45；滚动物理 A
3. **资产列表页**：净值看板（eyebrow + **tabular 暖白大数字** + 三 pill）；tile 按下 0.98 + Hero 接力进详情；CPD 徽章 goldContainer pill；服役进度条 goldAccent/hairline
4. **资产详情页（新）**：§6 全项 + 视差 B + 成组入场 D
5. **统计页**：净结余卡（负值 semanticExpense 大字）；双线趋势 + 金阶 donut；导出 = hairline 金描边 outline 键
6. **启动画面**：canvas 纯色 + 徽标居中 38% + Playfair 600 wordmark；图标：Android 自适应（前景 G 龙 66% 安全区/canvas 底）+ Windows ico 多尺寸
7. 应用内图标：1.8px 描边 24 网格圆头线性单色——未激活 inkSecondary / 激活 goldAccent

## 9. 验收补充（叠加既有 DoD）
- 对比度抽查：正文/次文/金交互三档实测 ≥ AA
- 金色纪律 grep：金渐变出现处 ≤ 2（确认键 + 饼图金阶定义处）
- **动效验收**：Hero 接力/视差/微缩放/stagger 各留 Windows 实跑截图或录屏帧（md5 唯一 + Dart PNG）；integration 补资产详情页路由与多照片断言
- 数据验收：asset_photos 迁移用例（V1→V2 旧数据自动落表）+ 详情页数字与列表同源单测 + D1 净成本口径单测更新
- 回归：T-01~T-07 全部测试保持绿 + Windows 实跑 + release APK 重建 + 用户目测通过
