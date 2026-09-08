# AGENTS.md — Gringotts 编码工作约定

> Codex 在本目录干活时自动读本文件。角色分工：Hermes 管理层 session 负责方向把控与任务管理（对代码只读不改）；你（Codex 执行层）负责编码执行。

## 项目一句话
Android 为核心的 AI+ 账本 app：资产档案 + 截屏记账 + AI 分析（provider 由用户自配）。

## 技术栈（已锁定，勿更换）
- Flutter + Drift (SQLite) + Riverpod，一套代码 Android / Windows
- 交付物 = Android APK 直装；开发期用 Windows 桌面快速预览

## 数据/架构铁律（为将来手机→电脑同步铺路）
- 主键一律 UUID 字符串，不用自增 int
- 每表带 created_at / updated_at
- 删除用墓碑（deleted_at 标记），禁止物理删除
- **金额一律整数分（integer cents）存储，禁止用浮点数存钱**；字段预留 currency（默认 CNY），UI 层负责格式化显示
- 照片存本地文件（内容 hash 命名 + 入库前压缩），数据库只存路径
- API key 只存 flutter_secure_storage，绝不硬编码、绝不进 git、绝不进日志

## AI 接入约定
- OpenAI-compatible 协议：baseURL / apiKey / model 三件套，全部由用户在设置页配置
- AI 是增强不是依赖：AI 未配置或调用失败时，全 app 功能可用（截图 = 图片暂存待补录，报表 = 本地聚合图表先出）

## UI 铁律
- Material 3 先行；默认深色主题（唯一主题，不做切换入口）
- 品味：干净有重量感、排版整齐、动画讲究；严禁深底霓虹渐变"AI 味"

## 范围纪律
- MVP 范围以 PROJECT_STATE「项目状态」与 FEATURES.md 为准
- **不得收窄或改写工单语义**；对工单有异议，在 WORKLOG 提出并等管理层确认，不得自行改需求交付
- 工单未指定交互形态时，用 Material 标准组件与最直接形态，不自创交互
- 明确不做（负范围）见 FEATURES.md C 区；不要自作主张加范围外功能，发现缺口记入 WORKLOG.md 待确认

## 代码语言（standing rule）
- Source code & comments in English only；user-facing UI strings remain Chinese

## 分工底线（用户亲自划定，严格遵守）
- 本目录同一时间只允许一个 agent 改代码：执行层干活时，管理层 session 只动 .md 管理文档，不碰代码
- 根目录的 .md 是管理文档：PROJECT_STATE / WORKLOG / FEATURES 按各自约定维护，代码文件勿动

## 工作流程约定
1. 开工先读 PROJECT_STATE.md 与 FEATURES.md
2. 代码仓库就在本目录
3. 每次收工在 WORKLOG.md 顶部追加一段：做了什么 / 关键决策 / 遗留问题 / 下一步
4. PROJECT_STATE.md 的"已确定/待定/决策记录"只在阶段完成时更新（由管理层维护）
