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

## C. 备查：T-21 施工 prompt（下一票 = M1 系列收官，规格已冻结；**已按 deepseek harness 调参**）

> 启用条件：无（规格冻结在 `DESIGN_MAIN.md` §11，用户 2026-09-15 拍板，含「两图上下排」「临时收入标注不参与图 2 缩放」两条确认）。M2.0 正式波仍暂缓，**不要在 T-21 里夹带 AI 相关改动**。
> 调参理由：deepseek harness 上一轮在回归阶段反复重跑同一脚本直到崩溃 ⇒ 本 prompt **分块 + 每块立即提交 + 熔断 + 失败可跳过上报**。

```
你是 Gringotts 执行层的 session（deepseek harness）。档案 = C:/Users/JHarayden/Desktop/Gringotts；开工自动读 AGENTS.md。

读三样即可：PROJECT_STATE.md → TICKETS_M2A.md 的 T-21 → DESIGN_MAIN.md §11（唯一规格，逐条照做）。不要读其他设计章节，不要读历史工单。

任务 = T-21（统计页图表重整 + 收入/存款语义）。**分 5 块，一块做完就 `git commit -m "WIP T-21: Part X"` 并在 WORKLOG 顶部写一行「Part X 完成 + 证据」，然后立刻做下一块。** 不要把 5 块攒到最后一起提交。

Part 1 服务层（先做，纯函数好测）
文件：lib/services/statistics_service.dart（+ 新增/修改单测 test/statistics_service_test.dart）
- 日视图改为「所选月每一天」：monthDays(selectedMonth) 桶（28/29/30/31），替换现在写死的 7 桶 dailyTrend
- 新增 incomeBaselinePerDay = 该月 budget.incomeCents ÷ 该月天数（无预算 → null）
- 月视图 12 桶、年视图按年（沿用现有口径）
- 全部为纯函数，可单测；顺手把 dailyTrend 的旧 7 桶调用点全部改掉（grep dailyTrend）
验收：单测覆盖 28/29/30/31 四种月份天数 + incomeBaselinePerDay（有预算/无预算两态）

Part 2 图 1（柱 + 额度线 + 超额红段 + 临时收入点）
文件：lib/pages/stats_page.dart
- 每天一根柱：不超额部分 elevated 填充 + hairline 边；超过「当天额度」的部分用 AppColors.semanticExpense
- 当天额度 = 可花预算 ÷ 当月天数；无预算则不画额度线，图上方一行 inkSecondary「先设置本月预算」
- 额度线 = goldAccent 1px 虚线（dash 4/3）
- 临时收入：该日有 income 流水 → 柱顶上方 4px semanticIncome 圆点（多笔取合计，点旁标数）
- 纵轴：必须开左轴金额刻度（现在写的是 leftTitles showTitles:false，必须改成 4 档：0 / ⅓ / ⅔ / max，格式 ¥1,200 千分位）
- 横轴：标签 x 必须等于数据点 index（现在写的是 interval: length/6，这是 offset 滑移的根因，禁止再出现非整数 interval）；日视图每 5 天一个标签 + 末尾必标

Part 3 图 2（双线，收入含保底均摊）
文件：lib/pages/stats_page.dart
- 支出线 semanticExpense；收入线 semanticIncome = 保底均摊（incomeBaselinePerDay）+ 当天临时收入
- 图 2 纵轴 = max(支出, 保底均摊) × 1.15；**临时收入不参与缩放**：该日画一条 semanticIncome 细虚线引到图内顶部 + 端点 3.5px 圆点 + 数值（如「12 号 临时收入 +¥800」）
- 无预算：收入线只含临时收入，图下一行说明「未设本月预算，收入线仅含临时收入」
- 两张图上下排列（图 1 在上）；空态「这个周期还没有记录」，单点/极值不崩

Part 4 月份联动
文件：lib/pages/stats_page.dart（+ 如需共享状态则加 provider）
- 统计页顶栏加月份按钮（复用主页同一套月历 sheet 组件，不要新造）
- selected month 与主页、明细页同源：任一处切换三处同步
验收：切月后统计页数据 = 该月数据（状态断言），未来月仍灰显不可选

Part 5 存款转资产
文件：lib/data/app_database.dart（+ 重新生成 .g.dart）、lib/domain/models.dart、分析页 lib/pages/home_page.dart、仓库/服务层
- budget_months 加两列 savingsConfirmedAt / savingsSkippedAt（nullable DateTime），schemaVersion 3→4 用 addColumn 迁移，旧数据必须可读
- AssetCategory 加枚举值 savings
- 分析页 Hero 下方提示卡：条件 = 该月 savingsTargetCents > 0 且两列皆 null；文案两键「存进资产」/「这个月没攒够」；当月最后 3 天加一句「这个月快结束了」
- 「存进资产」→ 新建资产：name「<M> 月计划存款」、category savings、valueCents = savingsTargetCents、purchasedAt = 该月最后一天 12:00、note「由月度计划存款确认生成」；写 savingsConfirmedAt；**幂等**（同月重复调用返回既有资产，不新建）
- 「这个月没攒够」→ 只写 savingsSkippedAt，**零资产落库**
- 派生值一律现算不落库（额度、均摊都不许建列）
验收：未操作时资产表零新增；确认后资产页出现该条（金额/类别/日期断言）；「没攒够」零新增；重复确认不产生第二条

最后（Part 6 收尾）
- 受影响 integration 只跑这些：t05_stats_test、t10b_home_test、t13b_full_chain_test（统计页/主页/全链路），**不要跑其余 10 个**
- flutter analyze（必须 No issues found）+ flutter test（必须全绿，报数量）
- flutter build apk --release → 复制到桌面 gringotts-T21-release.apk + 记 md5
- WORKLOG 顶部写执行层条目 → git commit -m "T-21: …" → git push → 停下等验收

硬性规则（上一轮 harness 在失败脚本上死循环直到崩溃，管理层已立规矩，违反即返工）
① 同一条命令 / 同一个脚本最多跑 2 次；第 2 次必须有新事实（改了代码或加了日志）。**第 3 次禁止** —— 改为把失败原文 + 已排除的假设写进 WORKLOG，commit WIP，**跳过该块继续下一块**，最后在报告里列为遗留。
② 出现 harness 内部错误（DSH ACP: Internal error 之类）立即停手：不要重试、不要刷屏，把现场写进 WORKLOG 后停止本次施工。
③ 不许为了跑绿而降低断言 / 加 skip / 删测试；不许改 AGENTS.md / DESIGN_MAIN.md / TICKETS_M2A.md / PROJECT_STATE.md。
④ 跑迁移测试前先备份 dev 库：python tool/clean_dev_db.py --report evidence/t21/dev_db_cleanup.json（apply 前先 dry-run 看数量）。
⑤ 报告只写结论 + 证据（命令、数值、文件行号），不要复述过程。

停下等验收。
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
