# 同类调研与独立贡献

检索日期：2026-10-29。原交接书“MoonBit 没有计算几何或空间索引库”的结论已撤回。本项目不宣称全球唯一、生态首个或全面优于其他项目。

| 项目 | 本次核查入口 | 重合与本项目取舍 |
|---|---|---|
| [cn-xjr/moongeokit](https://github.com/cn-xjr/moongeokit/tree/0300c9cd7600c255011ddae96c9f7d929679e18a) | 已有 Mooncakes 0.3.0；几何、网格索引和 robust.mbt | 基础几何及查询诊断有重合。本项目采用精确二进制有理数符号回退，配合动态分裂／删除 R-tree 和实际区域候选精化。不是给其接口换名。 |
| [walkzzz/moon-geometry](https://github.com/walkzzz/moon-geometry/tree/10756656c02e787766a1a74f890d9513db12a042) | README，base/adaptive_pred、base/filtered_predicates、base/exact_predicates、spatial/rtree | 存在大量同名几何与索引 API。本次抽查的 adaptive_orient2d 在不确定区间未调用精确整数回退；具体比较必须用上述版本、函数和独立输入复现，不能由此评价整个库。 |
| [LING71671/MoonSTRtree](https://github.com/LING71671/MoonSTRtree/tree/de80237446811162f932c78792ad7ed82992f3ab) | README、静态索引定位 | 索引和区域相关功能重合；其公开说明为构建后不可变，本项目首版集中于动态修改、结构维护和统一区域语义。没有速度优胜结论。 |
| [sssssurf/geocodec](https://github.com/sssssurf/geocodec/tree/f7a2945e1e1b057280cd5254a8fe53048f53f979) | README，位置编码 | 已有 geohash 等能力，因此本项目从首版移除 geohash。 |
| [SupremeHuaji/Quadtree](https://github.com/SupremeHuaji/Quadtree) | README | 说明已有 MoonBit 空间查询生态；本项目不据此声称所有索引能力都是空白。 |
| [mourner/robust-predicates](https://github.com/mourner/robust-predicates) | README、orient2d 实现思路 | 可借鉴把数值可靠性落到算法和反例；本项目没有拷贝其 JS，也不宣称鲁棒谓词算法为原创。 |
| [mourner/rbush](https://github.com/mourner/rbush) | README、动态索引 API | 可借鉴小接口和明确查询语义；本项目不宣称实现其批量装载或性能水平。 |

## 可核验的贡献

1. 用 core/bigint 对真实输入 Double 求精确方向符号；筛选不确定时执行实质计算，不返回“足够接近所以共线”。180 条独立 Fraction 符号数据用于跨后端核对。
2. 实现节点容量约束、真实二次分裂、删除下溢重插和根收缩，提供结构验证器与实际计数；随机混合操作会检查结构和查询结果。
3. 统一 Polygon 外环、孔洞、边界归属以及区域候选精化，返回 component、ring、edge、边界段和索引 revision；包围盒误命中保留诊断。

以上是本次实际实现的能力组合，不构成“没有任何其他库具备同样能力”的保证。调研是有限范围的技术比较，不是完整的依赖审计、质量排名或对其他项目验收结果的判断。
