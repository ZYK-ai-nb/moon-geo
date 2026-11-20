# MoonGeo 申报补充材料：任务、状态契约与贡献范围

核查日期：2026-11-20。对应模块 `ZYK-ai-nb/moon-geo@0.2.0`。本材料补充约一页的申报正文，便于审核者从具体行为核查贡献；不以篇幅或功能组合证明生态价值。

## 报名方向与成果时间

本次意向为新项目建设，申请十一月审核及验收，通过后参与第二赛季度优秀项目评选。项目十月已公开并曾申报；十一月在同一仓库开发，不声明整个项目始于本月，也不将旧版本改名重报为另一作品。官网当前说明允许已有项目以本期实质新增参与，月度新项目须通过验收后进入季度评选；赛道归类、截止与最终结果以赛事组确认为准。

| 已有基础与新增 | 具体内容 | 可追溯来源 |
|---|---|---|
| 十月 0.1.1 基础 | 可靠方向符号、含孔与多分量区域、动态 R-tree、区域边界诊断及版本 | [十月发布记录](release-0.1.1.md)，不重复计入本期新增 |
| 十一月外部数据与工作流 | 受限 GeoJSON 验证、query/insert/replace/remove 顺序接口、Node 文件入口、公开几何对照 | [541fd0b](https://github.com/ZYK-ai-nb/moon-geo/commit/541fd0b) |
| 十一月比较和适配 | 固定版本同任务消费者、重合披露、工具链适配及验证修复 | [24edfff](https://github.com/ZYK-ai-nb/moon-geo/commit/24edfff)、[9e18e1a](https://github.com/ZYK-ai-nb/moon-geo/commit/9e18e1a) |
| 十一月发布 | 0.2.0 上传和独立注册表下载验证 | [发布记录](release-0.2.0.md)；发布后文档更新不追写到已上传归档 |

## 用同一个点观察成功和失败

输入是固定来源的 Natural Earth South Africa（ID 101）与 Lesotho（ID 102）几何。前者的孔洞与后者独立区域均保留。查询点为 `(28.2,-29.6)`。修改步骤由本项目构造，不能解释为实际国界变化或客户使用。

| 顺序 | 实际操作及结果 | 版本与随后查询 |
|---|---|---|
| 1 | 初始导入两个区域 | revision 2，命中 `[102]` |
| 2 | 尝试用自交外环替换 101，操作 `ok=false` | revision 仍为 2，随后查询仍命中 `[102]` |
| 3 | 用取消孔洞的合法几何替换 101 | revision 3，命中 `[101,102]` |
| 4 | 删除 102 | revision 4，命中 `[101]` |
| 5 | 重新插入原始 102 | revision 5，命中 `[101,102]` |

输入、程序和断言见 `testdata/natural-earth-request.json`、`scripts/check_geojson_workflow.py`。409 次查询还比较命中与逐候选三态决策。有限样本的一致性不代表所有数值输入已全面验证。

## 状态契约究竟保证什么

- 初始化：先解析并验证全部 Feature，再创建新索引。ID 必须唯一，Polygon/MultiPolygon 的拓扑由核心构造器验证，外部 bbox 被忽略并重新计算。
- 单次操作：插入与替换先验证几何，重复 ID 的插入报错。验证失败不会修改该操作之前的可查询状态；此前已成功的操作保留，后续操作继续。不存在整批回滚、持久化恢复或并发隔离承诺。
- 版本：成功插入、替换、删除使 revision 增加；不存在 ID 的删除或合法替换返回 `changed=false`，不增加版本。版本是内存 Int32 计数，不是全局事件时间或永久序列号。
- 边界：默认计入命中，可通过开关排除；候选区域的 Inside、Outside、OnBoundary 决策仍输出。核心 API 还提供分量编号，当前 workflow JSON 的边界字段为环与边编号，没有导出分量编号，不声明多分量边界的完整独立定位能力。
- 错误：顶层 `ok=true` 代表请求被处理，调用者仍需检查每条结果的 `ok`。CLI 只要有一项失败便返回退出码 1，同时保留逐项结果；请求整体解析失败也返回错误。

几何核心与 R-tree 同属 MoonBit 实现。解析和状态处理并非由 Node、Shapely 或其它语言替代；Node 负责文件宿主，Shapely 仅作开发验证。环的拓扑校验为二次复杂度，索引重叠严重时也可能退化。

## 与同类相比能说和不能说的内容

[固定版本比较](package-comparison.md)承认 MoonGeoKit、rbush 和 moon-geometry 在所测共同任务中成功。MoonGeoKit 的应用适配代码可完成孔洞扣除和边界判断；moon-geometry 已有带孔 GeoJSON 解析，不能宣称这些能力空白。MoonSTRtree 与 robust 仅完成限定来源核查，未做完整统一实验。

目前能够说明的采用理由，是调用方需要外部区域导入、边界归属、顺序编辑和失败后状态契约时，可以使用一套已经连通并验证的接口。只需几何算法或索引的应用，已有组件可能更适合。没有完整评估其它项目实现同等契约所需的工作量，也没有证明其无法做到；因此不以“多几个接口”“MoonBit 重写”或“组合起来”直接宣告生态差异成立。

尚缺真实使用方的接入与维护反馈、完整同等契约对照及可靠耗时比较。这些是进一步增强生态价值证据的方向，并非已经完成的结果，也不是官网明确的强制客户数量或性能门槛。

## 复现与支持范围

```sh
moon check --target all --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
node scripts/query_geojson.mjs testdata/geojson-demo.json work/result.json
python scripts/check_geojson_workflow.py
python scripts/compare_packages.py
```

需 MoonBit 0.10.21 或更新版本；文件入口另需 Node.js。Shapely 对照需开发依赖 `shapely==2.2.0`，固定版本比较需网络。Native 构建另需系统 C 编译器。[发布源码 CI](https://github.com/ZYK-ai-nb/moon-geo/actions/runs/44548033646)与[文档同步 CI](https://github.com/ZYK-ai-nb/moon-geo/actions/runs/44673224336)验证 Linux Native；本机 Windows 缺少 C 编译器，不将该环境的 Native 构建记为通过。

GeoJSON 为局部二维经纬坐标的应用子集，要求闭合环、整数 ID、properties 为对象或 null；拒绝字符串 ID、三维位置、自定义 CRS、跨日界线及跨度超过 180 度的环、非法拓扑与重复 JSON 键。保留的是平面直线段拓扑语义，不是完整 RFC 7946、球面测量或全球 GIS 引擎。文件全部载入内存，不提供大文件流式处理。最初交接中的 KD-tree、geohash 与 kNN 不在当前实现或本次申报范围。

算法、测试数据和许可来源见 [provenance](provenance.md)。AI 参与开发，参赛者需要能够说明候选筛选与精判的区别、输入 Double 的精确方向符号含义、失败更新的状态边界及 GeoJSON 支持范围。文档和测试不能代替参赛者本人的解释。

赛事路径来源：[官网](https://moonbitlang.github.io/Hackathon2026/#process)及[官网公开源码](https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx)。参赛归类、表单字段及时间以正式章程、实际报名表和官方通知为准；本材料没有假定十一月具体截止日或已获资格确认。
