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

## T-09D 收尾整合与品牌资产
- 启动画面（canvas + 徽标 38% + Playfair wordmark）+ Android 自适应图标（G 龙 66% 安全区）+ Windows ico 多尺寸——源文件 brand/gringotts-logo.png
- 全量回归：速记→draft→补全→统计→资产→详情→导出 全链路 Windows 实跑（三段 integration 单跑拼合）
- release APK 重建 + WORKLOG 写 T-09 完工报告（DESIGN_T09 §8 逐页对照 + 动效清单对照）
- 不包含：AI 能力、预算、周期账单、加密、截屏解析、账户、多币种（负范围不变）
- 验收：回归证据 + 全部测试绿 + APK + **用户目测通过（最终拍板在用户）**

---

## 施工顺序
T-09A → T-09B → T-09C → T-09D（A 是 B/C/D 的地基；B 与 C 可在 A 后并行；D 收尾）
每票一 commit：`T-09x: <summary>`；发现缺口 → WORKLOG 登记，不得自行改需求
