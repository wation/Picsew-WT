# 修复iOS录屏扩展配置问题

## 问题分析
根据错误信息和代码检查，发现以下问题：
1. BroadcastUpload扩展的CODE_SIGN_ENTITLEMENTS路径配置错误
2. 缺少BroadcastUpload.entitlements文件
3. Info.plist中的NSExtensionPrincipalClass可能需要包含模块名

## 修复步骤

### 1. 修正BroadcastUpload扩展的entitlements文件路径
- 打开project.pbxproj文件
- 将BroadcastUpload扩展的CODE_SIGN_ENTITLEMENTS从"Picsew-WT-Extension.entitlements"改为"Extensions/BroadcastUpload/BroadcastUpload.entitlements"

### 2. 创建BroadcastUpload.entitlements文件
- 在Extensions/BroadcastUpload目录下创建BroadcastUpload.entitlements文件
- 添加必要的权限配置，包括App Group权限

### 3. 修正SampleHandler的NSExtensionPrincipalClass配置
- 打开BroadcastUpload/Info.plist文件
- 将NSExtensionPrincipalClass从"SampleHandler"改为"PicsewWTExtension.SampleHandler"（包含模块名）

### 4. 验证配置
- 运行xcodebuild clean build命令验证修复是否成功
- 检查是否还有扩展点未识别的错误

## 预期结果
- iOS应用能正确出现在控制中心的屏幕录制菜单中
- 不再出现扩展点未识别的错误
- 录屏扩展能正常工作