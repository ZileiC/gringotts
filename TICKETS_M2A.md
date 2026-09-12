# TICKETS_M2A.md — M2.0 前置波派工工单（管理层发布 2026-09-11）

> 执行层（Codex）按序施工。设计要求唯一真相源 = **DESIGN_MAIN.md**（本波）+ DESIGN_T09.md（品牌/动效基线，仍有效）。
> 每票一 commit（`T-1x: <summary>`）并 **push**；收工写 WORKLOG（先重读最新版再顶部插入）；停下等管理层验收。
> **反浪费铁律**：证据脚本先声明前提（元素可见性 ensureVisible + DB 状态）；出问题换确定性手段（单测/数值读回/源码核查）定位；禁止盲目重跑。
> 回归重跑须落 `evidence/regression/`，**不得覆盖**各票 evidence 目录（M1.x 约定）。
> DoD（每票通用）：`flutter analyze` 零错误 + `flutter test` 全绿 + Windows 实跑证据（Dart PNG + md5 唯一）+ 受影响 integration 脚本通过。

## T-10 预算引擎 + 新主页（本波核心，功能与 UI 都是大头）
> **拆两步**：T-10a（数据+引擎，**与 UI 无关，立即可开工**）/ T-10b（主页 UI，**等用户过目第①屏后开工**）

### T-10a 数据层 + 预算引擎（立即可开工）
- 新表 `budget_months`：`id` UUID / `year_month` TEXT(`YYYY-MM`，唯一) / `income_cents` INT / `savings_target_cents` INT / 三时间戳 / `deleted_at` 墓碑
- 迁移 V2→V3：createTable（无历史回填）；仓储 `BudgetRepository`（按年月 upsert / 读单月 / 按月列表）
- 纯函数 `BudgetEngine`（全部整数分）：
  - `daysInMonth`（闰年判定）/ `remainingDays = daysInMonth − dayOfMonth + 1`（含今天）
  - `budgetCents = income − savings`；`spentCents` = 本月已确认支出（**draft/收入/transfer 不计**，T-05 口径）
  - `fixedDailyCents = budgetCents ÷ daysInMonth`（向下取整）
  - `remainingCents = budgetCents − spentCents`（可负）
  - `liveDailyCents = remainingCents ÷ remainingDays`（**向下取整**，负值显示钳 0）
  - 无预算记录 → 三个额度返回 `null`（**不显示假数字**）
- **边界单测全套**：跨月重置 / 2 月与闰年 / 当月最后一天(remainingDays=1) / 超支负值 / `budgetCents ≤ 0` 防御 / draft 不计 / 编辑历史记录后即时重算
- 验收：边界单测全绿 + analyze/test 全绿（**本步无 UI 变更，不动首页**）

### T-10b 新主页 UI + IA 切换（等用户过目 design/MAIN_preview.html 第①屏）
- 顶栏：月份标题（可左右切换看历史月，**只读**）+ 预算设置入口
- Hero 卡：eyebrow「今天还能花」+ **实时额度（Playfair 衬线 + 金渐变，tabular 数字）** + 副行「基准/剩余额度/剩 N 天」
- 进度区：本月已花 / 预算可花 + 进度条（gold，超支满格转 `semanticExpense`）+ 百分比 + 预算构成说明
- 今日行：今日已花金额 + 笔数
- 主 CTA「记一笔」→ 压栈进快记页；次级「明细」→ 明细页
- AI 占位卡（M2.0 填充，**不放假数据**）
- 引导态（无预算）：Hero 换「先设置本月预算」卡 → 预算 sheet（收入 + 计划存款，数字键盘输入）+ 「沿用上月数值」一键
- **IA 变更**：`main.dart` 首页改为分析页；快记页保留全部既有能力但降为二级（返回键回主页）。**T-09「首页即键盘」铁律作废**（用户 2026-09-11 明确推翻）
- **顺带项（管理层指令）**：更新 `AGENTS.md` 两处——①工作流程条款的「当前派工工单」指向 `TICKETS_M2A.md`（注明 `TICKETS_M1.md` 为已完成的 M1.0 存档）②UI 铁律中「首页即速记键盘、无导航层」已作废 → 改为「首页 = 分析页（A0），速记页为二级、[记一笔] 一键可达」。原因：管理层 session 对 AGENTS.md 的写入被防护栏拦下（授权超时），按规矩不绕过，转由执行层订正
- 验收：Windows 实跑三帧（引导态 / 已设置态 / 超支态）+ 受影响的 t09a/t09c/t09c2 速记相关 integration 断言按新 IA 更新后通过

