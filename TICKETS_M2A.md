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

## T-12b（P1 必修）：`updateFields` 数据丢失
**缺陷**：`TransactionRepository.updateFields` 无条件写 `Value(merchant)` / `Value(note)`；调用方 `ReviewPage._applyBulkAndConfirm`（`review_page.dart:54`）只传 `categoryId` ⇒ **回顾页批量补类别会把草稿的商户与备注清成 null**（用户主流程静默数据丢失，管理层已源码级实锤）。
**修法（择优）**：用 drift 的 `Value<String?>` 区分「未提供 = `Value.absent()` 不动」与「置空 = `Value(null)`」；或每字段加显式 flag；**审计 `updateFields` 全部调用点（含测试）**。`updateTransaction`（T-12 新增）已显式全字段写，无需改动。
**顺带**：证据脚本播种改用**固定时间戳**（本轮跨 run 帧 md5 漂移的根因是 now−2h 之类）。
**验收**：① 批量补类别后 merchant/note 原值保留（回归断言）② 显式清空仍可用 ③ analyze 零错误 + test 全绿。

## T-13（收尾票）
1. **资产页字体回归**：净值大数字恢复 **Playfair 衬线 + 金渐变**（其余数字保持 tabular sans）；其余列表/CPD/天数不变
2. **照片孤儿文件 GC**：`gringotts/photos/` 无 DB 引用（含墓碑）的 hash 文件清理；**先 dry-run 后 apply**，输出前后数量
3. **M1.x 清账**：t09e 内注释「keypad home」等过时表述订正（如再触碰）
4. **启动画面 wordmark 去重**：⚠️ **待用户裁决**（徽标内含 wordmark + 下方独立 wordmark 重复）——用户未表态前不动
5. **全量回归**：速记→draft→补全→统计→资产→详情→编辑→明细→导出 全链路实跑；release APK 重建
6. **T-13 完工报告**：对照 DESIGN_T09 §8 + DESIGN_MAIN，逐页核对

## 后续（M2.0 正式波，待管理层派工）
BYO AI 配置（provider/baseURL/key/model）+ 主页 AI 分析建议 + 对话窗口 + 图表 AI 解读 + 预算与周期账单 + Widget + 本地加密。路线图详情见 `HANDOFF_MANAGEMENT.md` §6。
