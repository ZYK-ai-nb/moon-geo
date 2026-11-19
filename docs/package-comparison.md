# 固定版本同任务实测

2026-11-19 使用同一个独立消费者工程运行 MoonGeo、MoonGeoKit、rbush 和 moon-geometry 的公开 API。目标为 JS，工具链为 moonc 0.10.21、Moon CLI 0.1.20261117。上游源码保持原样，保存在忽略的工作目录。

| 方案 | 本次固定来源 |
|---|---|
| MoonGeo | 本仓库十一月源码，实际提交和执行结果可由本次 CI 追溯 |
| MoonGeoKit | [0300c9c](https://github.com/cn-xjr/moongeokit/tree/0300c9cd7600c255011ddae96c9f7d929679e18a)，模块 cn-xjr/moongeokit 0.3.0 |
| rbush | [ed1ed14](https://github.com/tc-adventureking/moon-rbush/tree/ed1ed14457b4b1965c5666b819d49a1f1c5acabb)，模块 tc-adventureking/rbush 0.1.0 |
| moon-geometry | [2b59b8b](https://github.com/walkzzz/moon-geometry/tree/2b59b8b953ecf8764ef6009dc2f7697f2eec539a)，源码 moon.mod 为 0.252.0，区别于当前已发布的 0.251.0 |

## 实际输入和结果

| 任务 | MoonGeo | MoonGeoKit | rbush |
|---|---|---|---|
| 插入 256 个相同的网格矩形，再查询 256 个中心点 | 全部得到预期单个 ID | GridSpatialIndex 全部一致 | RBush 全部一致 |
| 删除同一个条目，再查原位置 | 无命中 | 无命中 | 无命中 |
| 预设网格范围外增加矩形 | R-tree 可插入并查询 | 所测固定网格拒绝，但线性 SpatialIndex 可完成 | 可插入并查询 |
| 相同外环和孔洞的内部、外部及边界共 5 个点，再取消孔洞查询 | 原生含孔 Polygon 和 RegionIndex 完成 | 单环 Polygon 加应用代码完成孔洞扣除、边界识别和更新后的判断 | 本次仅比较索引任务，没有把几何任务加到其职责内 |
| 近共线输入 A=(0,0)、B=(134217728,134217729)、C=(134217729,134217730) | 精确方向符号 -1，即 CW | orientation_sign，epsilon=0，结果 0 | 未比较谓词 |

方向案例的精确行列式为 -1。MoonGeo 的保证针对输入 Double 的二进制值，不对测量误差作保证。MoonGeoKit 所测接口的浮点和容差语义与之不同，这个反例不能推出整个库不可靠。孔洞和边界测试使用本项目编写的应用适配代码，不能把“需要适配”表述为“竞品无法做到”。

moon-geometry 的限定比较也实际执行成功，`io/geojson_io.geojson_parse` 读入同一带孔 Polygon 并得到两个环，`geometry/polygon_holes` 对内部、孔洞内部和外部三个点分别得到 true、false、false。没有把它说成缺少 GeoJSON 或含孔区域能力。其三态边界与修改事务语义尚未完成统一评估。

## 调用方如何选择

已有固定世界范围、需要网格查询或容差几何的应用，可以继续使用 MoonGeoKit。只需要包围盒索引、批量装载或索引快照的应用，可以评估 rbush，这些是 MoonGeo 当前没有覆盖的能力。

MoonGeo 当前适合的需求是局部二维区域的严格边界归属、孔洞和分量处理、频繁修改，以及可直接运行的 GeoJSON 文件工作流。它把输入校验、区域目录、修改版本和逐候选诊断放在同一个接口中，调用方可直接消费查询与修改结果。这个集成价值有适用范围，不能作为整体领先的结论。

本次验证说明多种方案能完成共同的基本任务。现有证据支持具体数值语义和集成方式的取舍，仍缺少真实用户采用和耗时对照。没有由测试数量、索引类型或代码量推导质量排名。

## 复现

```sh
python scripts/compare_packages.py
```

脚本下载固定提交的公开快照到 `work/`，编译独立消费者并执行断言。需要 MoonBit 0.10.21 或更新工具链和网络，不会给本库增加运行时依赖。也可传入 `--moon-home PATH` 使用独立工具链。原始结果写入 `work/validation/package-comparison.json` 和 `.log`。输入适配程序在 `testdata/comparison/main.mbt`，CI 执行同一脚本。

此次曾在旧编译器 0.10.17 下遇到 rbush 新语法不兼容，随后用独立的新工具链重跑。这个环境问题未作为竞品质量结论。项目自身也已按新编译器更新派生语法，并重新执行严格检查和测试。
