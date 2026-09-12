# TICKETS_M2A.md — 工单（当前：T-12b / T-13）

> 规则：一次一票；不得收窄或改写工单语义，缺口记 WORKLOG 等管理层裁决；DoD 通用 = analyze 零错误 + test 全绿 + Windows 实跑证据（Dart PNG + md5 唯一）+ 受影响 integration 通过；**收工三连 WORKLOG → commit → push**。

## 已完成（索引，细节见 WORKLOG_ARCHIVE.md）
| 票 | 内容 | commit |
|---|---|---|
| T-10a | 预算引擎 + `budget_months`(V2→V3) + 边界单测 | `6733f65` |
| T-10b | 新主页 UI + IA 切换（今日饼图 / 固定底栏 / 引导态） | `41ae607` |
| T-11 | 快记页重设计（两输入 / 4×3 含小数点 / 3×3 类别 / 描边确认键） | `17c135f` |
| T-11b | 顶部证据帧 + 额度联动断言 | `25a4b32` |
| T-12 | 明细页（月→日→条目 / 全字段编辑 / 草稿徽章迁主页 / SheenSweep 清理） | `e581909` |

---

## T-12b —— ⚠️ 已合并入下方 T-12c 的 Part C（本节保留为缺陷原始记录，勿单独施工）
**缺陷**：`TransactionRepository.updateFields` 无条件写 `Value(merchant)` / `Value(note)`；调用方 `ReviewPage._applyBulkAndConfirm`（`review_page.dart:54`）只传 `categoryId` ⇒ **回顾页批量补类别会把草稿的商户与备注清成 null**（用户主流程静默数据丢失，管理层已源码级实锤）。
**修法（择优）**：用 drift 的 `Value<String?>` 区分「未提供 = `Value.absent()` 不动」与「置空 = `Value(null)`」；或每字段加显式 flag；**审计 `updateFields` 全部调用点（含测试）**。`updateTransaction`（T-12 新增）已显式全字段写，无需改动。
**顺带**：证据脚本播种改用**固定时间戳**（本轮跨 run 帧 md5 漂移的根因是 now−2h 之类）。
**验收**：① 批量补类别后 merchant/note 原值保留（回归断言）② 显式清空仍可用 ③ analyze 零错误 + test 全绿。

## T-12c（结构+流程重构，P1，合并票）：导航层级 + 快记即正式 + 隐患收口
> 用户 2026-09-12 实机测试两条指令：①「批量补类型」已无意义（快记页可直接选类别）→ **整个删除**；且**记录不该等确认才被系统认账**——荒谬；②**快记页是分析页的下一级，资产/统计与首页平级**。故合并 T-12b（updateFields P1）、原 T-12c（导航补口）为一张票，一次改到位。

### Part A 导航层级重构（用户指令②）
- **顶级 = 底部 tab bar 三页平级：`分析` | `资产` | `统计`**（切换不压栈，各带独立 key：`tab_home` / `tab_assets` / `tab_stats`）
- **「记一笔」= 底栏上方的居中主按钮**（金渐变实心，悬浮/独立条均可）；点击 **压栈进入快记页**——快记页 = 分析页的**下一级**，返回回分析页
- **明细页 = 统计页的子页**（统计页顶部加「明细 ›」入口；原分析页底栏的 `明细` 按钮删除）
- **快记页顶栏三入口删除**（`quick_review` / `quick_assets` / `quick_stats`）——资产/统计 已成顶级 tab，回顾页即将删除
- 分析页底栏的 `[记一笔][明细]` 双按钮结构**取消**（被 tab bar + 主按钮取代）

### Part B 快记即正式：废除草稿链路（用户指令①）
- **快记页确认键直接写正式记录**（`is_draft = false`），立即进统计/预算/明细，**不再需要确认步骤**
- **删除**：回顾页（`review_page.dart`）及其入口、`_applyBulkAndConfirm` **批量补类别**、主页「今日 N 笔待完善」徽章与 `watchTodayDraftCount`、明细页「待完善」草稿标记的分支
- **保留**：`is_draft` 列与统计/预算里的草稿排除逻辑（**不迁移、不删列**；无新草稿产生即无害，且兼容历史数据）
- **清库**：dev 库如有 live 草稿，随本票墓碑清理（应已为 0）
- **测试处置**：`t03_flow_test.dart`（整条草稿链路）**删除**；`draft_workflow_test.dart` 中草稿确认用例删除、保留其中仍适用的统计口径断言（改为直接建正式记录）；`widget_test`/`home_page_test` 中依赖徽章或草稿的断言同步删改；**不得留下引用已删组件的死测试**
- **文档顺带（执行层可直接改）**：`AGENTS.md` 数据铁律里「速记以 draft 入库…确认后才进统计」一条**改为**「快记即正式（`is_draft=false`），立即计入统计；草稿链路已废除」；`DESIGN_MAIN.md` §4.1 保留清单里的「draft 入库」与 §5 的草稿标记同步订正

### Part C 隐患收口（原 T-12b）
- `updateFields` 曾无条件写 `Value(merchant)`/`Value(note)`；**其唯一危险调用点 `review_page.dart:54` 随 Part B 删除** → 改为：审计全部剩余调用点，**若已无调用则整方法删除**（优于留一个陷阱），有调用则改 `Value<String?>`（absent=不动 / null=清空）
- 顺带：证据脚本播种改用**固定时间戳**（跨 run 帧 md5 漂移根因）

**验收**：① 三 tab 平级切换 + 「记一笔」压栈进快记页 + 返回回分析页（导航断言）② 统计页可达明细页 ③ **快记一笔后立即可在明细/统计/主页额度中看到**（不再需要确认）④ 回顾页/批量补类别/徽章相关代码与测试全部清除（无死引用）⑤ `updateFields` 无陷阱残留 ⑥ analyze 零错误 + test 全绿（数量变化需说明哪些测试被删）⑦ Windows 实跑帧（Dart PNG + md5 唯一）⑧ **完成后重建 release APK 交付用户做全流程真机测试**

---

## T-13（收尾票）
1. **资产页字体回归**：净值大数字恢复 **Playfair 衬线 + 金渐变**（其余数字保持 tabular sans）；其余列表/CPD/天数不变
2. **照片孤儿文件 GC**：`gringotts/photos/` 无 DB 引用（含墓碑）的 hash 文件清理；**先 dry-run 后 apply**，输出前后数量
3. **M1.x 清账**：t09e 内注释「keypad home」等过时表述订正（如再触碰）
4. **启动画面 wordmark 去重**：⚠️ **待用户裁决**（徽标内含 wordmark + 下方独立 wordmark 重复）——用户未表态前不动
5. **全量回归**：速记→draft→补全→统计→资产→详情→编辑→明细→导出 全链路实跑；release APK 重建
6. **T-13 完工报告**：对照 DESIGN_T09 §8 + DESIGN_MAIN，逐页核对

## 后续（M2.0 正式波，待管理层派工）
BYO AI 配置（provider/baseURL/key/model）+ 主页 AI 分析建议 + 对话窗口 + 图表 AI 解读 + 预算与周期账单 + Widget + 本地加密。路线图详情见 `HANDOFF_MANAGEMENT.md` §6。
