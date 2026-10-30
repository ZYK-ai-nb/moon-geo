# 同类调研与独立贡献

检索与源码抽查：2026-10-29 至 2026-10-30。原交接书“MoonBit 没有计算几何或空间索引库”的结论已撤回。本项目不宣称全球唯一、生态首个或全面优于其他项目。下表限于列出的固定提交及本次抽查内容；未运行竞品，不能推断整体正确性或性能。

| 项目 | 本次核查入口 | 重合与本项目取舍 |
|---|---|---|
| [cn-xjr/moongeokit](https://github.com/cn-xjr/moongeokit/tree/0300c9cd7600c255011ddae96c9f7d929679e18a) | README、[robust.mbt](https://github.com/cn-xjr/moongeokit/blob/0300c9cd7600c255011ddae96c9f7d929679e18a/robust.mbt) | 几何、动态增删改、区域候选及诊断已有明显重合，其索引采用固定世界均匀网格；抽查的 `orientation_sign` 使用调用者给定容差。本项目采用动态 R-tree 和对输入 Double 精确求方向符号的回退。动态更新、诊断均不是本项目独有。 |
| [walkzzz/moon-geometry](https://github.com/walkzzz/moon-geometry/tree/10756656c02e787766a1a74f890d9513db12a042) | README、[adaptive_orient2d](https://github.com/walkzzz/moon-geometry/blob/10756656c02e787766a1a74f890d9513db12a042/base/adaptive_pred/adaptive_pred.mbt)、[rtree_insert](https://github.com/walkzzz/moon-geometry/blob/10756656c02e787766a1a74f890d9513db12a042/spatial/rtree/rtree.mbt) | 基础几何、带孔多边形和空间索引均有重合。抽查的 `adaptive_orient2d` 不确定分支未调用精确整数回退；对应 `rtree_insert` 追加至根节点。本项目的方向回退使用 BigInt，R-tree 支持分裂和删除重整；不能据此评价对方其他函数或整个项目。 |
| [LING71671/MoonSTRtree](https://github.com/LING71671/MoonSTRtree/tree/de80237446811162f932c78792ad7ed82992f3ab) | README、静态索引定位 | 索引和区域功能重合，其公开说明为构建后不可变；本项目使用可动态插入、删除和维护的 R-tree。对方还提供多维与轨迹等能力；没有速度优胜结论。 |
| [sssssurf/geocodec](https://github.com/sssssurf/geocodec/tree/f7a2945e1e1b057280cd5254a8fe53048f53f979) | README，位置编码 | 已有 geohash 等能力，因此本项目从首版移除 geohash。 |
| [SupremeHuaji/Quadtree](https://github.com/SupremeHuaji/Quadtree) | README | 说明已有 MoonBit 空间查询生态；本项目不据此声称所有索引能力都是空白。 |
| [mourner/robust-predicates](https://github.com/mourner/robust-predicates) | README、orient2d 实现思路 | 可借鉴把数值可靠性落到算法和反例；本项目没有拷贝其 JS，也不宣称鲁棒谓词算法为原创。 |
| [mourner/rbush](https://github.com/mourner/rbush) | README、动态索引 API | 可借鉴小接口和明确查询语义；本项目不宣称实现其批量装载或性能水平。 |

一个可复核的设计取舍：上述 MoonGeoKit 固定版本的 [GridSpatialIndex](https://github.com/cn-xjr/moongeokit/blob/0300c9cd7600c255011ddae96c9f7d929679e18a/grid_index.mbt) 使用预设 world，与 world 完全不相交的包围盒不能由该网格索引插入或更新。MoonGeo 的 R-tree 不要求预先设置全局范围，在坐标契约内可直接插入远处的区域；`moon run examples/service_area --target js` 包含该步骤。这只比较 MoonGeoKit 的网格索引，不能推广到其其他索引，也不是性能优劣结论。

## 可核验的贡献

1. 用 core/bigint 对真实输入 Double 求精确方向符号；筛选不确定时执行实质计算，不返回“足够接近所以共线”。180 条独立 Fraction 符号数据用于跨后端核对。
2. 实现节点容量约束、真实二次分裂、删除下溢重插和根收缩，提供结构验证器与实际计数；随机混合操作会检查结构和查询结果。
3. 统一 Polygon 外环、孔洞、边界归属以及区域候选精化，返回 component、ring、edge、边界段和索引 revision；包围盒误命中保留诊断。

实际使用时，该组合面向区域边界判定和频繁变更的平面区域索引；这是一项有待用户验证的定位，不代表市场需求或独特性已获证明。以上是本次实际实现的能力组合，不构成“没有任何其他库具备同样能力”的保证。调研是有限范围的技术比较，不是完整的依赖审计、质量排名或对其他项目验收结果的判断。
