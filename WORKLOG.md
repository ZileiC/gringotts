# WORKLOG — Gringotts 施工日志

> 执行层（Codex）每次收工在顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步。管理层（Hermes）通过本文件验收进度。

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
