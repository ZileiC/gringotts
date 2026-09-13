# Gringotts — 项目主页（交接入口）

> 每个 session 先读本文件；细节以档案为准。新的管理层 session 另读 `HANDOFF_MANAGEMENT.md`（协议/成本/路线图详情，只需读一次）。

## 状态（2026-09-13，T-13a 验收通过）
- **M2.0 前置波**：T-10a ✅ / T-10b ✅ / T-11 ✅ / T-11b ✅ / T-12 ✅ / T-12c ✅ / **T-13a ✅（`751509a`+`bf1ae2d`+`f90116f`+`4a943a3`+`fd14688`，净值衬线金渐变回归 / 照片孤儿 GC 67→56 / 月历 342dp 边界修好）**
- **下一票**：**T-13b（收尾 II，M2.0 前置波最后一票）**——wordmark 去重（待用户裁决）+ 全量回归（回归前先清 dev 库）+ release APK + 完工报告 + 工具/测试卫生；工单见 `TICKETS_M2A.md`，prompt 见 `SESSION_PROMPTS.md` §C
- **交付物**：桌面 `gringotts-T12c-release.apk`（62.8MB，md5 `8e508b6b83d138ec8eac9e818c2d8e03`；T-13b 将重建出包）；仓库 github.com/jharayden/gringotts（private）
- **质量基线**：**194 单测全绿且整轮正常退出**；integration 全绿（t04/t05/t09a~e/t10b/t11/t12/t12c/**t13a**）；证据帧 md5 唯一（帧含 dev 库/CPD 日期者仅 run 内可复现，已如实声明）；零硬编码色值

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
1. **T-13b（下一票，M2.0 前置波最后一票）**：① 启动画面 wordmark 去重（⚠️ **待用户裁决**）② 全量回归（**先清 dev 库**，覆盖三 tab + 记一笔压栈 + 明细挂统计页）③ release APK ④ 完工报告 ⑤ 工具/测试卫生（`photo_gc` selftest 环境依赖 + `--report` 参数化、`clean_dev_db --report`、`t04` 补墓碑 teardown）⑥ `splash.dart:9` 过时注释
2. ✅ 2026-09-13 **T-13a 验收通过**（`751509a`+`bf1ae2d`+`f90116f`+`4a943a3`+`fd14688`）：净值衬线金渐变（共享 token）/ 照片孤儿 GC 67→56 零误删 / M1.x 清账 / 月历 342dp 边界修好
3. ✅ 2026-09-13 用户「权限全开」：`AGENTS.md` 已订正（快记即正式 / 三 tab IA / 金渐变例外 / 掉线保险 WIP 提交）；T-12c 已验收（`a394df6`+`ce43036`）
4. 备用裁决池：截屏记账（M1.0 实测后定生死）、语音记账、剪贴板捕获
5. **流程条款**：验收记录里的挂账项必须写入下一张工单才算出账（T-12c→T-13a 月历边界、T-13a→T-13b 工具卫生与 t04 墓碑）；发现执行层遗留的未提交施工 → 先 commit 保全（`HANDOFF_MANAGEMENT.md` §7 第 9 条）
