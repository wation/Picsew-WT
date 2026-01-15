# iOS控制中心显示问题修复指南

## 问题描述

当前PicsewAI iOS应用无法在iPhone控制中心的屏幕录制菜单中显示。

## 根本原因

缺少`Broadcast Setup UI Extension`组件。iOS控制中心屏幕录制菜单需要应用提供两个扩展：
1. `Broadcast Setup UI Extension` - 用于在控制中心显示并处理录屏前的设置
2. `Broadcast Upload Extension` - 用于处理实际的录屏数据

当前项目只有`Broadcast Upload Extension`，缺少`Broadcast Setup UI Extension`。

## 解决方案

在Xcode中手动添加`Broadcast Setup UI Extension`，具体步骤如下：

### 步骤1：添加Broadcast Setup UI Extension目标

1. 打开Xcode项目 `PicsewAI.xcodeproj`
2. 在项目导航器中，右键点击项目名称，选择 `New Target...`
3. 在弹出的模板选择窗口中，选择 `iOS` > `Application Extension` > `Broadcast Setup UI Extension`
4. 点击 `Next`
5. 配置扩展信息：
   - Product Name: `BroadcastSetup`
   - Organization Identifier: `com.magixun.picsewai`
   - Bundle Identifier: 自动生成为 `com.magixun.picsewai.BroadcastSetup`
   - Team: 选择与主应用相同的开发团队
   - Language: Swift
6. 点击 `Finish`
7. 当Xcode询问是否激活方案时，选择 `Activate`

### 步骤2：配置Extension的Info.plist

1. 在项目导航器中，找到 `BroadcastSetup` 扩展的 `Info.plist` 文件
2. 确保以下配置正确：
   - Bundle Identifier: `com.magixun.picsewai.BroadcastSetup`
   - NSExtension > NSExtensionPointIdentifier: `com.apple.broadcast-setup-ui-extension`
   - NSExtension > NSExtensionAttributes > RPBroadcastHostBundleIdentifier: `com.magixun.picsewai`
   - NSExtension > NSExtensionAttributes > RPBroadcastProcessMode: `RPBroadcastProcessModeSampleBuffer`
   - NSExtension > NSExtensionMainStoryboard: `MainInterface`

### 步骤3：配置App Group权限

1. 选择 `BroadcastSetup` 扩展目标
2. 切换到 `Signing & Capabilities` 标签
3. 点击 `+ Capability` 按钮
4. 搜索并添加 `App Groups` 权限
5. 勾选与主应用和Upload扩展相同的App Group: `group.com.magixun.picsewai`

### 步骤4：实现Broadcast Setup UI Extension代码

1. 在 `BroadcastSetup` 扩展中，找到并打开 `BroadcastSetupViewController.swift`
2. 替换为以下代码：

```swift
import UIKit
import ReplayKit

/// 控制中心录屏设置界面控制器
class BroadcastSetupViewController: RPBroadcastPickerExtensionViewController {
    
    // 开始录屏按钮
    private let startButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 配置界面
        setupUI()
        
        // 设置背景色
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
    }
    
    /// 配置界面元素
    private func setupUI() {
        // 配置开始录屏按钮
        startButton.setTitle("开始录屏", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 12
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        // 添加按钮到视图
        view.addSubview(startButton)
        
        // 设置按钮约束
        startButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 添加按钮点击事件
        startButton.addTarget(self, action: #selector(startBroadcast), for: .touchUpInside)
    }
    
    /// 处理开始录屏按钮点击事件
    @objc private func startBroadcast() {
        // 直接完成请求，使用默认的广播控制器
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
```

### 步骤5：修改MainInterface.storyboard（可选）

1. 在 `BroadcastSetup` 扩展中，找到并打开 `MainInterface.storyboard`
2. 可以根据需要自定义界面，但保持简洁即可
3. 确保故事板中的视图控制器类设置为 `BroadcastSetupViewController`

### 步骤6：将扩展嵌入到主应用

1. 选择主应用目标 `PicsewAI`
2. 切换到 `General` 标签
3. 在 `Frameworks, Libraries, and Embedded Content` 部分
4. 点击 `+` 按钮，选择 `BroadcastSetup.appex`
5. 设置嵌入方式为 `Embed & Sign`

### 步骤7：测试

1. 连接iPhone设备到Mac
2. 选择 `BroadcastSetup` 扩展目标，确保运行设备为你的iPhone
3. 点击Xcode的运行按钮，选择主应用 `PicsewAI` 进行运行
4. 在iPhone上，打开控制中心
5. 长按屏幕录制按钮
6. 你应该能看到 `PicsewAI 录屏设置` 出现在可用的录屏应用列表中

## 技术说明

- **Broadcast Setup UI Extension**：用于在控制中心显示应用，并处理用户的录屏请求
- **Broadcast Upload Extension**：用于实际处理录屏数据，已经存在于项目中
- **App Group**：用于扩展之间以及扩展与主应用之间的通信
- **ReplayKit**：苹果提供的用于屏幕录制和广播的框架

## 注意事项

1. 确保所有扩展使用相同的App Group
2. 确保所有扩展的Bundle Identifier遵循主应用+扩展类型的命名规则
3. 确保所有扩展使用相同的开发团队和签名配置
4. 测试时需要使用真实设备，模拟器不支持控制中心扩展
5. 如果仍然无法显示，可以尝试重启设备或重新安装应用

## 预期效果

完成上述步骤后，应用将能够：
1. 在iPhone控制中心的屏幕录制菜单中显示
2. 用户长按屏幕录制按钮时，能看到PicsewAI应用
3. 点击应用后，显示自定义的录屏设置界面
4. 成功开始和停止录屏，并将数据传递给主应用处理