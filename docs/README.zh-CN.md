# TaskOrchestratorKit（中文）

一个面向 App 启动编排的任务调度框架，提供 Objective-C 与 Swift 两套实现。

## 特性

- 确定性执行顺序（优先级 + 注册顺序）
- DAG 依赖调度 + 循环依赖检测
- 多执行通道：串行 / 主线程 / 并发
- 可插拔任务状态存储（支持幂等跳过）
- 可观测回调（开始、跳过、结束、整轮结束）
- 统一结果对象（有序任务、失败任务、错误映射）

## 仓库结构

- `TaskOrchestratorKit/`：Objective-C 核心实现
- `TaskOrchestratorSwift/`：Swift 原生实现（支持 SPM / CocoaPods）
- `ExampleApp/`：iOS 示例应用（可直接运行验证）

## 安装

### 1) Objective-C（CocoaPods）

```ruby
pod 'TaskOrchestratorKit', :path => '/path/to/TaskOrchestratorKit'
```

### 2) Swift（SPM）

`Package.swift`:

```swift
.package(url: "https://github.com/<YOUR_ORG>/TaskOrchestratorKit.git", branch: "main")
```

目标依赖产品：`TaskOrchestratorSwift`

代码中导入：

```swift
import TaskOrchestratorSwift
```

### 3) Swift（CocoaPods）

```ruby
pod 'TaskOrchestratorSwift', :path => '/path/to/TaskOrchestratorKit'
```

## 快速使用

### Objective-C

```objc
TOOrchestratorConfig *config = [TOOrchestratorConfig new];
TOOrchestrator *orchestrator = [[TOOrchestrator alloc] initWithConfig:config];

// 注册任务...
TOOrchestratorResult *result = [orchestrator runWithContext:[NSMutableDictionary dictionary]];
NSLog(@"success=%d failedTask=%@", result.success, result.failedTaskID);
```

### Swift

```swift
import TaskOrchestratorSwift

let config = SWOrchestratorConfiguration(
    maxConcurrentTasks: 3,
    strictDependencyCheck: true,
    waveTimeoutSeconds: 20,
    taskTimeoutSeconds: 20
)
let orchestrator = SWTaskOrchestrator(configuration: config)
```

## 运行示例 App

```bash
cd ExampleApp
pod install
open TaskOrchestratorExample.xcworkspace
```

在 App 中：

- `运行正常依赖`：ObjC 正常依赖场景
- `运行循环依赖`：ObjC 循环依赖场景
- `运行 Swift Demo`：Swift 版本场景（通过 `TaskOrchestratorSwift` 库调用）

## 开发建议

- 新增任务时，优先定义清晰 `taskIdentifier` 与 `dependencies`
- 需要主线程操作（如路由/UI）时，明确设置主线程执行模式
- 对可容忍失败的任务，单独设置“失败后继续”策略
- 为关键任务增加 observer 日志，便于排障

## 贡献

见仓库根目录 `CONTRIBUTING.md`。

## 许可证

MIT，见 `LICENSE`。
