# AGENTS.md — Gringotts 执行层工作约定（Codex 自动读）

## 项目
Android 为核心的 AI+ 账本 app。档案=本目录；入口 `PROJECT_STATE.md`。栈锁定：Flutter + Drift + Riverpod。交付=Android APK（Windows 桌面仅开发预览）。

## 数据铁律
- UUID text 主键 / 每表 created_at + updated_at + deleted_at 墓碑；**禁物理删除**
- **金额一律整数分**，禁浮点；无账户体系、无多币种（用户否决）
- 派生值不落库（如 budget = 收入 − 存款 现算，不存）
- 速记以 draft 入库（金额必填、类别可后补），确认后才进统计——「先记后补」是哲学不是选项
- 照片：内容 hash 命名 + 入库前压缩，DB 只存路径
- API key 只进 flutter_secure_storage；禁硬编码 / 进 git / 进 log

## UI 铁律
- `tokens.dart` 是颜色/字号/间距唯一来源，组件内禁硬编码
- 深色唯一主题；黑金体系（近黑底 + 香槟金 accent）；**禁投影、禁渐变填充、禁发光、禁循环动画**
- 衬线（Playfair）仅限品牌时刻：主页 Hero 额度 / 资产净值 / wordmark / 快记金额行 / 键面数字（符号除外）
- 结构：主页=分析页（启动页）；速记页为二级；明细页时间优先（月→日→条目）

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
4. **收工三连（缺一不算完工，管理层不予验收）**：① 重读最新 WORKLOG 并顶部追加（做了什么 / 关键决策 / 遗留问题 / 下一步）→ ② 本票 commit（`T-xx: <summary>`）→ ③ `git push`
