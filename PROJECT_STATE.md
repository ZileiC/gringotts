# Gringotts — 项目主页（交接入口）

> 每个 session 先读本文件；细节以档案为准。新的管理层 session 另读 `HANDOFF_MANAGEMENT.md`（协议/成本/路线图详情，只需读一次）。

## 状态（2026-09-14，T-14b **施工中断已保全区** —— Part A/B 完成全绿，剩收尾五项）
- **T-14b 进度**：Part A（`14c942e`）+ Part B（`0cc6190`）**已完成并已 push**；管理层实测 `flutter analyze` 零问题、**`flutter test` 207 全绿**；回归 14 个 integration **13 个 exit=0**
- **剩余（收尾 prompt 已就绪）**：① 修 `t13b_full_chain_test.dart:181` 陈旧断言（明细返回落统计 tab，key 不在台上）② 补 `evidence/t14b/` 帧 md5 清单与断言映射 ③ WORKLOG 执行层条目 ④ 出包 `gringotts-T14b-release.apk` ⑤ 收工三连 → 派工 prompt = `SESSION_PROMPTS.md` §B（含**熔断规则**）
- **中断事故记录**：上一轮 harness 反复重跑同一脚本（用户截断后 `DSH ACP: Internal error` 刷屏）→ 已保全 WIP、收窄重跑范围、写死熔断规则（见 WORKLOG 顶部与管理层 HANDOFF §7 第 11 条）
- **M2.0 正式波（含 T-15~T-20）按用户安排暂缓**（2026-09-14）→ 拆票表保留在 `TICKETS_M2A.md` 备查，**未获用户指示前不派工、不催办**
- **交付物**：桌面 `gringotts-T13b-release.apk`（md5 `e7c75551f5894e22e952df892de914f6`）；**T-14b 完成后出包** `gringotts-T14b-release.apk`（含 T-14 统计页改动 + 底栏重设计）；仓库 github.com/jharayden/gringotts（private）
- **质量基线**：**196 单测全绿且整轮正常退出**；全量回归 14/14 脚本；dev 库回归后 live 全 0；对比度 ≥ AA（最低 4.89）；零硬编码色值；工作区已内部清理（释放 ≈6.8GB，见 WORKLOG）

## 用户已定调（要点）
- 定位：AI+ 账本 app；**Android 手机为核心，Windows 辅助**；最终形态 = AI 理财提示 + 经济状况智能分析
- **主页 = 分析/指导页**（预算引擎：手填月度收入+计划存款 → 固定基准额度 + 实时剩余额度两个都要；无预算走引导态不显示假数字）；速记页降为二级（[记一笔] 一键可达）
- **快记页**：两输入（项目名称+数值）/ 键盘 4×3 含小数点（C 移出）/ 3×3 类别全显不横滑 / 键面与金额用衬线 / 金边描边确认键；**禁扫光与渐变**（用户评「AI 味重」）
- **明细页**：时间优先 `月 → 日 → 条目`；全字段可改 + 删除墓碑；日合计 = 可见行净额（已锁进设计）
- **资产页**：对标「有数」+ CPD 日均成本 + 变现复盘（净成本口径）；净值大数字恢复衬线金渐变（待 T-13）
- **AI**：BYO provider（baseURL/key/model 用户自配），M2.0 上线；落点=主页

## 铁律（协议）
- **本 session（Hermes）= 管理层**：方向/brainstorm/派工/验收/GitHub 仓库管理；**代码只读**，只动 .md
- **执行层 = Codex**：本目录开工自动读 `AGENTS.md`
- **收工三连**（执行层）：WORKLOG → commit → push（未提交/未推送视同未完工）
- **验收必标 commit hash**；破坏性 git 操作前先核对 log/status 并备案
- **反浪费**：禁盲目重跑；证据脚本先声明前提；播种用固定时间戳
- 详细协议、成本纪律、prompt 写法 → `HANDOFF_MANAGEMENT.md`

## 文件索引
`PROJECT_STATE.md` 本文件 · `HANDOFF_MANAGEMENT.md` 新管理层必读 · `AGENTS.md` 执行层约定 · `TICKETS_M2A.md` 当前工单 · `DESIGN_MAIN.md` 主页/快记/明细设计真相源 · `DESIGN_T09.md` 品牌与动效基线 · `FEATURES.md` 产品档案 · `WORKLOG.md` 施工日志(仅近轮) + `WORKLOG_ARCHIVE.md` 历史 · `design/*.html` 视觉稿 · `brand/gringotts-logo.png` 品牌源

## 路线图（详情见 HANDOFF_MANAGEMENT.md §6）
- **M1.0 本地核心账本** ✅ 完成（速记/回顾/资产+CPD/统计图表/导出/直达入口/品牌 UI）
- **M2.0 前置波**（进行中）：预算引擎 + 分析主页 + 快记重设计 + 明细页 → 余 T-12b/T-13
- **M2.0 正式**：BYO AI（provider 配置）/ 主页 AI 分析与建议 / 对话窗口 / 图表 AI 解读 / 预算与周期账单 / Widget / 本地加密
- **M3.0**：专家 skill 体系（每日建议、周月报）+ 知识库
- **M4.0**：Windows 端（镜像 + 分析工作台）+ 同步

## 开放项
1. **T-14b（当前票，P1）**：Part A 导航语义修正（「记一笔」仅属分析页——资产/统计无该入口、越权路径与断言全清、底栏高度恒定）＋ Part B 底栏重设计（按 `DESIGN_MAIN.md` §8 冻结稿·方向 A；用户改选 B/C 时同步改写）；**本票末出 APK**（`gringotts-T14b-release.apk`）
2. **待你拍板（两个设计稿）**：① `design/bottom_bar_preview.html`（底栏三方向 A/B/C —— T-14b Part B 用）② `design/ai_wave_preview.html`（AI 三屏各 2 方向 —— T-15 起用）
3. **M2.0 正式波（AI 上线）**：拆票见 `TICKETS_M2A.md`（T-15 AI 基座 → T-16 主页 AI 建议 → T-17 / T-18 → T-19 → T-20）；T-15 启用条件 = AI 三屏方向已拍板 → 冻结 `DESIGN_AI.md`
4. ✅ 2026-09-13/14 已验收：T-12c / T-13a / T-13b / T-14 —— M2.0 前置波全部关闭；workspace 已内部清理 ≈6.8GB
5. **待批准（防护栏拦截一次）**：`AGENTS.md` UI 结构行改为「记一笔仅属分析页」——该文件每回合注入执行层，建议尽快批准
6. 备用裁决池：截屏记账（M1.0 实测后定生死）、语音记账、剪贴板捕获
