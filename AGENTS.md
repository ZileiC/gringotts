# AGENTS.md — Gringotts 执行层工作约定（Codex 自动读）

## 项目
Android 为核心的 AI+ 账本 app。档案=本目录；入口 `PROJECT_STATE.md`。栈锁定：Flutter + Drift + Riverpod。交付=Android APK（Windows 桌面仅开发预览）。

## 数据铁律
- UUID text 主键 / 每表 created_at + updated_at + deleted_at 墓碑；**禁物理删除**
- **金额一律整数分**，禁浮点；无账户体系、无多币种（用户否决）
- 派生值不落库（如 budget = 收入 − 存款 现算，不存）
- **快记即正式**：确认即写 `is_draft=false`，立即计入统计/预算/明细；草稿链路（回顾页/批量补类别/待完善徽章）已废除（`is_draft` 列与草稿排除逻辑保留，兼容历史数据，不迁移不删列）
- 照片：内容 hash 命名 + 入库前压缩，DB 只存路径
- API key 只进 flutter_secure_storage；禁硬编码 / 进 git / 进 log

## UI 铁律
- `tokens.dart` 是颜色/字号/间距唯一来源，组件内禁硬编码
- 深色唯一主题；黑金体系（近黑底 + 香槟金 accent）；**禁投影、禁渐变填充、禁发光、禁循环动画**（例外仅金渐变章程允许处，见 `DESIGN_MAIN.md` §7——允许处随用户裁决变动，以该节为准）
- 衬线（Playfair）仅限品牌时刻：主页 Hero 额度 / 资产净值 / wordmark / 快记金额行 / 键面数字（符号除外）
- 结构：底栏只放三个 tab 平级（分析/资产/统计，切换不压栈）；**「记一笔」仅属分析页**（入口位置与形态以 `DESIGN_MAIN.md` §8 冻结稿为准；资产/统计 tab **没有**记一笔入口）；快记页 = 分析页的下一级，返回落分析页；明细页挂统计页，时间优先（月→日→条目）

## 范围纪律
以 `PROJECT_STATE.md` 与 `TICKETS_M2A.md` 为准；**不得收窄或改写工单语义**；异议写 WORKLOG 等管理层裁决；不得自增范围外功能。

## 代码语言
源码与注释全英文；UI 文案中文。

## 分工
同一时间只允许一个 agent 改代码；管理层（Hermes）只动 .md。

## 工作流程（硬性）
1. 开工先读 `PROJECT_STATE.md` + `TICKETS_M2A.md`（只读当前票）；`WORKLOG.md` 只读顶部两条
2. **反浪费铁律**：同一验证/复现动作禁连续重跑（最多 1 次，且须由新事实驱动：代码改动/环境变化/新日志）；失败即换确定性手段（单测断言 / md5 / 源码 grep）并标注手段边界（debug 帧耗时 ≠ 真机帧率）
3. **证据条款**：脚本先声明前提（元素可见性 `ensureVisible` + DB 状态）；**播种用固定时间戳**（否则帧 md5 不可跨 run 比对）；回归帧落 `evidence/regression/`，不覆盖原票证据
4. **掉线保险（WIP 提交）**：每完成一个 Part 立即 `git commit -m "WIP T-xx: Part N"`（本地提交即可，收工一并 push）——2026-09-13 曾有一轮执行层掉线、整票四部分只存在于未提交工作区
5. **收工三连（缺一不算完工，管理层不予验收）**：① 重读最新 WORKLOG 并顶部追加（做了什么 / 关键决策 / 遗留问题 / 下一步）→ ② 本票 commit（`T-xx: <summary>`）→ ③ `git push`
