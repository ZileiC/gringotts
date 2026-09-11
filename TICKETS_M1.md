# TICKETS_M1.md — T-09 派工工单（管理层发布）

> 执行层（Codex）按序施工。每张票完成即在 WORKLOG 记录并 commit（票号进 commit message）。
> 工单语义不得收窄或改写；有异议记 WORKLOG 等管理层确认。
> **Design token 铁律**：所有颜色/字体/间距一律经 `lib/ui/tokens.dart`，组件内禁止硬编码色值/字号。
> 完工定义（DoD）：`flutter analyze` 零错误 + `flutter test` 全绿 + Windows 实跑证据（截图/录屏帧 md5 唯一、全 Dart PNG）+ Android release APK 构建成功。

## 全局约定
- 版本目标 = **T-09（M1.0 品牌收官 + 用户增补三裁决）**；过程修补记 M1.x
- **设计细则唯一真相源 = DESIGN_T09.md**（用户已确认基调）：色板 tokens 全表 / 字阶 / 动效规格 / 高级动效层 / 资产详情页 / 金色章程 / 逐页要点——施工前通读，数值一律照抄 tokens 表
- 类别体系（v1 固定 seed，允许后补自定义）：餐饮 / 交通 / 购物 / 居住 / 娱乐 / 学习 / 医疗 / 人情 / 其他
- 资产分类体系（对标有数）：硬通货 / 数码 / 非标品 / 普通物品

---

## T-09A 色板与字体换肤（tokens 落地）
- tokens.dart 全表替换为 DESIGN_T09.md §1 数值：暖调黑金体系（canvas/surface/elevated/overlay/hairline/ink/ink2/金三阶/金容器对/语义红绿）
- 字阶按 §2（Perfect Fourth）+ tabular figures 金额铁律 + **金额数字保持现状无衬线（用户裁决①）** + Playfair Display 仅品牌 wordmark/启动画面
- buildAppTheme() 全量对齐；全库 grep 硬编码色值清零（唯一例外 tokens.dart）
- 验收：analyze/test 全绿；Windows 实跑截图 3 张（速记/资产/统计）对照 DESIGN_T09 §8 逐页要点；截图 Dart PNG + md5 唯一

