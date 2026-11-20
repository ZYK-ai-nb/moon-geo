# MoonGeo 0.2.0 发布记录

- 发布日期：2026-11-19。模块 `ZYK-ai-nb/moon-geo@0.2.0`，发布身份 `ZYK-ai-nb`，`moon publish` 退出码 0，服务器返回 `200 OK`。发布前演练退出码 0，服务器返回 `202 Accepted`。
- 发布源码：[5766f32](https://github.com/ZYK-ai-nb/moon-geo/commit/5766f32e855a33d72a650d17d77387d02c1a3891)。[该提交的 CI](https://github.com/ZYK-ai-nb/moon-geo/actions/runs/44548033646) 已通过，包括 Wasm、Wasm-GC、JS、Linux Native 各 105 项测试、409 次 Shapely 查询对照及固定版本同任务比较。
- 上传归档含 76 个文件，SHA-256：`b7a92bf897def54987d70556eb8672ed3655f732b957ab08ea5a6855212817be`。发布后从 Mooncakes 下载的这 76 个文件逐字节一致；上传包不含本地工作目录、Git 数据或凭据。
- `python scripts/check_registry_consumer.py --version 0.2.0`：新建独立消费者，通过注册表下载，无本地源码覆盖；Wasm、Wasm-GC、JS 各 4/4 测试通过，覆盖 README 示例及新版 `geojson`、`workflow` 接口。另运行下载包内的文件查询入口，查询、修改后的结果符合断言。
- 本机验证工具链：MoonBit `0.10.21+06da1ed44`、moon `0.1.20261117`。发布临时使用的独立工具链凭据已移除，Git 提交使用 `ZYK-ai-nb` 的 noreply 邮箱。

本版在十月 0.1.1 基础上增加受限 GeoJSON 导入与顺序文件查询工作流。区域校验、查询边界、修改失败不改状态的契约及现有项目的功能重合，见 [生态重合与独立贡献说明](independent-contribution.md) 和 [同任务实测](package-comparison.md)。不将十月已有功能计作十一月新增，也不把发布成功等同于通过初审。

本记录在发布后补充，不属于上述上传归档。0.1.1 的发布事实保留在 [历史记录](release-0.1.1.md)。
