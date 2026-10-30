# MoonGeo 0.1.1 发布记录

- 发布时间：2026-10-30；模块 `ZYK-ai-nb/moon-geo@0.1.1`，由 `ZYK-ai-nb` 账号执行 `moon publish`，退出码 0，服务器返回 `200 OK`。
- 发布源码：[提交 827fb1d](https://github.com/ZYK-ai-nb/moon-geo/commit/827fb1da924b1d82916c1d1ec4813a43f42ca99f)；[该提交的 CI](https://github.com/ZYK-ai-nb/moon-geo/actions/runs/41002762647) 在 Wasm、Wasm-GC、JS 和 Linux Native 各通过 93 项测试，也验证 GEOS 样本和运行示例。
- 上传归档 SHA-256：`2e26ef3879265603983d2b79591e7ef53601e9e9ed3f0819d568ffd0e5952911`。全新消费者从注册表下载的 51 个文件与上传包逐字节一致，无额外文件。
- `python scripts/check_registry_consumer.py --version 0.1.1`：注册表下载成功；README 的 3 段示例在 Wasm、Wasm-GC、JS 各 3/3 通过。
- 发布前 `moon publish --dry-run` 的服务器返回 `202 Accepted` 并报告演练成功、未更改；本机 CLI 随后仍以退出码 1 报错。正式发布独立执行，结果如上，不将演练退出码记为通过。

本版本包含服务区域更新演示、GEOS 有限样本对照及修正后的十月赛申报草稿。它不代表评委已接收报名或通过初审。0.1.0 的归档不被覆盖，相关历史见 [0.1.0 发布记录](release-0.1.0.md)。