## T-09B 资产详情页 + 多照片（用户裁决②③）
- **asset_photos 新表**（id UUID/asset_id FK/path/sort/三时间戳/deleted_at 墓碑）；schemaVersion V1→V2 规范迁移，旧单张照片自动落 sort=0（迁移单测）
- PhotoService 扩展：多选（multiImage）+ 拍照 → 压缩 + sha256 命名 + 幂等去重（沿用现有管线）；首图 = 主图（列表缩略图）
- 创建/编辑表单：照片区多选 + 拍照 + 缩略图横排可删（未入库移除零成本）
- **详情页**（§6 全项）：Hero 接力进页；hero 照片 PageView 横滑 + 页点 + 0.5x 视差；数据区（价值/购买日/持有天数/CPD 徽章/进度条；已卖出加差价红绿/保值率/**净成本/天 = D1 口径修正**）；操作区（编辑/卖出/退役/删除墓碑二次确认）
- 详情页数字与列表同源（CpdCalculator），单测锁定；**D1 缺陷随本票关闭**（列表已卖出 tile 同步改净成本口径 + 单测更新）
- 验收：迁移/同源/D1 单测；integration 补「创建多照片资产→列表→点入详情→翻照片→返回 Hero 逆向」链路；Windows 实跑

## T-09C 高级动效层（用户裁决④，参照 DESIGN_T09 §5）
- **A 惯性滚动**：自定义 ScrollPhysics（spring 高 stiffness + 摩擦余韵），资产/统计/回顾三页统一
- **B 视差**：详情页 hero 照片 0.5x（≤48px 铁律）；净值看板滚动「沉入」（0.85x + scale 0.98 + opacity 0.6）
- **C 微缩放**：TouchedScale 统一组件——可点 tile 0.98 回弹 spring 240ms / 键盘 0.97 / 确认键 0.96 + 触感，全 app 复用
- **D 成组入场**：列表 60ms stagger fade+12px 上移 280ms easeOutCubic，成组不逐个
- **E 共享元素**：列表照片缩略 → 详情 hero 大图 Hero 接力 350ms easeOutCubic，返回逆向
- 性能红线：全 Transform/Opacity 不触发重布局；ListView.builder 懒构建；60fps（WORKLOG 留滚动帧率描述）
- 无障碍：disableAnimations 全退化（§4/§5）；触感保留
- 验收：动效逐项截图/录屏帧（md5 唯一 + Dart PNG）；既有 85+ 单测全绿不回退

## T-09C2 动效补完（管理层裁决追加票，2026-09-11）
- **§4 基础动效三项**（DESIGN_T09 §4，T-09C 未含，本轮补）：
  - 净值 / 净结余**数字 count-up spring 400ms 临界阻尼**（仅页面进入与数值变化时触发；reduce-motion 直接呈现）
  - 确认键 **sheen 600ms 一次性**扫光（禁循环；reduce-motion 跳过，触感保留）
  - chip 选中 **AnimatedContainer 150ms**（选中色＝goldContainer/onGoldContainer）
- **P4 修复（必做）**：`TouchedScale` reduce-motion 下 `onPointerDown: null` 导致 `onPressHaptic` 不触发——触感与缩放动画解耦，reduce-motion 仍触发 haptic（spec「触感保留」）；补断言单测
- **Hero 飞行曲线 easeOutCubic（批准做，带回退条件）**：自定义转场曲线让 Hero 接力飞行走 easeOutCubic；**若引入 jank 或破坏 T-09B 已验证的 Hero 流程，立即回退 350ms 平台原生默认并在 WORKLOG 记录**
- 验收：三项动效各有确定性断言单测（count-up 值序、sheen 一次性不循环、chip 150ms）+ P4 触感断言 + Hero 回退条件记录；analyze/test 全绿；Windows 实跑帧（Dart PNG + md5 唯一）；reduce-motion 全项退化验证

## T-09D 编辑补完（管理层裁决追加票，2026-09-11）
- **购买日期编辑（P1 必做）**：编辑 sheet 增加购买日期选择——直接喂 CPD 与持有天数，填错即算错钱；改动后 `updated_at` 刷新，CPD 即时重算（同源 CpdCalculator）
- **照片管理（P2 必做）**：编辑 sheet 支持照片**增/删/设封面**（复用 multi-picker + PhotoService 压缩 hash 管线 + asset_photos 仓储：新增 sort 末位、删除=墓碑、设封面=sort 交换）；**不做拖拽排序**（防范围蔓延）
- **顺带项（T-09C2 裁决）**：snackbar 改 `SnackBarBehavior.floating` + 底部 margin（位于确认键上方，不遮挡确认键 sheen）；若与其它页一致性冲突，备选＝延迟 250ms 出现——一行配置 + 截图验证
- **顺带项**：把「证据脚本先声明前提（元素可见性 + DB 状态，ensureVisible 等）」写入 AGENTS.md 证据条款（反浪费铁律配套）
- 验收：购买日期改动→CPD 重算单测；照片增删/设封面单测 + 墓碑语义；integration 补「编辑资产：改日期 + 加照片 + 删照片 + 设封面 → 列表主图更新」链路；Windows 实跑

## T-09E 品牌收尾（原 T-09D 顺延）
- 启动画面（canvas 纯色 + 徽标 38% + Playfair wordmark「Gringotts」）+ Android 自适应图标（前景 G 龙 66% 安全区 / canvas 背景）+ Windows ico 多尺寸——源文件 brand/gringotts-logo.png
- 全量回归：速记→draft→补全→统计→资产→详情→编辑→导出 全链路 Windows 实跑（三段 integration 单跑拼合）；**含 t09b 第二处 ensureVisible 段的复跑验证**（T-09C2 遗留）
- **dev 库清理**：多轮证据脚本遗留的测试草稿/资产走墓碑清理（纯开发数据）
- **profile 模式帧率采样**（debug 帧耗时不再作证据，只作 debug 成本标注；真机 60fps 判定权归用户实装 APK 实感）
- release APK 重建 + WORKLOG 写 T-09 完工报告（DESIGN_T09 §8 逐页对照 + 动效清单对照）
- 不包含：AI 能力、预算、周期账单、加密、截屏解析、账户、多币种（负范围不变）
- 验收：回归证据 + 全部测试绿 + APK + **用户目测通过（最终拍板在用户）**

---

## 施工顺序
T-09C2 → T-09D → T-09E（C2 补动效缺口与 P4；D 补资产编辑；E 收尾拍板）
每票一 commit：`T-09x: <summary>`；发现缺口 → WORKLOG 登记，不得自行改需求
