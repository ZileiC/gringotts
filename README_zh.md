<div align="center">

<img src="docs/logo.png" alt="Gringotts" width="180" />

# Gringotts · 金库

**本地优先、可接入 AI 的 Android 记账应用。**
深色黑金，只回答一个数字：今天你还能花多少。

[English](README.md) · **中文**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Drift](https://img.shields.io/badge/Drift-SQLite-0B5563)](https://drift.simonbinder.eu)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-1B3A6B)](https://riverpod.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%C2%B7%20Windows%20preview-3DDC84?logo=android&logoColor=white)](#快速开始)
[![Tests](https://img.shields.io/badge/tests-237%20passing-46A758)](#质量与证据)
[![Status](https://img.shields.io/badge/status-M1%20complete-9C7A24)](#路线图)
[![License](https://img.shields.io/badge/license-MIT-E3C36B)](LICENSE)

</div>

---

## 这是什么

大部分记账应用会让你先成为一个会计。Gringotts 只问一件事，并且每次打开都回答它：
**今天还能花多少，钱都花到哪儿去了？**

你填一次月度收入和想存下的钱，它把这份预算摊成每天的可用额度，盯着每一笔记录，并从 M2 开始，
用**你自己配置的** AI 服务商解释发生了什么、建议接下来怎么做。所有数据留在你的设备上——没有账号、
没有云端、没有埋点。

> 设计北极星：**calm confidence（心里稳、脸上淡、手上不慌）**。给你一个能立刻动手的数字，
> 界面保持安静，不用任何花哨装饰假装洞察。

## 界面

<div align="center">

| 分析 | 快记 | 明细 |
|---|---|---|
| <img src="docs/screenshots/01-analysis.png" width="210" alt="分析页：今天还能花、预算进度、今日构成" /> | <img src="docs/screenshots/02-quick-entry.png" width="210" alt="快记页：两个输入、键盘、九宫格类别" /> | <img src="docs/screenshots/03-ledger.png" width="210" alt="明细页：月、日、条目与当日合计" /> |
| 实时额度、预算进度、今日构成、AI 位 | 两个输入、一副为场景定制的键盘、九宫格类别常驻 | 月 → 日 → 条目，每天右侧是当日净额 |

| 资产 | 资产详情 |
|---|---|
| <img src="docs/screenshots/04-assets.png" width="210" alt="资产页：净值、日均成本、持有天数" /> | <img src="docs/screenshots/08-asset-detail.png" width="210" alt="资产详情：照片、价值、日均成本、卖出与退役" /> |
| 净值、日均成本、持有天数、已实现盈亏 | 照片、日均成本、编辑 / 卖出 / 退役 / 删除 |

| 统计 · 日 | 统计 · 月 |
|---|---|
| <img src="docs/screenshots/05-stats-daily.png" width="210" alt="统计页日视图：每日支出柱对着当天额度，下面是趋势图" /> | <img src="docs/screenshots/06-stats-month.png" width="210" alt="统计页月视图：每月成对柱与趋势图" /> |
| 整月每一天；超出额度的柱段变红；下方是双线趋势 | 同一对图换成十二个月，对着当月预算 |

<br />

<img src="docs/screenshots/07-splash.png" width="240" alt="启动画面：Gringotts 徽标与 wordmark" />

<sub>启动画面 —— 品牌时刻，等第一帧就绪</sub>

</div>

## 设计原则

- **一个数字优先**：应用的主角是"今天还能花多少"，其余一切都是这个数字的证据。
- **记账动作不能被打断**：选类别永远不是门槛——确认的那一刻记录就已经写进账本，之后随时可以补全。
- **注意力也是预算**：深色唯一主题、黑金体系、细描边；禁投影、禁渐变填充、禁发光、禁循环动画。
  配色是一套系统，不是主题乐园。
- **衬线只用于品牌时刻**：Playfair 只出现在主页额度、资产净值、wordmark 与键盘数字上；
  其余文字一律用干活的 sans（MiSans）。
- **派生值不落库**：预算、日额度、日均成本、以及所有图表序列都是读时算出来的。
  数据库只存事实，不存结论。

## 功能

**记录**
- 快记：两个输入（项目名 + 金额）、为场景定制的 4×3 键盘、九宫格类别常驻可见、描边确认键——为"三秒一笔"而生
- 混合输入解析：`瑞幸 15` 一行同时给出商户与金额
- 按时段与频次的类别预填，工作日午间有内联的"午餐"提示
- 照片：内容哈希命名、入库前压缩，数据库只存路径

**看懂**
- 月度收入 + 计划存款 → 每天可用额度；主页同时给出固定基准额度与实时剩余额度
- 今日支出圆环 + 本月预算进度条
- 统计页围绕两张图重建：支出柱对着当天额度（超出的柱段变红），加上一张真正的双线趋势——
  收入线含月度收入的按天均摊，不再贴着横轴
- 分析 / 明细 / 统计三页共享同一个"当前月份"，切一次三页同步
- 类别占比、日/月/年汇总、CSV + JSON 导出（带 UTF-8 BOM）

**资产**
- 资产含购入价、状态、照片、持有天数与日均成本
- 卖出资产并复盘实际盈亏
- 月末一键把"计划存款"确认成一条真实资产（不确认就永不写库）

**数据与隐私**
- 本地优先：SQLite 在设备上，单机应用，无服务器、无账号
- 每张表都是 UUID 主键 + `created_at` / `updated_at` + `deleted_at` 墓碑；禁止物理删除，
  schema 从第一天就是可同步的
- 金额一律整数分，金额路径上没有任何浮点数
- M2 的 AI 层是自带密钥（BYO）：key 只进 `flutter_secure_storage`，不写日志、不进仓库、不硬编码；
  模型只拿到聚合统计，永远拿不到你的原始流水

## 架构

```
lib/
├── app/            应用外壳、路由、共享 provider（主题、当前月份）
├── data/           drift 数据库、表定义、生成代码、仓库层
├── domain/         纯模型与枚举（流水、资产、预算）
├── services/       预算引擎、统计、解析、预填、导出、存款计划
├── pages/          分析 · 快记 · 明细 · 资产 · 资产详情 · 统计
└── ui/             设计 token、动效、月历 sheet、自绘线稿图标、记一笔按键
```

| 关注点 | 选择 | 理由 |
|---|---|---|
| 框架 | Flutter（Android 为主，Windows 作预览与回归） | 一套代码，且我们真正在意的界面有一致的真机表现 |
| 持久化 | Drift over SQLite | 类型化查询，迁移可以在真实文件上测 |
| 状态 | Riverpod | provider 可测；同一份仓库流同时喂给每个页面 |
| 图表 | fl_chart | 图形留在本地，AI 只负责写文字 |
| 字体 | MiSans（界面）+ Playfair Display（品牌时刻） | MiSans 子集化，每个字重约 14KB，包体诚实 |

### 代码强制的数据规则

1. 金额是 `int` 分，格式化只发生在边缘。
2. 每张表都有 `created_at` / `updated_at` / `deleted_at`；删除即打墓碑。
3. 派生值一律不落库——`budget = 收入 − 存款` 是读时算术，日额度、日均成本、图表序列同理。
4. 记录在确认的那一刻就生效，没有需要伺候的草稿流水线。
5. 迁移只做加列，且会在真实的历史版本文件上测试（当前 `schemaVersion` 4，覆盖 V1→V4 路径）。

## 设计系统

`lib/ui/tokens.dart` 是颜色、字号、间距的唯一来源，组件里禁止硬编码。真正起作用的是两条规则：

- **金色克制**：香槟金只作描边、文字、细线、图表点缀与少数点名允许的渐变时刻——
  绝不做正文、分隔线或大面积填充。
- **不做假深度**：用细描边与色调替代投影，用一次 0.96 的按下缩放替代弹跳，
  所有动效在 `reduce-motion` 下干净退化。

完整参考——颜色角色、字阶、间距、动效、组件语言、金额呈现规则与实测对比度——见
[`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md)。

## 快速开始

```bash
# 前置：Flutter 3.x（stable）、Android SDK（出 APK）、Windows 桌面工具链（预览）
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 改 schema 后重新生成 drift 代码

flutter analyze                    # 必须零问题
flutter test                       # 单测 + widget 测试
flutter test integration_test/xxx_test.dart -d windows     # 真机引擎证据脚本

flutter build apk --release        # 真正的交付物
```

## 质量与证据

这个项目把"在我机器上能跑"当成 bug 报告。每一次改动都带：

- `flutter analyze` 零问题 + 单测全绿（写这份 README 时为 237 个用例），
- widget 与服务层测试**钉住数值而不是画面**：一个数字、一个颜色、一个几何关系或一行数据库记录，
- 真机引擎的 integration 脚本，导出文件逐字节校验（BOM、编辑后的商户、编辑后的金额、JSON 内容），而不是靠肉眼看，
- 迁移在真实的历史版本数据库文件上验证过，
- 只有在数值断言表达不了结论时才使用帧证据，并明确声明每帧在单次运行内的唯一性。

## 路线图

| 里程碑 | 内容 | 状态 |
|---|---|---|
| **M1.0** | 本地核心账本：快记、明细、资产 + 日均成本、统计、导出、品牌 UI | ✅ |
| **M2.0 前置波** | 预算引擎、分析主页、快记重设计、明细页、导航壳、双图统计、存款转资产 | ✅ |
| **M2.0** | 自带 AI：服务商配置、主页 AI 分析与建议、对话窗口、报表解读、周期账单、Widget、本地加密 | 设计中 |
| **M3.0** | 专家 skill 体系（经济/理财）、每日建议、周报月报、异常消费检测 | 计划中 |
| **M4.0** | Windows 端：镜像应用 + 分析工作台，先加密导出/导入，后局域网同步 | 计划中 |

## 参与

欢迎 issue 与 PR——先看 [`CONTRIBUTING.md`](CONTRIBUTING.md)。一句话版本：结构性改动先开 issue，
改动必须留在既有 design token 内，并且准备接受一场"要证据不要截图"的评审。

## 安全

请私下报告漏洞——见 [`SECURITY.md`](SECURITY.md)。简短版：仓库里不该有任何密钥，
API key 只存在于设备的安全存储里，AI 层的设计前提是永不接触原始流水。

## 许可

代码采用 [MIT](LICENSE)。随包分发的第三方资源沿用各自许可——见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 致谢

由 [Flutter](https://flutter.dev)、[Drift](https://drift.simonbinder.eu)、
[Riverpod](https://riverpod.dev) 与 [fl_chart](https://github.com/imaNNeo/fl_chart) 构建。
字体：[MiSans](https://hyperos.mi.com/font)（界面）与
[Playfair Display](https://fonts.google.com/specimen/Playfair+Display)（品牌时刻）。

<div align="center">
<sub>Gringotts · 金库自己记账</sub>
</div>
