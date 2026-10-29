# MoonGeo 0.1.0 发布记录

## 当前状态

- 模块身份已绑定为 `ZYK-ai-nb/moon-geo`，repository 为 `https://github.com/ZYK-ai-nb/moon-geo`。
- Mooncakes CLI 已核验登录为 `ZYK-ai-nb`。GitHub CLI 的设备授权正在处理。
- Git 提交使用 GitHub 账号名与关联的 noreply 邮箱，仅配置本仓库；不在源码中保存报名联系方式。
- 远程仓库、注册表正式发布、CI 和外部下载验证尚待完成。本文将在取得实际结果后更新，不提前宣称成功。

## 发布范围

可靠方向判定与算术路径诊断、基本几何和简单区域／孔洞、动态 R-tree、区域候选精化和边界诊断。仅依赖 MoonBit 标准库。KD-tree、geohash、kNN 和高级多边形布尔不属于该版本。

## 本地验证基线

绑定前已有 91 个测试在 Wasm、Wasm-GC、JS 分别通过，180 条独立 Fraction 方向符号数据通过核对；三个 README 片段在独立消费者中分别 3/3 通过。绑定后会重新检查包内容和可下载性。

Windows Native 在本机缺少 MSVC／Windows SDK，未运行到功能测试。Linux Native 的结果必须以后续 CI 为准。
