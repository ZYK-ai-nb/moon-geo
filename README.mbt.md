# MoonGeo

面向地图编辑与区域归属查询的纯 MoonBit 库。重点是可靠的拓扑判定、真正可修改的 R-tree，以及可复核的边界诊断。Apache-2.0，仅使用 `moonbitlang/core`；运行时无需 Python、C 几何库、FFI 或网络服务。

当前源码版本 **0.1.1**，模块为 `ZYK-ai-nb/moon-geo`。历史 0.1.0 归档内的旧申报草稿误写为十一月赛，本版已修正。0.1.0 的发布状态与持续集成证据见 [历史发布记录](docs/release-0.1.0.md)。以下示例可以直接从源码运行。

## 本地运行

在工程根目录运行：

```sh
moon version --all
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon run cmd/main --target js
```

Windows 可用 `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` 完整复现本地检查；日志写入 `work/validation/`。Native 运行另需本机 C 编译工具链，安装好后可加 `-IncludeNative`。本机实测编译器为 `moonc v0.10.17+093cb8f9c`，Moon CLI 为 `0.1.20261021`；CI 使用官方 stable 工具链，执行结果见发布记录。

安装命令：

```sh
moon add ZYK-ai-nb/moon-geo@0.1.1
```

在消费者的 `moon.pkg` 中使用 `import { "ZYK-ai-nb/moon-geo" @geo }`。注册表发布后可用 `python scripts/check_registry_consumer.py --version 0.1.1` 验证独立消费者。

下面三个片段均为测试块；复制到只有测试的包时，导入应放在 `import { "ZYK-ai-nb/moon-geo" @geo } for "test"` 中，避免普通源码包出现未使用导入。可运行 `python scripts/check_consumer.py`，在本地独立工作区编译并执行三个原始文档片段，不需要发布或登录。

## 示例 1：普通叉积丢失的方向符号

```mbt nocheck
///|
test {
  let a = @geo.Point::new(134217728.0, 134217729.0)
  let b = @geo.Point::new(134217729.0, 134217730.0)
  let c = @geo.Point::new(0.0, 0.0)
  let result = @geo.orientation_report(a, b, c)
  assert_eq(result.orientation, @geo.CW)
  assert_eq(result.arithmetic, @geo.ExactDyadic)
}
```

同样坐标在原点展开的普通 Double 叉积为 0，而精确行列式为 -1。浮点筛选不能确定符号时，库解码输入的 IEEE-754 二进制值，并用标准库 BigInt 求准确符号。可执行版本：

```sh
moon run examples/predicates --target js
```

## 示例 2：区域内、边界、区域外

```mbt nocheck
///|
test {
  let polygon = @geo.Polygon::new([
    @geo.Point::new(0.0, 0.0),
    @geo.Point::new(1.0, 0.0),
    @geo.Point::new(1.0, 1.0),
    @geo.Point::new(0.0, 1.0),
  ])
  assert_eq(polygon.locate(@geo.Point::new(0.5, 0.5)).location, @geo.Inside)
  let boundary = polygon.locate(@geo.Point::new(1.0, 0.5))
  assert_eq(boundary.location, @geo.OnBoundary)
  guard boundary.boundary is Some(witness) else { fail("missing boundary") }
  assert_eq(witness.ring, 0)
  assert_eq(witness.edge, 1)
}
```

`RegionIndex::query_point` 先查询 R-tree，再判定真实区域。包围盒候选可因孔洞或凹形而被排除；`decisions` 保留这些排除结果。`include_boundary=false` 只改变命中列表，边界诊断仍然保留。凹形区域演示：

```sh
moon run examples/regions --target js
```

### 真实工作流的可运行示例

假设服务区是平面方形，其中一块区域暂不提供服务：查询落在排除区的点时，包围盒会给出候选，实际区域判断会将其排除；排除区边界也按业务策略排除，但保留边界编号供检查。移除排除区并更新索引后，同一点变为内部命中；删除整个服务区后不再返回候选。该场景为自建示例，不代表真实用户案例，坐标也不是经纬度。

```sh
moon run examples/service_area --target js
```

程序包含断言，逐步检查候选、命中、边界、更新后的版本号和删除后的索引状态；持续集成也运行此示例。

## 示例 3：动态 R-tree

```mbt nocheck
///|
test {
  let tree = @geo.RTree::new(capacity=4)
  tree.insert(101, @geo.BBox::new(0.0, 0.0, 2.0, 2.0))
  tree.insert(102, @geo.BBox::new(10.0, 10.0, 12.0, 12.0))
  let found = tree.query(@geo.BBox::new(1.0, 1.0, 3.0, 3.0))
  assert_eq(found.entries.map(fn(e) { e.id }), [101])
  assert_true(tree.remove(101))
  assert_eq(tree.validate(), [])
}
```

Guttman 二次分裂、删除下溢后的条目重插、根节点收缩均已实现；结果按 ID 排序。演示会触发实际分裂和删除收缩：

```sh
moon run examples/dynamic_index --target js
```

## 精度与适用边界

- 坐标为同一平面、同一单位的 Double；绝对值不超过 `1.0e100`，NaN/Infinity 被拒绝。经纬度需要调用者先投影，面积不是球面面积、距离不是米制地理距离。
- **方向与拓扑判定**针对已输入的二进制坐标求可靠符号；测量误差、GPS 定位误差不在该保证内。
- **面积、质心、距离**是浮点近似测量，不保证精确。极小面积可能下溢，质心不可计算时返回 `None`，不会伪造一个质心。
- Polygon 要求简单外环和严格位于内部的互不相交孔洞；非法环被拒绝。普通自交环只可交给 `signed_area` 求代数面积，不能作为有效区域入索引。
- Polygon 输入与返回的环数组均防御性复制。MultiPolygon 的实区域分量须分离；孔洞中的独立岛可作为另一分量。
- 首版不含 KD-tree、geohash、kNN、多边形布尔、Delaunay、Voronoi、浏览器可视化或性能优胜声明。

## 验证与来源

主分支测试包括手算案例、四类带种子的 QuickCheck 属性、180 组独立 Python Fraction 方向符号、与 Shapely/GEOS 对照的 503 对线段及 507 个多边形定位点、500 个矩形的 200 次范围查询、1,000 次混合索引操作，以及孔洞、边界和区域更新场景。GEOS 对照限于三个多边形和小整数坐标，不能证明极端浮点或全部行为正确。生成器只用于开发：

```sh
python scripts/generate_oracle.py --check
```

如需重新核对 GEOS 对照数据，在独立开发环境安装 `shapely==2.2.0` 后运行 `python scripts/generate_geos_oracle.py --check`；CI 会安装该开发依赖并执行核对，库运行不需要 Shapely、GEOS 或 Python。

详细算法、复杂度、语义和限制见 [semantics](docs/semantics.md)。已有 MoonBit 几何和索引项目见 [related work](docs/related-work.md)；本项目不宣称生态首个或全球唯一。参考了 Shewchuk 的可靠谓词思路、Guttman 的 R-tree 算法和经典几何算法，未复制其他 MoonBit 项目源码，详见 [provenance](docs/provenance.md)。
