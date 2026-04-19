# 贡献指南

感谢你考虑为 openwrt-maintenance 做贡献！

## 开始之前

- 所有脚本必须用 **POSIX `/bin/sh`** 编写，不假设 bash 存在。
- OpenWrt 默认 shell 是 BusyBox ash，请避免使用 bash-only 语法。

## 开发流程

1. Fork 仓库并创建特性分支。
2. 修改代码。
3. 运行测试：

   ```sh
   sh tests/run.sh
   ```

4. 确保测试全部通过后提交。
5. 提交 Pull Request，简要说明改动目的。

## 添加新脚本

参考 [docs/layout.md](docs/layout.md) 中"添加一个新脚本"一节。要点：

- 在 `scripts/` 下新建脚本，引入 `lib/common.sh`。
- 在 `tests/` 下新建对应的 `test_*.sh`，引入 `_assert.sh`。
- `sh tests/run.sh` 会自动发现新测试文件。

## 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

- `feat:` 新功能
- `fix:` 修复
- `docs:` 文档
- `test:` 测试
- `chore:` 构建 / 杂项

## 代码风格

- 缩进：4 空格（参见 `.editorconfig`）。
- 变量引用加双引号：`"$var"` 而非 `$var`。
- 函数前写简短注释说明用途。
- 每个 `lib/*.sh` 用 `__OWRT_*_LOADED` guard 防止重复加载。

## 报告问题

请通过 GitHub Issues 报告，尽量附上：

- OpenWrt / ImmortalWrt 版本（`cat /etc/openwrt_release`）
- 包管理器类型（opkg 或 apk）
- 完整的错误输出
