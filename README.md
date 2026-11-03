# 工资计时器 SalaryTicker

一个 macOS 桌面悬浮窗 + 菜单栏小工具，实时显示今天和本月已经赚了多少钱。

- 今日已赚（精确到 0.001 元，每 0.1 秒刷新）
- 每秒进账 / 时薪 / 日薪
- 已工作时长、进度条、距下班倒计时
- 本月已赚、本月剩余工作日
- 状态：在岗 / 午休 / 未上班 / 已下班 / 休息日
- 菜单栏常驻显示本月已赚
- 设置：月薪、上下班时间、午休、工作日、日薪计算方式（21.75 天 / 实际工作日）、开机启动

## 安装

到 [Releases](../../releases) 下载 `SalaryTicker.dmg`，把「工资计时器」拖进「应用程序」。

应用未经苹果公证，首次打开请右键 →「打开」，或执行：

```sh
xattr -dr com.apple.quarantine /Applications/工资计时器.app
```

## 从源码构建

需要 Xcode Command Line Tools，macOS 14+。

```sh
./build.sh      # 生成 SalaryTicker.app（Universal）
./make_dmg.sh   # 生成 SalaryTicker.dmg
```

## 使用

- 拖动悬浮窗可移动位置
- 右键悬浮窗或点击菜单栏图标：设置 / 隐藏悬浮窗 / 退出
