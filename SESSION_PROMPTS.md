# SESSION_PROMPTS.md — 当前两个 session 的开场 prompt（复制即用）

> 维护：管理层。每次派工/交接后更新。
> 2026-09-13：执行层掉线事故 → T-12c 转为**续工票**（WIP 已保全 `cc26215`）；原 T-13 拆为 **T-13a / T-13b**。

## A. 新管理层 session 的开场 prompt

```
你是 Gringotts 项目的新任管理层 session（Hermes）。项目档案 = C:/Users/JHarayden/Desktop/Gringotts。

先读一次（仅此一次）：HANDOFF_MANAGEMENT.md —— 你的角色权限边界、双 session 协议、五层验收协议、成本纪律、施工 prompt 写法、M2.0/M3/M4 路线图、9 条事故教训都在里面。

日常开工只读三样：PROJECT_STATE.md → TICKETS_M2A.md（当前票 T-12c 续工 → T-13a → T-13b）→ WORKLOG.md 顶部两条。设计细节按需只读章节（如 DESIGN_MAIN §3 第 1 条），不要整篇读。

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

## C. 备查：T-13b 施工 prompt（下一票，M2.0 前置波最后一票）

> T-13a（`751509a`+`bf1ae2d`+`f90116f`+`4a943a3`+`fd14688`）已于 2026-09-13 验收通过；其施工 prompt 已归档到 WORKLOG 验收记录，不再复用。

**T-13b（收尾 II：全量回归与交付）**
```
继续 Gringotts 施工（M2.0 前置波最后一票）。先读 PROJECT_STATE.md + TICKETS_M2A.md 的 T-13b + DESIGN_T09 §8；设计细节按需只读章节。
任务：① 全量回归：快记→立即入账→统计→资产→详情→编辑→明细→导出 全链路实跑（须覆盖新导航：三 tab + 记一笔压栈 + 明细从统计页进入）② release APK 重建交付 ③ 完工报告：对照 DESIGN_T09 §8 + DESIGN_MAIN 逐页核对 ④ 工具/测试卫生（见工单第 5 项：photo_gc selftest 环境依赖 + --report 参数化、clean_dev_db --report、t04 补墓碑 teardown）⑤ splash.dart 过时注释收尾。
注意：工单第 1 项（启动画面 wordmark）用户已裁决「不动」——**不要碰启动画面**（DESIGN_T09 §8 第 6 条已锁定）。
关键前提：**全量回归前先 `python tool/clean_dev_db.py --apply` 清掉 T-04 遗留行**（否则帧不可信）；工具报告不得覆盖他票证据（先做第 4 项的 --report 参数化）。
验收：① 全链路 integration 通过且前置条件自声明，回归帧无未解释的重复 md5 ② 完工报告逐页无遗漏 ③ APK md5 交付 ④ analyze 零错 + 194 test 全绿 ⑤ 工具在普通 shell（TMP 不在仓库内）下 selftest / dry-run 均可独立跑通。
规则：每完成一个 Part 立即 WIP 提交；收工三连 WORKLOG → commit（T-13b: …）→ push；停下等验收。
```
