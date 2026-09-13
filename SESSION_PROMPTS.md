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

## B. 执行层 T-12c **续工** 的施工 prompt（复制即用）

```
继续 Gringotts 施工：T-12c 续工。先读 PROJECT_STATE.md + TICKETS_M2A.md 的 T-12c（「现状 / 剩余」两段）+ WORKLOG.md 顶部管理层条目；设计细节只在需要时读 DESIGN_MAIN §3 第 1 条。不要整篇读设计文档。

背景：T-12c 四部分上一轮已写完并保全在 commit cc26215（未验收，勿重做）。你的任务是把剩余项收干净。

剩余项：
① test/home_shell_test.dart 会挂死整轮 flutter test（单独跑 90s 超时）——两个用例要修：AssetsPage 断言需 skipOffstage: false（IndexedStack 非选中页是 offstage）；「记一笔压栈」用例 pending drift Timer 未释放（补 close/addTearDown/pumpAndSettle）。
② test/home_page_test.dart 的「月历 sheet 切换月」用例失败（伴随 deactivated widget ancestor）——查 sheet pop 后 setState 时序。
③ 管理层裁决：从任一 tab 点「记一笔」，返回必须落回分析页 → _openQuickEntry 前 _index = 0，并补导航断言。
④ 月历补「未来月灰显不可点」断言（原 future 箭头断言已随箭头删除），并断言箭头无残余 key。
⑤ 证据：受影响 integration 逐个跑通（t10b/t11/t12 属回归，帧落 evidence/regression/，不覆盖原票 evidence）；新增 t12c 专属 integration（tab 切换不压栈 / 记一笔压栈 / 月历切换），帧 md5 唯一。反浪费：脚本先声明前提，播种用固定时间戳，失败不盲目重跑。
⑥ 收工：重建 release APK（gringotts-T12c-release.apk）交付用户；申报「删了哪些测试 / 改了哪些 / 各自结果」与测试数量变化。

不要改 DESIGN_MAIN.md 与 AGENTS.md（管理层已按用户 2026-09-13 授权订正完毕，你改了会冲突）。
规则：每完成一个 Part 立即 `git commit -m "WIP T-12c: Part X"`（掉线保险，AGENTS.md 工作流程第 4 条）；收工三连 WORKLOG → commit（T-12c: …）→ push；停下等验收。
```

## C. 备查：T-14 施工 prompt（下一票，收口小票）

> T-13a / T-13b 均已验收通过（M2.0 前置波关闭，2026-09-13）；其施工 prompt 已归档到 WORKLOG 验收记录，不再复用。

**T-14（收口小票：四项 spec/记录对齐 + 照片孤儿例行化）**
```
继续 Gringotts 施工。M2.0 前置波已关闭（T-13b 验收通过）。先读 PROJECT_STATE.md + TICKETS_M2A.md 的 T-14 + DESIGN_T09 §8.5。
任务（四小项，均 P3 收口）：
① 统计页净结余负值配色对齐 spec：stats_page.dart:138-147 无颜色分支 ⇒ 负值仍暖白 ink → 改为「负值 AppColors.semanticExpense、零/正 AppColors.ink」，补单测（负值红 / 零与正值暖白）。
② 统计页导出键形态对齐 spec：FilledButton.tonalIcon（goldContainer 实心 pill）→ hairline 金描边 outline 键（OutlinedButton + goldAccent fine 边 + 金字）。理由：项目「金色克制」章程——金只作描边/文字，不作大面积填充。
③ 证据帧名过时：t09e 02_keyboard_after_splash（内容=启动后主页）、t09c 01_home_idle（内容=快记页 idle）→ 更名与实际内容一致，md5 清单同步更新（帧本体内容不变）。
④ clean_dev_db.py 备份名前缀 pre-t09e-<stamp>.bak → pre-clean-<stamp>.bak。
⑤ 收尾跑一次 `python tool/photo_gc.py`（dry-run 报数；若要 apply 先确认），WORKLOG 记一行孤儿数——全量回归会自然产生孤儿（上轮实测 7 个 ≈30KB）。
验收：① 两项 spec 对齐有单测断言 + 帧（负值大数字为 semanticExpense、导出键为描边式）② 帧名/备份名改后相关脚本重跑全绿、md5 记录同步 ③ analyze 零错 + test 全绿（194 + 新增）④ 孤儿报数留档。
规则：每完成一个 Part 立即 WIP 提交；收工三连 WORKLOG → commit（T-14: …）→ push；停下等验收。
```
> T-14 之后进入 **M2.0 正式波**（BYO AI 配置页 → 主页 AI 分析建议 → 对话窗口 → 图表 AI 解读 → 预算与周期账单 → Widget + 本地加密）；派工前由管理层先把该波拆票写进 `TICKETS_M2A.md`。
