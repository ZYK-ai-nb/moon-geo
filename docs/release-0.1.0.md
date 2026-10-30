# MoonGeo 0.1.0 发布记录

## 当前状态

- 模块身份已绑定为 `ZYK-ai-nb/moon-geo`，repository 为 `https://github.com/ZYK-ai-nb/moon-geo`。
- Mooncakes 已正式发布 `ZYK-ai-nb/moon-geo@0.1.0`，实际发布命令退出 0，服务器返回 `200 OK`。
- 已在无 `moon.work`、无本地依赖覆盖的新消费者工程中，从注册表下载并运行三个原始 README 片段；Wasm、Wasm-GC、JS 分别 3/3 通过。
- 注册表下载的 44 个文件与正式上传归档逐字节一致。
- Git 提交使用 GitHub 账号名与关联的 noreply 邮箱，仅配置本仓库；不在源码中保存报名联系方式。
- GitHub CLI 已验证为 `ZYK-ai-nb`；[公开仓库](https://github.com/ZYK-ai-nb/moon-geo)已创建，本地提交和 `v0.1.0` 标签已推送，默认分支为 `main`。
- [GitHub Actions](https://github.com/ZYK-ai-nb/moon-geo/actions) 已触发；请以对应提交的实际执行结果为准。
- 报名表尚未提交；不能声称初审材料已正式提交或已经通过初审。

## 注册表归档

- 模块：`ZYK-ai-nb/moon-geo@0.1.0`
- 文档入口：https://mooncakes.io/docs/ZYK-ai-nb/moon-geo
- 上传归档 SHA256：`2e1d0636f09578889836bbb649a6f854862b93a6f61f11de563accebbcc39b4e`
- 发布源码提交：`4bb2c86`；后续发布状态和验证记录会保留在主分支，不改写该归档。
- 此归档中的旧版申报书误写为十一月赛；当前赛事为十月赛，以主分支 `docs/申报书草稿.md` 为准。后续主分支的 GEOS 对照测试与文档修正未包含在 0.1.0 归档中。

重现注册表消费者验证：`python scripts/check_registry_consumer.py --version 0.1.0`。原始执行日志保留在本地 `work/validation/`。

## 发布范围

可靠方向判定与算术路径诊断、基本几何和简单区域／孔洞、动态 R-tree、区域候选精化和边界诊断。仅依赖 MoonBit 标准库。KD-tree、geohash、kNN 和高级多边形布尔不属于该版本。

## 本地验证基线

绑定前后 91 个测试均在 Wasm、Wasm-GC、JS 分别通过，180 条独立 Fraction 方向符号数据通过核对；三个 README 片段在本地依赖消费者和实际注册表消费者中都分别 3/3 通过。

Windows Native 在本机缺少 MSVC／Windows SDK，未运行到功能测试。Linux Native 的结果必须以后续 CI 为准。
