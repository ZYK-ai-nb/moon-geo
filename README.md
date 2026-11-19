# MoonGeo

纯 MoonBit 的鲁棒二维空间查询库：精确方向判定、动态 R-tree、带边界诊断的区域查询。

## 十一月新增

在十月 `0.1.1` 基础上，`0.2.0` 新增受限 GeoJSON 导入与文件查询工作流。当前版本需要 MoonBit 0.10.21 或更新版本。实施方案、复现命令与限制见 [实施方案](docs/十一月本地实施方案.md)，采用取舍见 [同任务实测](docs/package-comparison.md)。

```sh
node scripts/query_geojson.mjs testdata/geojson-demo.json work/geojson-result.json
```

Node.js 仅负责文件读写和构建，JSON 解析、几何、索引与更新逻辑由 MoonBit 执行。首次运行需要已安装 MoonBit 和 Node.js。

## 快速体验

安装 MoonBit 后，在仓库根目录运行：

```sh
moon run examples/service_area --target js
```

示例模拟一个带排除区的服务范围：点落在排除区时被判为服务范围外，更新范围后成为内部命中，删除范围后不再有候选；边界是否计入由调用者决定。运行时会执行断言。示例使用平面坐标，不是经纬度，也不是实际用户数据。

```text
revision=1 point=(3,3): candidate=101, outside (inside excluded zone)
revision=1 point=(2,3): boundary excluded; ring=1, edge=3
revision=2 point=(3,3): inside; hits=[101]
revision=3 point=(3,3): area removed; candidates=0
revision=4 distant region: hits=[102]; no fixed world extent
```

完整使用说明及三个例子见 [README.mbt.md](README.mbt.md)。

- [功能边界与算法口径](docs/semantics.md)
- [同类调研与差异](docs/related-work.md)
- [生态重合与独立贡献说明](docs/independent-contribution.md)
- [固定版本同任务实测](docs/package-comparison.md)
- [算法来源与许可证](docs/provenance.md)
- [十一月申报书](docs/申报书-十一月本地草稿.md)
- [十月申报历史](docs/申报书草稿.md)
- [本地验证记录](docs/validation/2026-10-29.md)
- [十一月验证记录](docs/validation/2026-11-19.md)

模块账号：`ZYK-ai-nb/moon-geo`。代码仓库：[ZYK-ai-nb/moon-geo](https://github.com/ZYK-ai-nb/moon-geo)。

发布和持续集成进度见 [0.1.1 发布记录](docs/release-0.1.1.md)及 [0.1.0 历史记录](docs/release-0.1.0.md)。
