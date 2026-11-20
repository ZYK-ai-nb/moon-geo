# 功能重合、独立贡献与采用范围

本项目此前两次收到与生态重复有关的申报反馈。本文承认已存在的能力，并明确十月基础、十一月新增和实际对照范围。改名、同算法重写或多功能组合本身均不能证明独立生态价值。

## 已有能力逐项披露

| 已有项目和来源 | 与 MoonGeo 重合的能力 | 本次实际核查 |
|---|---|---|
| [MoonGeoKit 0300c9c](https://github.com/cn-xjr/moongeokit/tree/0300c9cd7600c255011ddae96c9f7d929679e18a) | 几何、动态索引、诊断、GeoJSON 导出 | 运行 256 个矩形查询及删除，均正确。单环 Polygon 加应用代码可完成所测孔洞和边界任务。 |
| [moon-geometry 2b59b8b](https://github.com/walkzzz/moon-geometry/tree/2b59b8b953ecf8764ef6009dc2f7697f2eec539a) | 几何、GeoJSON、含孔区域、空间索引和鲁棒接口 | GeoJSON 解析同一带孔 Polygon 成功，三个内外点判断正确。其他大量接口未完成对照。 |
| [rbush ed1ed14](https://github.com/tc-adventureking/moon-rbush/tree/ed1ed14457b4b1965c5666b819d49a1f1c5acabb) | 动态二维 R-tree、查询、删除 | 相同的 256 个矩形查询及删除通过。对方还提供 MoonGeo 当前未实现的批装载和快照。 |
| [robust 0.1.0](https://mooncakes.io/docs/t-ujiie-g/robust%400.1.0) | 鲁棒二维方向谓词 | 仅文档核查，已有 orient2d。不能用 MoonGeoKit 的数值反例推断该包的行为。 |
| [MoonSTRtree 88f1d30](https://github.com/LING71671/MoonSTRtree/tree/88f1d3074533bc6ede306d55af150a0eba11a8be) | 空间索引、几何和区域相关任务 | 已定位当前来源，未执行该版本完整统一任务对照，不据十月旧版本比较宣称优胜。 |

GeoJSON、动态 R-tree、孔洞与鲁棒谓词均不作为 MoonGeo 独有能力申报。前三项的固定输入、适配代码、观察结果和限制见 [同任务实测](package-comparison.md)。

## 本期实际新增

十月发布的 0.1.1 已有几何核心和动态 R-tree，不重复计为十一月新增。十一月新增内容是可复用的数据调用链及其状态契约。

1. `geojson.parse_feature_collection`、`build_index` 校验集合、ID 和拓扑，重算 bbox。整个集合通过后才建立新索引。
2. `workflow.run` 维护几何、区域目录和索引的一致性。单次修改先校验，失败时该次修改前的结果与 revision 保持不变。
3. 新增 `workflow` 输出统一返回 hits、逐候选三态 decisions 和版本，复用十月已有的边界诊断能力。边界开关只改变命中，边界环和边编号仍可核查，成功修改才改变版本。
4. Node 仅提供文件入口。MoonBit 完成解析、几何、索引与修改，公开数据、错误操作后的继续查询和 Shapely 独立对照验证整条入口。

## 采用理由和限制

需要把局部区域文件接入 MoonBit、严格区分边界归属并频繁修改区域的应用，可以直接使用这套调用链。调用方因此获得统一的输入校验、修改顺序、边界策略和失败后状态契约。只需要索引、容差几何或更广泛算法的应用，可继续使用上述组件。

本次实测说明其他方案也能完成共同任务。采用理由应由上述具体契约与集成需求支撑，不能仅以接口封装或文件入口判定生态差异充分。项目仍缺真实客户采用与可信耗时对比，不作整体性能排名。最终生态价值由审核组结合实现与任务评估。

复现命令为 `python scripts/compare_packages.py` 和 `python scripts/check_geojson_workflow.py`。前者需网络和当前 MoonBit 工具链，后者需开发依赖 Shapely。运行库仅依赖 MoonBit 标准库。数据来源、算法依据、AI 参与和许可见 [provenance](provenance.md)，对照项目源码未复制到产品实现中。