## T-11 快记页重设计（**方向待用户选型后开工，禁止先动**）
- 用户将在 DESIGN_MAIN §4 三方向（A 素净计算器 / B 额度联动 / C 类别优先）中选一 → 管理层更新本票为「按方向 X 落地」后开工
- 整页重构为选中方向的视觉语言；**必须保留**：键盘 3 秒一笔、混合输入行解析、时段默认类别、高频 chip、午餐内联提示、收入切换、draft 入库、`TouchedScale` 触感与 `reduce-motion` 退化
- 明确移除（用户反馈「AI 味重」）：金渐变填充确认键 + sheen 扫光 + 发光/装饰性渐变（A/C 全无；B 仅保留金描边与极淡底）
- 验收：既有速记能力断言全绿（改造后不减少）+ 三帧 Windows 实跑（空态/输入态/收入态）+ reduce-motion 退化

## T-12 明细页（全部收支查看 + 全字段编辑，DESIGN_MAIN §5）
- 入口：主页「明细」按钮（+ 统计页可选）
- 列表：按日分组（今天/昨天/M月D日，组头 eyebrow）；行 = 类别点 + 商户/备注（空则类别名）+ 金额（支出 ink / 收入 `semanticIncome`）+ `待完善` 草稿标记
- 筛选：月份切换（默认当月）+ 类型 chips（全部/支出/收入）
- 点行 → 编辑 sheet：**全字段**（金额 / 类别 / 商户 / 备注 / 日期 / 类型支出收入）+ **删除**（二次确认 → 墓碑）
- 规则：草稿编辑后**保持草稿态**（转正式仍走回顾页批量确认，不绕过「先记后补」）；`updated_at` 刷新；编辑后统计与主页额度**即时联动**
- 验收：逐字段编辑单测 + 删除墓碑语义（raw 行留存）+ draft 保持 + 编辑→统计/额度联动断言 + Windows 实跑

## T-13 资产字体回归 + M1.x 小项清账
- **净值大数字恢复 Playfair 衬线 + 金渐变**（DESIGN_MAIN §6：管理层此前误读用户裁决导致该字体被移除，责任在管理层）；其余数字（列表值 / CPD 徽章 / 天数）保持 tabular sans
- M1.x 小项：①照片孤儿文件 GC（`gringotts/photos/` 无引用 hash 文件，扫 DB 引用后清理，需先 dry-run 后 apply）②回归重跑不覆盖各票 evidence（改落 `evidence/regression/`，本波生效）③启动画面 wordmark 去重（**待用户实机裁决**：裁徽标内文字 / 去下方独立 wordmark——用户未表态前不动）
- 验收：字体帧目检 + GC 前后 DB 引用一致性核对 + evidence 目录不被覆盖（跑一轮回归后 md5 不变）

---

## 施工顺序与依赖
```
T-10（预算引擎+主页，可立即开工）
  ├─→ T-11（快记重设计，★等用户选方向）
  └─→ T-12（明细页）
        └─→ T-13（字体回归 + M1.x 小项）
```
- T-10 与 T-12 无依赖，可并行；T-11 必须等选型；T-13 建议最后（避免与 T-10/T-11 同改 tokens 消费点）
- 任一票发现缺口 → WORKLOG 登记等管理层裁决，**不得自行扩范围**
