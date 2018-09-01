# Magisk Manager for Recovery Mode
## (c) 2017-2018, VR25 @ xda-developers
### License: GPL v3+



#### 免责声明

- 本软件以 "现状" 来提供，希望它能有用，但不作任何保证。 在安装/更新之前，请务必阅读参考资料。虽然没有猫受到伤害* ，如因使用/滥用而引致任何问题，我概不负责。
- GNU通用公共许可证第3版或更新的副本将随每个版本一起提供。 请在使用，修改和/或共享此作品的任何部分之前阅读它。
- 为了防止欺诈，不要镜像任何与项目相关的链接。

- \* 原文为 "While no cats have been harmed" 如果你有更好的翻译,请通过issue告诉我


#### 说明

- 在 Recovery 模式下管理 Magisk 镜像, 数据, 模块与设置 -- 在终端中运行 "/data/media/mm"



### 特性

- 启用/停用模块
- 更改 Magisk 设置 (使用vi编辑器)
- 自动修复 magisk.img (e2fsck -fy)
- 列出已安装的模块
- 让 magisk.img 在恢复出厂设置时不被清除
- 改变 magisk.img 的大小
- 切换自动挂载
- 卸载模块



### 安装

- 像普通的 Magisk 模块一样从 Magisk Manager 或 TWRP 刷入



### 用法

- 第一次 (在安装/升级之后) -- 执行 "mm" (在 recovery 终端).
- 下次 (在 recovery 中) -- 不需要重刷zip; 在终端上运行 "/data/media/mm"
- 按照提示/向导操作。一切都是互动的。



### 在线支持

- [Git Repository](https://github.com/Magisk-Modules-Repo/Magisk-Manager-for-Recovery-Mode)
- [XDA Thread](https://forum.xda-developers.com/apps/magisk/module-tool-magisk-manager-recovery-mode-t3693165)



### 最近的更改

**2018.8.1 (201808010)**
- 一般优化
- 新的 & 简化的安装程序
- 删除不必要的代码和文件
- 更新文档

**2018.7.24 (201807240)**
- 修复 modPath 检测问题 (Magisk V16.6).
- 更新文档

**2018.3.6 (201803060)**
- 将映像挂载点恢复为 /magisk 以便于访问（mm必须运行或使用 CTRL+C 关闭）
- 其它优化
