<div align="center">
  <img src="docs/logo.png" alt="Gringotts" width="120" />
</div>

# Gringotts

一个离线的 Android 记账应用。你填一次月度收入和想存下的金额，应用把它摊成每天可花多少，然后盯着你实际花了多少。
没有账号，没有服务器，整本账就是手机上的一份 SQLite 文件。

[English](README.md) · **中文**

[![License](https://img.shields.io/badge/license-MIT-E3C36B)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](#构建)

## 界面

<div align="center">

| 分析 | 快记 | 明细 |
|---|---|---|
| <img src="docs/screenshots/01-analysis.png" width="210" alt="分析页：今天还能花、预算进度、今日构成" /> | <img src="docs/screenshots/02-quick-entry.png" width="210" alt="快记页：两个输入、键盘、九宫格类别" /> | <img src="docs/screenshots/03-ledger.png" width="210" alt="明细页：月、日、条目与当日合计" /> |

| 资产 | 资产详情 |
|---|---|
| <img src="docs/screenshots/04-assets.png" width="210" alt="资产页：净值、日均成本、持有天数" /> | <img src="docs/screenshots/08-asset-detail.png" width="210" alt="资产详情：照片、价值、日均成本、卖出与退役" /> |

| 统计 · 日 | 统计 · 月 |
|---|---|
| <img src="docs/screenshots/05-stats-daily.png" width="210" alt="统计页日视图：每日支出柱对着当天额度，下面是趋势图" /> | <img src="docs/screenshots/06-stats-month.png" width="210" alt="统计页月视图：每月成对柱与趋势图" /> |

<br />

<img src="docs/screenshots/07-splash.png" width="240" alt="启动画面" />

</div>

## 它能做什么

- 三秒记一笔：名称、金额、一副带小数点的键盘，九个类别常驻在屏幕上
- 混合输入解析：敲 `瑞幸 15`，一行里同时填好商户和金额
- 把月度预算摊成每天额度，分析页上显示今天还剩多少
- 明细按「月 → 日 → 条目」组织，每天右侧是当天的净额
- 统计页两张图：每日支出对着当天额度；支出与收入的走势对比
- 资产记录含购入价、持有天数与日均成本，卖出后复盘实际盈亏
- 条目和资产都能附照片。图片按内容哈希命名、压缩后存成文件，数据库只留路径
- 导出 CSV 或 JSON
- 没设预算时显示设置引导

## 构建

需要 Flutter 3.x 和 Android SDK。Windows 端用于预览和跑 integration 测试。

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 改过 schema 之后
flutter analyze
flutter test
flutter build apk --release
```

## 代码结构

Flutter + Drift（SQLite）+ Riverpod。`lib/services` 放预算、统计、解析和导出，都是纯函数；
`lib/data` 放表定义和仓库层；`lib/ui` 放设计 token 与共用组件；`lib/pages` 是六个页面。

金额一律整数分。每张表都有 `created_at`、`updated_at`、`deleted_at`，删除只打墓碑不删行，
所以之后要同步时结构已经就绪。派生数字（预算、每日额度、日均成本，以及所有图表序列）
一律读时计算，不入库。

## 测试

`flutter test` 有 252 个单测与 widget 测试。`integration_test/` 里的脚本跑在 Windows 引擎上，
断言的是数值不是画面：导出文件逐字节校验（BOM、改过的商户、改过的金额、JSON 内容），
迁移则在真实的历史版本数据库文件上验证。`flutter analyze` 无告警。

## 设计

深色主题、黑金、用细描边代替投影。颜色、字号、间距都来自 `lib/ui/tokens.dart`，
组件里硬编码一个色值就算 bug。对比度数值和图表遵循的规则写在
[docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md)。

## 路线图

- M1：本地账本。已完成。
- M2：自带 AI 服务商，主页给出分析与建议、对话窗口、报表解读、周期账单、桌面小组件与本地加密。进行中。
- M3：理财与经济专家 skill、每日建议、周报月报。
- M4：Windows 端与分析工作台，之后是加密导出导入，再之后是局域网同步。

## 参与

欢迎 issue 和 PR，规矩在 [CONTRIBUTING.md](CONTRIBUTING.md)。一句话版本：改了行为就带一个断言，
断言的是那个数字、颜色或数据库行；结构性改动先开 issue。

## 安全

漏洞请按 [SECURITY.md](SECURITY.md) 私下报告。API key 只放 `flutter_secure_storage`，
AI 层的设计前提是只发送聚合统计，不发送原始流水。

## 许可

MIT，见 [LICENSE](LICENSE)。随包的字体与图标沿用各自许可，列在
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 致谢

主要靠 Flutter、Drift、Riverpod 和 fl_chart。界面字体是 MiSans，wordmark 与两处品牌数字用
Playfair Display。
