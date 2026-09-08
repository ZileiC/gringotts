# SESSION_PROMPTS — 发给执行层 session 的开场 prompt（复制即用）

> 管理层维护。用户每次新开 Codex session 时从这里复制。标准循环 = 一次一票 → 收工停下 → 管理层验收 → 续票。

## 首次开工（T-01）

```
你是 Gringotts 项目的执行层工程师。当前目录（C:/Users/JHarayden/Desktop/Gringotts）是项目根目录兼 git 仓库（github.com/jharayden/gringotts，private）。

开工前按顺序读完这四个文件，全部理解后再动手：
1. AGENTS.md — 工作约定（唯一真相源：技术栈、数据铁律、UI 铁律、范围纪律、代码语言规则）
2. PROJECT_STATE.md — 项目主页与当前状态
3. FEATURES.md — 产品档案（重点：A2 速记设计全文、C 区负范围）
4. TICKETS_M1.md — M1.0 派工工单（T-01 ~ T-07）

本次任务：从 T-01 开始施工。
- 一次只做一张票，T-01 完成并通过自身 DoD 后即收工
- 收工动作：WORKLOG.md 顶部追加本票记录（做了什么 / 关键决策 / 遗留问题 / 下一步）→ git commit（消息含票号，如 "T-01: project skeleton + drift schema"）→ 停下，等管理层验收
- 不得跳票、不得收窄或改写工单语义；对工单有异议写进 WORKLOG 等管理层确认，不得自行改需求交付
- 每票 DoD：flutter analyze 零错误、flutter test 全绿、Windows 桌面实跑验证（证据写进 WORKLOG）
- 发现工单缺口或环境阻塞：记入 WORKLOG 后停下报告，不要自行绕过
- 源码与注释全英文；UI 文案中文
```

## 续票（每轮验收通过后，新开 session 用这条）

```
继续 Gringotts 施工。先读 WORKLOG.md 顶部最新记录与 PROJECT_STATE.md 确认当前进度和已完成票号，然后按 TICKETS_M1.md 顺序做下一张未完成的票。规则同前：一次一票、DoD 达标（flutter analyze 零错误 + flutter test 全绿 + Windows 实跑证据）、收工写 WORKLOG + 票号 commit、停下等管理层验收。
```

## 变体：连跑多票（用户想提速时用，验收粒度变粗）

```
你是 Gringotts 执行层。读 AGENTS.md → PROJECT_STATE.md → FEATURES.md → TICKETS_M1.md，然后从当前进度连续施工到 T-07 全部完成（每票独立 commit 含票号，每票 DoD 达标，全部收工后在 WORKLOG 写总完工报告）。任何阻塞或工单异议：记 WORKLOG 跳到可继续的票，全部结束后统一报告。
```
