# DESIGN_T08.md — T-08 品牌 UI 换肤设计细则（管理层发布，待用户确认）

> 依据：apple-design.skill（动效/材质/字体优先级最高）+ designer（色彩系统/单强调色纪律/反模式）+ claude-design（反 slop）。
> 色板来源声明（IRON LAW 合规）：色板非模板——从用户定版的黑金徽标（brand/gringotts-logo.png）与「巫师银行/金库」内容域反推：vault 的深黑 + gold 的光。情绪目标 = 沉稳、可信、有重量感的财富感，克制的高级。
> 本文件经用户确认后升格为 T-08 工单附件，执行层照此施工。

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
- **品牌衬线**：**Playfair Display**（google_fonts 打包，仅 600/700 两字重）——用于品牌时刻：app 名 wordmark、总资产净值大数字、启动画面。备选 Cormorant Garamond（更纤细奢华）待用户裁决
- **数字**：列表/表格用 tabular figures（fontFeatures enableTabularFigures），防跳动
- **字阶（Perfect Fourth 1.333，base 16）**：12 caption / 14 body-sm / 16 body / 21 lead / 28 h4 / 38 h3 / 50 h2；金额大数字 56（display）
- **字距铁律**：≥28px 标题负字距（-0.02em~-0.05em）；正文 0；eyebrow 小标签 +0.4px + 全大写（拉丁）/加字距（中文）
- **行高反转**：字号越大倍率越小（display 1.0 → body 1.5）

## 3. 层次与材质
- **深度 = 表面阶梯 + hairline 描边，不用投影**（Linear 铁律）：canvas → surface → elevated → overlay 四级，卡片一律 1px hairline
- **半透明顶栏**（apple-design 材质条）：速记/统计页顶栏 BackdropFilter blur(20) + canvas 60% 叠加，内容从其下滚过；底部边缘 1px 亮 hairline（光沿材质边）
- **金渐变仅限两处**（hero-scale or nothing）：①总净值衬线大数字（goldAccent→goldDeep 垂直，background-clip 式）②确认键「记一笔」的高光 sheen（600ms 一次性扫过，非循环）。其余任何元素禁止渐变
- **禁**：卡片投影、霓虹饱和、纯黑纯白、循环动画、一屏多个金填充控件

## 4. 动效规格（apple-design 转译 Flutter）
| 交互 | 规格 |
|---|---|
| 键盘键按下 | 即时反馈（pointer-down）：scale 1.0→0.97，120ms easeOut + selectionClick 触感 |
| 确认「记一笔」成功 | sheen 扫过 600ms 一次性 + mediumImpact 触感 + snackbar（goldContainer 底）——视觉/触感同帧 |
| 净值数字 | count-up spring 400ms（临界阻尼，无过冲），仅页面进入与数值变化时 |
| chip 选中 | AnimatedContainer 150ms |
| 页面路由 | M3 fade-through 280ms（进 easeOutCubic / 出 easeInCubic 200ms） |
| sheet | 上滑 320ms easeOutCubic + 遮罩 fade 200ms |
| 无障碍 | MediaQuery.disableAnimations 时全部退化为透明度渐变；触感保留 |

原则：动效服务层级，可中断，反馈发生在按下而非抬起；不为装饰而动。

## 5. 金色使用章程（prose constraints——品牌性格住在这里）
**允许**：确认键填充；选中 chip/容器态；激活 tab/图标；净值数字渐变；CPD 徽章容器；启动画面/自适应图标；饼图金系色阶（品牌渐层，见 §7）
**禁止**：金色正文；金色分隔线/描边（分隔线一律 hairline）；金色大面积底；一屏第二个金填充控件；循环流光；任何霓虹化饱和度

## 6. 图标与启动资产
- 应用内图标：1.8px 描边（24 网格）圆头线性，单色——未激活 inkSecondary / 激活 goldAccent；禁止多彩 duotone
- Android 自适应图标：前景 = 徽标 G 龙居中 66% 安全区，背景 = canvas 纯色
- Windows ico：多尺寸（16/32/48/256）
- 启动画面：canvas 纯色底，徽标居中 38% 高度 + 下方 Playfair 600 wordmark「Gringotts」（ink 色），无标语无渐变

## 7. 图表配色
- 趋势双线：支出 `semanticExpense` / 收入 `semanticIncome`，网格线 hairline 40% 透明度
- 类别饼图：**金系 6 阶色阶**（goldDeep→goldAccent→#F0E0AC→…）+ 中性灰阶兜底未分类——品牌色阶是图表的金色唯一豁免，且不做彩虹
- 触摸 tooltip：overlay 底 + ink 文字 + 金色数值

## 8. 逐页要点
1. **速记首页**：顶栏 wordmark（衬线金渐变小字，品牌时刻）+ 三入口；金额 display 56 暖白；混合输入框 elevated；chip 选中=goldContainer/onGoldContainer；键盘键 elevated + 按下缩放；确认键金填充 onGold 文字
2. **回顾页**：日期头 eyebrow 式（inkSecondary + 字距）；draft 卡 surface；灰显维持 Opacity 0.45；批量操作键标准态
3. **资产页**：净值看板 = surface 卡 + eyebrow + 衬线金渐变大数字 + 三 pill；CPD 徽章 goldContainer pill；服役进度条 = goldAccent 填充/hairline 轨道；已卖出 tile 盈亏红绿
4. **统计页**：净结余卡（负值 semanticExpense 大字）；双线趋势 + donut 金阶；导出 = hairline 金描边 outline 键
5. **设置/导出页**：标准列表，零金色

## 9. 验收补充（叠加既有 DoD）
- 对比度抽查：正文/次文/金交互三档实测 ≥ AA
- 金色纪律 grep：金渐变出现处 ≤ 2（净值数字 + 确认键 sheen 实现）
- 截图证据：md5 唯一 + 全部 Dart PNG 编码（E1 整改）
- 回归：T-01~T-07 全部测试保持绿 + Windows 实跑 + release APK 重建成功 + 用户目测通过
