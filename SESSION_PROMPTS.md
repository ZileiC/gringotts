# SESSION_PROMPTS.md — 当前两个 session 的开场 prompt（复制即用）

> 维护：管理层。每次派工/交接后更新。**注意 T-12b 已合并入 T-12c（其唯一危险调用点在回顾页，随 Part B 删除）**。

## A. 新管理层 session 的开场 prompt

```
你是 Gringotts 项目的新任管理层 session（Hermes）。项目档案 = C:/Users/JHarayden/Desktop/Gringotts。

先读一次（仅此一次）：HANDOFF_MANAGEMENT.md —— 你的角色权限边界、双 session 协议、五层验收协议、成本纪律、施工 prompt 写法、M2.0/M3/M4 路线图、8 条事故教训都在里面。

日常开工只读三样：PROJECT_STATE.md → TICKETS_M2A.md（当前票 T-12c → T-13）→ WORKLOG.md 顶部两条。设计细节按需只读章节（如 DESIGN_MAIN §3），不要整篇读。

职责：brainstorm、派工、验收（结论必标 commit hash）、GitHub 仓库管理；代码只读不改。成本敏感：每票约 ¥15，严格执行 HANDOFF §4 降本纪律与 §5 prompt 写法。

接手第一件事：读 HANDOFF §8 开放项，然后给用户 T-12c 的施工 prompt（本文件 §B 已是现成版）。
```

## B. 执行层 T-12c 的施工 prompt（结构+流程重构，含原 T-12b）

```
继续 Gringotts 施工。先读 PROJECT_STATE.md + TICKETS_M2A.md 的 T-12c + DESIGN_MAIN.md §3 第 1 条（月份按钮与月历弹窗规格）——只读这些，其余不必读。

任务：T-12c 结构+流程重构（四部分，一次改到位）
Part A 导航层级：顶级=底部 tab bar 三页平级（分析/资产/统计，key: tab_home/tab_assets/tab_stats，切换不压栈）；「记一笔」= 底栏上方居中金色主按钮，点击压栈进快记页（快记页=分析页下一级，返回回分析页）；明细页改为统计页的子页（统计页顶部「明细 ›」入口）；删除分析页原 [记一笔][明细] 双按钮与快记页顶栏三入口（quick_review/quick_assets/quick_stats）。
Part B 快记即正式：快记确认直接写 is_draft=false，立即进统计/预算/明细；删除 review_page.dart 与批量补类别（_applyBulkAndConfirm）、主页待完善徽章与 watchTodayDraftCount、明细页待完善分支；is_draft 列与统计/预算的草稿排除逻辑保留（不迁移、不删列）；dev 库残留 live 草稿墓碑清理；t03_flow_test 整条删除、draft_workflow_test 草稿用例删除但保留其中统计口径断言（改为直接建正式记录）、widget_test/home_page_test 依赖徽章草稿的断言同步删改，不留死引用。
Part C 隐患收口：审计 updateFields 剩余调用点——无调用则整方法删除，有调用则改 Value<String?>(absent=不动/null=清空)。顺带：证据脚本播种改固定时间戳（跨 run 帧 md5 漂移根因）。
Part D 月份选择：主页左上月份标题改「月份按钮」，点开月历 sheet（规格严格照 DESIGN_MAIN §3 第 1 条：年份 ‹ 2026 › + 月份 3×4 宫格、当前月金边选中、未来月灰显禁用、选中即切换、与类别网格同语言、禁渐变投影）；删除右上左右箭头，只留预算设置 ⚙。

文档顺带（你直接改）：AGENTS.md 数据铁律「draft 入库…确认后才进统计」→「快记即正式（is_draft=false），立即计入统计；草稿链路已废除」；DESIGN_MAIN §4.1 保留清单的「draft 入库」与 §5 草稿标记录同步订正。

验收：①三 tab 平级切换 + 记一笔压栈进快记页（导航断言）②统计页可达明细 ③快记一笔后立即可在明细/统计/主页额度看到（无需确认）④回顾页/批量补类别/徽章 代码与测试全清（无死引用）⑤updateFields 无残留陷阱 ⑥月份按钮+月历可用、箭头已移除 ⑦analyze 零错 + test 全绿（申报时说明删了哪些测试）⑧Windows 实跑帧（Dart PNG + md5 唯一）⑨完成后重建 release APK 交付用户。
规则：收工三连 WORKLOG → commit（T-12c: …）→ push；停下等验收。
```

## C. 备查：T-13（T-12c 验收后派工）
资产页净值大数字恢复衬线金渐变 / 照片孤儿 GC（先 dry-run）/ M1.x 清账 / **启动画面 wordmark 去重（待用户裁决）** / 全量回归 + APK + 完工报告。
