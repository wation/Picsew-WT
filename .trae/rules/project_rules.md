Picsew-WT 项目专属开发规则
1. 项目命名与目录落地
1.1 根文件夹命名：Picsew-WT
1.2 平台子目录
1.2.1 安卓端目录：Picsew-WT-Android
1.2.2 iOS 端目录：Picsew-WT-iOS
2. 包名与唯一标识落地
2.1 安卓包名：com.magixun.picsewwt
2.2 iOS Bundle ID：com.magixun.picsewwt
3. 技术合规落地（直接沿用个人规则，无额外补充）
4. 机型适配落地（直接沿用个人规则，无额外补充）
5. 开发模式与架构落地
5.1 iOS 端：长截图核心模块放在 “Picsew-WT-iOS/Modules/Screenshot/” 目录，按 MVVM 拆分
5.1.1 View 层：实现长截图预览、裁剪、保存界面（适配灵动岛 / 刘海屏）
5.1.2 ViewModel 层：处理截图拼接、自动滚动截图逻辑、权限申请（相册 / 屏幕录制）
5.1.3 Model 层：定义截图参数（分辨率、拼接方式）、本地存储模型
5.2 安卓端：长截图核心代码放在 “Picsew-WT-Android/app/src/main/java/com/magixun/picsewwt/screenshot/” 目录
6. 多语言与本地化落地
6.1 语言文件路径
6.1.1 iOS 端：Picsew-WT-iOS/Resources/i18n/（存放 6 种语言包）
6.1.2 安卓端：Picsew-WT-Android/app/src/main/res/values-xx/（xx=zh/en/ja/ko/es/pt）
6.2 核心注释：长截图功能的 “悬浮窗权限”“屏幕录制权限”“图片拼接算法” 需重点标注
7. 输出文档规范（直接沿用个人规则，无额外补充）