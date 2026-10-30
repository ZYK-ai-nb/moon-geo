# 算法来源与许可证

本工程采用根目录 Apache-2.0 LICENSE。几何与索引代码为本次工作中编写；交接工程原来只有 MoonBit 模板、许可证、账号绑定脚本和 Array 探针。本次使用 AI 辅助设计、实现和检查，维护者仍需理解算法与验证记录。

| 来源 | 本次参考范围 | 与源码的关系 |
|---|---|---|
| [Shewchuk, Adaptive Precision Floating-Point Arithmetic and Fast Robust Geometric Predicates](https://www.cs.cmu.edu/~quake/robust.html) | 浮点方向判定的误差与筛选／精确回退思路 | 不是其 C 或 robust-predicates JS 的逐行移植；精确回退独立使用 core/bigint 的二进制有理数表示 |
| [Guttman 1984, R-Trees: A Dynamic Index Structure for Spatial Searching](https://doi.org/10.1145/602259.602266) | ChooseLeaf、quadratic split、CondenseTree 设计 | 本次独立实现；删除采用收集叶条目再插入的变体 |
| Joseph O'Rourke, Computational Geometry in C | 方向、线段、射线／绕数、凸包等经典概念 | 不复制书中代码、插图或题目数据 |
| IEEE-754 二进制浮点表示 | binary64 符号位、指数、有效位解码 | 按公开格式编写；精确对象是输入的二进制值 |
| [Python fractions 标准库](https://docs.python.org/3/library/fractions.html) | Fraction.from_float 独立生成精确符号 | 仅开发工具；不把 Python 标准库源码带入工程 |
| [Shapely](https://github.com/shapely/shapely) 2.2.0 / GEOS 3.14.1 | 开发时为有限样本生成线段和多边形点定位的对照结果 | 仅用于运行生成器，不是 MoonBit 库的运行时依赖；生成器与测试样本属于本工程，未复制 Shapely 或 GEOS 源码 |
| moonbitlang/core | bigint、debug、测试 quickcheck | MoonBit 工具链标准库，沿用其 Apache-2.0 许可；无第三方 Mooncakes 包 |

`testdata/orientation_oracle.json` 及对应生成测试由本工程的标准库生成器产生，种子 20261029，180 条数据；其来源可重跑，无下载的数据集。手算形状、随机矩形和状态机操作数据均为本次自建。

`geos_oracle_test.mbt` 的对照样本由 `scripts/generate_geos_oracle.py` 产生：固定种子的小整数坐标、503 对线段和 3 个多边形的 507 个点。通过该有限样本不代表对完整几何行为或极端浮点输入完成全面对拍。

调研中阅读了 related-work 列出的仓库 README、接口或指定源码文件，未把这些项目的源码、测试数据或图片复制进本项目。不存在“改名后作为原创”的第三方移植代码。
