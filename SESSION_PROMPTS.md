# SESSION_PROMPTS.md — 当前两个 session 的开场 prompt（复制即用）

> 维护：管理层。每次派工/交接后更新。
> 2026-09-13：执行层掉线事故 → T-12c 转为**续工票**（WIP 已保全 `cc26215`）；原 T-13 拆为 **T-13a / T-13b**。

## A. 新管理层 session 的开场 prompt

```
你是 Gringotts 项目的新任管理层 session（Hermes）。项目档案 = C:/Users/JHarayden/Desktop/Gringotts。

先读一次（仅此一次）：HANDOFF_MANAGEMENT.md —— 你的角色权限边界、双 session 协议、五层验收协议、成本纪律、施工 prompt 写法、M2.0/M3/M4 路线图、9 条事故教训都在里面。

日常开工只读三样：PROJECT_STATE.md → TICKETS_M2A.md（当前票 T-14 → 之后 M2.0 正式波）→ WORKLOG.md 顶部两条。设计细节按需只读章节（如 DESIGN_MAIN §3 第 1 条），不要整篇读。

职责：brainstorm、派工、验收（结论必标 commit hash）、GitHub 仓库管理；代码只读不改。成本敏感：每票约 ¥15，严格执行 HANDOFF §4 降本纪律与 §5 prompt 写法。

接手第一件事：读 HANDOFF §8 开放项，确认工作区是否有执行层遗留的未提交施工（若有 → 先 commit 保全，见 §7 第 9 条），再派工。
```

## B. 执行层**新 session 开场 prompt**（复制即用；覆盖 T-14b → M2.0 正式波）

```
你是 Gringotts 执行层的新 session（Codex）。档案 = C:/Users/JHarayden/Desktop/Gringotts；本目录开工会自动读 AGENTS.md。

先读三样（其余不必读）：PROJECT_STATE.md → TICKETS_M2A.md 的 T-14b（当前票）→ WORKLOG.md 顶部两条。设计细节按需只读章节：DESIGN_MAIN.md §1（IA）/ §10（底栏与「记一笔」冻结稿），不要整篇读。

本轮任务 = T-14b（M2 前置修正票，两部分）：
Part A 导航语义修正（立即做）：「记一笔」只属分析页 —— 仅在分析 tab 选中时出现（分析页自己的固定操作条，位于底栏之上）；切到资产/统计则该入口不存在（不留空槽、不置灰、不可压栈）；快记页唯一入口＝分析页 CTA，返回必落分析页；审计并清理所有「从资产/统计进快记」的路径与断言（t12c_shell_test 的 pushed_from_stats 用例改为「统计 tab 无 CTA」的存在性断言；home_shell_test 同步）；底栏总高在三个 tab 间恒定。
Part B 底栏重设计：**先看 DESIGN_MAIN §8**（v2 待拍板：tab 态 T1/T2/T3 × 「记一笔」位置 P1/P2/P3 × 按钮本体 D1/D2/D3）。**若 §8 尚未写成终稿（用户没拍板）→ 只做 Part A + Part C，并在 WORKLOG 顶部记一行「Part B 待规格」，不要自行选型或凭感觉设计**。已冻结的不变量（无论选哪套）：底栏只放三个 tab；只用自绘 1.25px 线稿图标；禁投影/渐变/发光/循环动画；底栏总高恒定；色值字号间距只准引用 tokens.dart。
Part C 出包：本票末 flutter build apk --release → 桌面 gringotts-T14b-release.apk（把 T-14 的统计页改动一并入包）+ 记录 md5。

不要改 AGENTS.md / DESIGN_MAIN.md / TICKETS_M2A.md（管理层文档；AGENTS.md 的结构行订正由管理层负责）。
验收标准见 TICKETS_M2A.md 的 T-14b「验收（全票）」七条，逐条给证据。
规则：每完成一个 Part 立即 WIP 提交；收工三连 WORKLOG → commit（T-14b: …）→ push；停下等验收。
```

> T-14b 验收通过后进入 **M2.0 正式波**：T-15 AI 基座 → T-16 主页 AI 建议 → T-17/T-18 → T-19 → T-20（拆票表见 `TICKETS_M2A.md`；**T-15 启用条件**：用户已就 `design/ai_wave_preview.html` 拍板 → 管理层冻结 `DESIGN_AI.md`）。

## C. 备查：M2.0 正式波（AI）—— T-15 施工 prompt

> **启用条件**：用户已就 `design/ai_wave_preview.html` 拍板（配置页 / 主页 AI 位 / 对话窗口 各选一方向）且管理层已冻结 `DESIGN_AI.md`。**未拍板前不要派工**（UI 大改流程：先预览稿 → 拍板 → 冻 spec → 派工）。
> T-14（`6133d61`+`79eaa74`）已于 2026-09-14 验收通过；M2.0 前置波全部关闭。

**T-15（AI 基座：BYO 配置页 + key 安全存取 + OpenAI 兼容客户端 + 测试连接）**
```
继续 Gringotts 施工。M2.0 正式波开工，本票 = T-15 AI 基座。先读 PROJECT_STATE.md + TICKETS_M2A.md 的 M2.0 正式波表与 T-15 + DESIGN_AI.md（用户已拍板的 UI 冻结稿）。
任务：① BYO 配置页（provider / baseURL / apiKey / model，OpenAI 兼容协议；按 DESIGN_AI 选定方向落地）② key 只进 flutter_secure_storage（禁硬编码/禁进 git/禁进 log）③ 客户端：chat/completions 调用 + 超时与错误分类（未配置/401/超时/网络失败）④ 「测试连接」一键验证 + 三态反馈 ⑤ 设置入口（从任一 tab 可达）⑥ 无 key 时的全局引导态（AI 位与后续对话都指向配置页）。
顺带（已批准）：开工先跑 `python tool/photo_gc.py`（dry-run 确认 7 个孤儿），确认后 `--apply --backup-dir <仓库内 tmp>` 清理并在 WORKLOG 记数；再跑一次 `flutter build apk --release` 出包（T-14 的统计页视觉改动至今未入包）。
验收：① key 不出现在源码/日志/git（grep 断言）② 连接成功/失败/超时三态有明确文案且可复现（用假 baseURL 造失败）③ 配置页从任一 tab 可达 + 重启后配置留存（secure storage 读回断言）④ analyze 零错 + test 全绿（196 + 新增）⑤ APK 重建交付（gringotts-T15-release.apk + md5）。
规则：每完成一个 Part 立即 WIP 提交；收工三连 WORKLOG → commit（T-15: …）→ push；停下等验收。
```
> 之后按 `TICKETS_M2A.md` 波表顺序：**T-16 主页 AI 分析与建议**（价值兑现票，只喂聚合统计 JSON）→ T-17 / T-18 → T-19 → T-20。
