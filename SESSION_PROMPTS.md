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

## B. 【已归档】执行层 T-14b prompt（该票已于 2026-09-15 验收通过，含熔断规则；仅存历史）

> 归档说明：T-14b 施工中断 → 保全 → 收尾，两次 prompt 均已完成使命。下一个派工对象取决于用户安排（M2.0 正式波暂缓中）。

```
你是 Gringotts 执行层的新 session（Codex）。档案 = C:/Users/JHarayden/Desktop/Gringotts；本目录开工会自动读 AGENTS.md。

先读三样（其余不必读）：PROJECT_STATE.md → TICKETS_M2A.md 的 T-14b「现状与剩余」（**先读这一节**）→ WORKLOG.md 顶部两条。设计真相源按需只读 DESIGN_MAIN.md §8，不要整篇读。

上一轮施工中断，但 Part A + Part B 已完成并保全：WIP 14c942e + 0cc6190 已 push；管理层实测 flutter analyze 零问题、flutter test 207 全绿。**你的任务是收尾，不是重做 —— 不要重构 Part A/B 的任何实现。**

剩余五项（逐项做完即停）：
① 修 integration_test/t13b_full_chain_test.dart:181：从「明细」返回后落点是**统计 tab**（明细是统计页子页），此时 home_record_key 不在台上 ⇒ 改为「先断言已回到壳 + key 不在台上 → tap(Key('tab_home')) → 断言 key 在台上」，然后继续跑完 export 段（CSV BOM + 编辑后商户/金额 + JSON 资产，逐字节）。
② 只重跑 t13b_full_chain_test（若你的改动触及 t12c_shell_test 则一并跑）。**禁止全量重跑 14 个 integration** —— 13 个已 exit=0，日志在 evidence/t14b/regression/。
③ 补 evidence/t14b/ 的帧 md5 清单（帧 md5 清单入库、PNG 本地）+ 一行「哪帧证明哪条 §8.5 断言」的映射表（visual_checks.txt 已有像素级校验可作基础）。
④ flutter build apk --release → 桌面 gringotts-T14b-release.apk + 记录 md5（把 T-14 的统计页改动一并入包）。
⑤ WORKLOG 顶部追加执行层条目 → 本票 commit（T-14b: …）→ push。

熔断规则（硬性；上一轮就是踩了这个坑）：
- 同一条命令 / 同一个脚本最多跑 2 次，且第 2 次必须由新事实驱动（改了代码或加了日志）。**第 3 次禁止** —— 改为把失败断言原文 + 已排除的假设写进 WORKLOG 顶部，commit WIP，然后**停下报告**，不要继续试。
- 若出现 harness 内部错误（如 `DSH ACP: Internal error`）或工具返回异常：**立即停手**，不要重试刷屏；把现场（最后一条命令 + 最后一段输出）写进 WORKLOG 后停下。
- 不要为了跑绿而降低断言、加 skip 或删测试；失败如实上报。
- 照片孤儿已 apply、MiSans subset 已完成 —— 都不要重复执行；不要改 AGENTS.md / DESIGN_MAIN.md / TICKETS_M2A.md。

验收依据：DESIGN_MAIN.md §8.5 七条 + 本票「验收（全票）」；停下等验收。
```

> M2.0 正式波（T-15 起）**按用户安排暂缓**；本票验收通过后由管理层请用户指示，不要自行启动。

## C. 备查：T-21 施工 prompt（下一票 = M1 系列收官，规格已冻结）

> 启用条件：无（规格已冻结在 `DESIGN_MAIN.md` §11，用户 2026-09-15 拍板）。M2.0 正式波仍按用户安排暂缓，**不要在 T-21 里夹带 AI 相关改动**。

```
你是 Gringotts 执行层的 session（Codex）。档案 = C:/Users/JHarayden/Desktop/Gringotts；本目录开工会自动读 AGENTS.md。

先读三样（其余不必读）：PROJECT_STATE.md → TICKETS_M2A.md 的 T-21（含诊断与验收）→ **DESIGN_MAIN.md §11（本票唯一规格来源，逐条照做）**；不要再读别的设计章节。

本轮任务 = T-21（统计页图表重整 + 收入/存款语义），按 DESIGN_MAIN §11 分五块，每块做完立即 WIP 提交：
Part A 服务层（StatisticsService）：日视图改为「所选月每一天」（28–31 桶，不再是 7 桶）；月/年口径照 §11.2；新增「保底收入均摊」计算（月收入 ÷ 当月天数）与「临时收入按日」聚合；全部为纯函数可单测。
Part B 图表层（两张图，§11.2 / §11.3）：图 1 = 支出柱 + 额度虚线（goldAccent dash 4/3）+ 超额段 semanticExpense + 临时收入绿点；图 2 = 双线（支出 semanticExpense / 收入 semanticIncome，收入含保底均摊）；**纵轴必须开金额刻度（原实现是 showTitles:false，必须改）**；**横轴标签 x 必须等于数据点 index（原实现用 length/6 导致滑移，禁止再出现非整数 interval）**；空态/单点/极值不崩。
Part C 月份联动（§11.4）：统计页顶栏加与主页同款月份按钮（复用同一月历 sheet），selected month 与主页/明细同源，切一处三处同步。
Part D 存款转资产（§11.5）：budget_months 加 savingsConfirmedAt / savingsSkippedAt（schemaVersion 3→4，addColumn）；AssetCategory 加 savings；分析页 Hero 下方提示卡（两动作 + 幂等）；「存进资产」生成存款类资产、「没攒够」零落库；**派生值一律现算不落库**。
Part E 收尾：run 受影响 integration（统计/主页/资产相关，例 t05 / t10b / t14b 系脚本；**不要全量重跑 14 个**）→ 出 release APK（桌面 gringotts-T21-release.apk + md5，M1 收官包）→ WORKLOG → commit（T-21: …）→ push。

硬性规则（上一轮 harness 曾在失败脚本上死循环，管理层已立规矩）：
① 同一条命令 / 同一个 integration 脚本最多跑 2 次，第 2 次必须由新事实驱动（改了代码或加了日志）；**第 3 次禁止** —— 改为把失败原文 + 已排除假设写进 WORKLOG，commit WIP 后停下报告。
② 出现 harness 内部错误（如 `DSH ACP: Internal error`）立即停手，不重试刷屏。
③ 不许为了跑绿而降低断言 / 加 skip / 删测试；不许改 AGENTS.md / DESIGN_MAIN.md / TICKETS_M2A.md。
④ 数据库迁移前先备份 dev 库（tool/clean_dev_db.py 的 --report 参数可用），迁移测试必须断言旧数据可读。

验收：DESIGN_MAIN.md §11.6 六条 + T-21「验收」逐条给证据（结构化断言优先，帧 md5 清单入库、PNG 本地）；停下等验收。
```

## D. 备查：M2.0 正式波（AI）—— T-15 施工 prompt（⏸ 按用户安排暂缓中）

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
