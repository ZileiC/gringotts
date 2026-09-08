# AGENTS.md — Gringotts 编码工作约定

> Codex 在本目录干活时自动读本文件。角色分工：Hermes 管理层 session 负责方向把控与任务管理（对代码只读不改）；你（Codex 执行层）负责编码执行。

## 项目一句话
Android 为核心的 AI+ 账本 app：智能速记 + 资产档案（CPD 日均成本）+ AI 分析（provider 由用户自配）。

## 技术栈（已锁定，勿更换）
- Flutter + Drift (SQLite) + Riverpod，一套代码 Android / Windows
- 交付物 = Android APK 直装；开发期用 Windows 桌面快速预览

## 数据/架构铁律（为将来手机→电脑同步铺路）
- 主键一律 UUID 字符串，不用自增 int
- 每表带 created_at / updated_at
- 删除用墓碑（deleted_at 标记），禁止物理删除
- **金额一律整数分（integer cents）存储，禁止用浮点数存钱**；不做账户体系、不做多币种（用户否决），字段只留整数分
- 速记入库为 draft 状态（金额必填，类别可后补），确认后转正式记录——「先记后补」是产品哲学，不是可选项
- 照片存本地文件（内容 hash 命名 + 入库前压缩），数据库只存路径
- API key 只存 flutter_secure_storage，绝不硬编码、绝不进 git、绝不进日志

## 速记智能约定（M1.0 核心，设计全文见 FEATURES.md A2）
- 解析全部本地实现（regex + 词典 + 历史联想），不得依赖网络或 AI——速记必须 100% 离线可用
- 金额是唯一必填项；类别/商户/备注全部允许后补
- 智能预填（时间段默认类别 / 高频 chip / 模式识别）只做「预填+可一键改」，禁止弹窗打断记录动作

## AI 接入约定（M2.0 起）
- OpenAI-compatible 协议：baseURL / apiKey / model 三件套，全部由用户在设置页配置
- AI 是增强不是依赖：AI 未配置或调用失败时，全 app 功能可用（报表 = 本地聚合图表先出）

## UI 铁律
- Material 3 先行；默认深色主题（唯一主题，不做切换入口）
- 首页即速记键盘，无导航层
- 品味：干净有重量感、排版整齐、动画讲究；严禁深底霓虹渐变"AI 味"

## 范围纪律
- MVP 范围以 PROJECT_STATE「项目状态」与 FEATURES.md 为准；当前里程碑 = M1.0
- **不得收窄或改写工单语义**；对工单有异议，在 WORKLOG 提出并等管理层确认，不得自行改需求交付
- 工单未指定交互形态时，用 Material 标准组件与最直接形态，不自创交互
- 明确不做（负范围）见 FEATURES.md C 区，含用户否决项：账户体系(B3)、多币种(B9)、截屏记账(备选池，未经管理层确认不得实现)；不要自作主张加范围外功能，发现缺口记入 WORKLOG.md 待确认

## 代码语言（standing rule）
- Source code & comments in English only；user-facing UI strings remain Chinese

## 分工底线（用户亲自划定，严格遵守）
- 本目录同一时间只允许一个 agent 改代码：执行层干活时，管理层 session 只动 .md 管理文档，不碰代码
- 根目录的 .md 是管理文档：PROJECT_STATE / WORKLOG / FEATURES 按各自约定维护，代码文件勿动

## 工作流程约定
1. 开工先读 PROJECT_STATE.md 与 FEATURES.md
2. 代码仓库就在本目录（github.com/jharayden/gringotts，private）
3. 每次收工在 WORKLOG.md 顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步
4. PROJECT_STATE.md 的"已确定/待定/决策记录"只在阶段完成时更新（由管理层维护）
