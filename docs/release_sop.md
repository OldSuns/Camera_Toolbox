# GitHub 发版 SOP

适用仓库：`OldSuns/Camera_Toolbox`

## 发布机制

- GitHub Actions 工作流文件：`.github/workflows/release.yml`
- 触发方式：推送符合 `v*` 规则的 Git tag
- Release 正文来源：仓库根目录 `release_notes.md`
- 当前远程名：`Camera_Toolbox`
  - 不是 `origin`
- 当前发布分支示例：`Public`

## 发布前检查

1. 确认当前分支正确。

```powershell
git branch --show-current
```

2. 确认工作区没有不想带进发布的临时改动。

```powershell
git status
```

3. 确认远程名仍然是 `Camera_Toolbox`。

```powershell
git remote -v
```

4. 确认目标 tag 还不存在。

```powershell
git tag --list v1.3.5
```

## 修改版本信息

1. 编辑 `pubspec.yaml`

- 将：

```yaml
version: 1.3.4+1
```

- 改为：

```yaml
version: 1.3.5+2
```

规则：
- 前半段 `1.3.5` 是对外版本号
- 后半段 `+2` 是 build number
- build number 建议始终递增，不要倒退

2. 编辑 `release_notes.md`

推荐结构：

```md
## 更新内容

### v1.3.5 更新日志

1. 这里写用户能感知到的主要改进。
2. 优先写功能优化、性能提升、稳定性修复。
3. 控制在 3-6 条，避免写得太碎。
```

## 发布前验证

按顺序执行：

```powershell
dart format lib test
flutter analyze
flutter test
```

如果需要手动检查版本文件：

```powershell
Get-Content pubspec.yaml
Get-Content release_notes.md
```

## 标准发版步骤

假设这次要发布 `v1.3.5`。

1. 提交版本号和发布说明。

```powershell
git add pubspec.yaml release_notes.md
git commit -m "Release v1.3.5"
```

2. 先推送当前分支。

```powershell
git push Camera_Toolbox HEAD
```

3. 创建 tag。

```powershell
git tag v1.3.5
```

4. 推送 tag。

```powershell
git push Camera_Toolbox v1.3.5
```

## Workflow 构建结果

推送 `v1.3.5` tag 后，GitHub 会自动运行：

- `build_android`
- `build_windows`
- `build_macos`
- `release`

Actions 页面：

- `https://github.com/OldSuns/Camera_Toolbox/actions/workflows/release.yml`

Releases 页面：

- `https://github.com/OldSuns/Camera_Toolbox/releases`

正常情况下，Release 会自动附带：

- `Camera_Toolbox_Android_Release.apk`
- `Camera_Toolbox_Windows_Release.zip`
- `Camera_Toolbox_MacOS_Release.zip`

## 发布后检查

1. 到 Actions 页面确认 4 个 job 全部成功。
2. 到 Releases 页面确认新版本已生成。
3. 检查 Release 正文是否为最新 `release_notes.md` 内容。
4. 检查 3 个平台附件是否齐全。
5. 如果应用内有版本显示，确认与 `pubspec.yaml` 一致。

## 常见问题

### 1. `origin` 推送失败

本仓库默认远程名不是 `origin`，而是：

```powershell
Camera_Toolbox
```

所以推送命令应使用：

```powershell
git push Camera_Toolbox HEAD
git push Camera_Toolbox v1.3.5
```

### 2. 只推了分支，没有触发发布

原因：
- 这个 workflow 不是按普通提交触发
- 必须推送 `v*` tag 才会触发

### 3. Release 文案不对

原因：
- workflow 读取的是触发构建时仓库根目录的 `release_notes.md`

解决方式：
- 先改 `release_notes.md`
- 再提交
- 再打 tag

不要先打 tag 再改文案。

### 4. tag 打错了

如果 tag 还没推送：

```powershell
git tag -d v1.3.5
```

如果 tag 已经推送到 GitHub：

```powershell
git push Camera_Toolbox :refs/tags/v1.3.5
git tag -d v1.3.5
```

然后重新创建正确 tag 并推送。

## 推荐发版检查清单

每次发版前确认：

- `pubspec.yaml` 已更新版本号
- `release_notes.md` 已更新版本说明
- `dart format lib test` 成功
- `flutter analyze` 无问题
- `flutter test` 全通过
- `git status` 干净或仅包含本次发布改动
- 本地不存在错误 tag
- 使用的是 `Camera_Toolbox` 远程

## 一套可直接复用的命令模板

将下面的版本号替换成你的目标版本：

```powershell
git status
dart format lib test
flutter analyze
flutter test
git add pubspec.yaml release_notes.md
git commit -m "Release vX.Y.Z"
git push Camera_Toolbox HEAD
git tag vX.Y.Z
git push Camera_Toolbox vX.Y.Z
```
