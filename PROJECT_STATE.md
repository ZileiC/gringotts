# Gringotts — 项目主页（交接入口）

> 每个 session 先读本文件；细节以档案为准。新的管理层 session 另读 `HANDOFF_MANAGEMENT.md`（协议/成本/路线图详情，只需读一次）。

## 状态（2026-09-13）
- **M2.0 前置波**：T-10a 预算引擎 ✅ / T-10b 新主页(=启动页) ✅ / T-11 快记页重设计 ✅ / T-11b 补口 ✅ / T-12 明细页 ✅ / **T-12c 四部分已施工未验收**（WIP 保全 `cc26215`，执行层掉线）
- **下一票**：**T-12c 续工**（修 3 个失败用例 + 返回落分析页 + 月历断言 + 证据 + APK）→ **T-13a**（资产字体回归/照片 GC）→ **T-13b**（wordmark 裁决/全量回归/APK/完工报告）；明细见 `TICKETS_M2A.md`，续工 prompt 见 `SESSION_PROMPTS.md` §B
- **交付物**：桌面 `gringotts-T11-release.apk`（md5 `3754a60a…`，待 T-12c 出包刷新）；仓库 github.com/jharayden/gringotts（private）
- **质量基线**：179 单测 + 3 个待修用例（`home_shell_test` 挂死整轮 `flutter test`，基线 commit `cc26215`）+ integration 全绿（t04/t05/t09a~e/t10b/t11/t12）；profile 0 missed frames；零硬编码色值

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
1. **T-12c 续工（下一票）**：四部分已施工并保全 `cc26215`（未验收）→ 剩余 = 修 3 个失败用例（含 `home_shell_test` 挂死整轮 test）+ 「记一笔」返回落分析页 + 月历未来月断言 + 证据帧 + release APK + 收工三连
2. **T-13a**：资产页净值字体回归 / 照片孤儿文件 GC（先 dry-run）/ M1.x 清账
3. **T-13b**：启动画面 wordmark 去重（⚠️ 待用户裁决）/ 全量回归 + APK / 完工报告
4. ✅ 2026-09-13 用户「权限全开」：`AGENTS.md` 已订正（快记即正式 / 三 tab IA / 金渐变例外 / 掉线保险 WIP 提交）；启动画面 wordmark 裁决延后（不阻塞）
5. 备用裁决池：截屏记账（M1.0 实测后定生死）、语音记账、剪贴板捕获
6. **流程条款**：验收记录里的挂账项必须写入下一张工单才算出账；发现执行层遗留的未提交施工 → 先 commit 保全（见 `HANDOFF_MANAGEMENT.md` §7 第 9 条）
