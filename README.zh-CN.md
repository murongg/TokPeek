# TokPeek

<p align="center">
  <img src="docs/images/tokpeek-hero.png" alt="TokPeek 原生 macOS 菜单栏状态与本地用量仪表盘">
</p>

<p align="center">
  <strong>随时看见你的 AI Token 用量。</strong>
</p>

<p align="center">
  <a href="https://github.com/murongg/TokPeek/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/murongg/TokPeek?sort=semver"></a>
  <a href="https://github.com/murongg/TokPeek/releases"><img alt="下载量" src="https://img.shields.io/github/downloads/murongg/TokPeek/total"></a>
  <a href="https://github.com/murongg/TokPeek/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/murongg/TokPeek/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/murongg/TokPeek/releases/latest"><img alt="需要 macOS 14 或更高版本" src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white"></a>
  <a href="https://github.com/murongg/TokPeek/releases/latest"><img alt="已通过 Apple 签名与公证" src="https://img.shields.io/badge/Apple-Signed%20%26%20Notarized-000000?logo=apple&logoColor=white"></a>
  <a href="LICENSE"><img alt="MIT 许可证" src="https://img.shields.io/github/license/murongg/TokPeek"></a>
</p>

<p align="center">
  <a href="https://github.com/murongg/TokPeek/releases/latest"><strong>下载最新版本</strong></a>
  ·
  <a href="https://github.com/murongg/TokPeek/releases">全部版本</a>
  ·
  <a href="README.md">English</a>
</p>

TokPeek 将本地 AI 会话记录整理成常驻菜单栏的用量仪表盘。无需打开网页，
就能查看 Token 总量、预估费用、每日趋势、客户端占比和模型排行；会话内容
不会上传到服务器。

## 下载

| 安装包 | 链接 |
| --- | --- |
| 最新 macOS Universal 2 ZIP — 同时支持 Apple 芯片和 Intel | [从最新版本页面下载](https://github.com/murongg/TokPeek/releases/latest) |
| SHA-256 校验文件与更新说明 | [打开最新版本页面](https://github.com/murongg/TokPeek/releases/latest) |
| 历史版本 | [浏览全部版本](https://github.com/murongg/TokPeek/releases) |

正式发布版本需要 **macOS 14 或更高版本**，同时支持 Apple 芯片与 Intel Mac，
并已使用 Developer ID 签名及通过 Apple 公证。

### 安装

1. 打开[最新版本页面](https://github.com/murongg/TokPeek/releases/latest)，下载
   `TokPeek-<版本号>-macOS-universal.zip`。
2. 将 `TokPeek.app` 移动到“应用程序”文件夹。
3. 打开 TokPeek，即可在菜单栏查看用量。

TokPeek 通过 Sparkle 检查带签名的更新，任何更新都需要用户确认后才会安装。

## 为什么选择 TokPeek

| 原生、随手可看 | 数据留在本地 | 多维度分析 |
| --- | --- | --- |
| 使用真正的 SwiftUI `MenuBarExtra`，点击一次即可查看。 | 会话发现、解析、定价和聚合全部在 Mac 本地完成。 | 支持时间范围、模型筛选，以及每日、客户端和模型维度分析。 |

## 功能

- 菜单栏双行显示预估费用与 Token 用量
- 可切换为仅 Token、仅费用、预算进度或仅图标
- 支持今天、7 天、30 天、90 天和全部时间
- 模型筛选同时作用于汇总、图表、客户端和排行
- Token 构成、每日用量、客户端占比和双列模型排行
- 支持每日、每周或每月的费用与 Token 预算，并预测月末费用
- 预算使用达到 80% 和 100% 时发送 macOS 本地提醒
- 所有图表提供 Tooltip 与详细用量信息
- 可配置刷新频率与默认统计周期
- 通过 `SMAppService` 支持登录时启动
- 支持简体中文和英文
- 支持浅色/深色外观、键盘操作与 VoiceOver
- 通过 Sparkle 提供安全的应用内更新

## 实现架构

```text
SwiftUI 菜单栏
    ↓
TokPeekKit 模型与状态
    ↓
TokPeekBridge（通过 C ABI 传递 JSON）
    ↓
tokpeek-core-ffi（Rust 静态库）
    ↓
tokscale-core
```

TokPeek 调用 `generate_local_graph_report` 获取数据，Swift 层不负责解析会话文件，
也不会重复计算用量。

## 开发

- macOS 14 或更高版本
- Xcode 16 或更高版本
- Swift 6
- 当前稳定版 Rust 工具链
- Release 构建需要 `aarch64-apple-darwin` 和 `x86_64-apple-darwin`

安装两个 Release 目标：

```bash
rustup target add aarch64-apple-darwin x86_64-apple-darwin
```

### 使用 Xcode

TokPeek 已包含共享的 Xcode 项目和 Scheme：

```bash
open TokPeek.xcodeproj
```

`Build Tokscale Core` 阶段会先调用 Cargo，再由 Swift 链接生成的静态库。Release
构建会将两个架构的 Rust 产物合并为 Universal 2 静态库。Sparkle 2 通过 Swift
Package Manager 解析。

项目文件由 `scripts/generate-project.rb` 生成。安装了 `xcodeproj` Ruby gem 的
维护者可以重新生成：

```bash
make project
```

### 构建与运行

```bash
make run
```

首次构建需要编译 Tokscale Core 及其依赖，因此耗时会更长。

运行 Rust、Swift Package Manager 和 Xcode Scheme 测试：

```bash
make test
```

创建启用 Hardened Runtime、使用临时签名的应用：

```bash
make app
open dist/TokPeek.app
```

如需 Developer ID 签名，请传入签名身份：

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
```

TokPeek 未启用 App Sandbox，因为 Tokscale Core 需要读取受支持编码工具的本地
会话文件；正式签名构建仍然启用 Hardened Runtime。

## 发布与更新

CI 会在推送到 `main` 或创建 Pull Request 时运行 Rust、Swift Package Manager
和 Xcode 测试，并验证 Universal 2 Release 构建。

稳定版本通过语义化版本标签发布：

```bash
git tag -a v0.1.0 -m "TokPeek v0.1.0"
git push origin v0.1.0
```

Release 工作流会运行完整测试、写入版本号、使用 Developer ID 签名、提交 Apple
公证、装订公证票据，并将 Universal 2 ZIP、SHA-256 校验文件与签名后的 Sparkle
Appcast 发布到 GitHub Releases。已安装的版本默认每天检查一次更新，安装前始终
询问用户。

Apple 和 Sparkle 签名凭据仅保存在加密的 GitHub Secrets 中，并会在临时 Runner
结束前删除。具体配置参见 [RELEASING.md](RELEASING.md)。

## Tokscale Core

Rust Bridge 当前固定使用 Tokscale 提交
`45b3b3e4ccf58f9eee4fc4159003f5f884af79b3`（v4.8.1）。由于本地会话格式和报告协议
可能变化，升级时需要进行代码审查和完整测试。

## 隐私

TokPeek 通过 Tokscale Core 在本地读取受支持的 AI 会话数据，不包含分析 SDK，
也不会上传会话内容。

## 许可证

TokPeek 使用 MIT 许可证开源。Tokscale Core 同样使用 MIT 许可证，详情参见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
