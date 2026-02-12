# TaskOrchestratorKit

Deterministic task orchestration for app startup workflows, with both Objective-C and Swift implementations.

[中文文档](docs/README.zh-CN.md) | [English Docs](docs/README.en.md)

## Keywords

- iOS 启动优化 / iOS startup optimization
- DAG 调度 / DAG scheduling
- 任务编排 / task orchestration

## Highlights

- Deterministic execution order: priority + registration order
- DAG dependency scheduling with cycle detection
- Mixed execution lanes: serial / main-thread / concurrent
- Idempotent state store support
- Run-level observer hooks and structured result output
- Objective-C core and Swift native implementation in one repo

## Repository Layout

- `TaskOrchestratorKit/` Objective-C implementation
- `TaskOrchestratorSwift/` Swift implementation (SPM + CocoaPods)
- `ExampleApp/` iOS demo app with Objective-C and Swift demo entries

## Quick Start

### Objective-C (CocoaPods)

Remote (GitHub):

```ruby
pod 'TaskOrchestratorKit', :git => 'https://github.com/AikenCod/TaskOrchestratorKit.git', :branch => 'main'
```

Local development:

```ruby
pod 'TaskOrchestratorKit', :path => '/path/to/TaskOrchestratorKit'
```

### Swift (SPM)

```swift
.package(url: "https://github.com/<YOUR_ORG>/TaskOrchestratorKit.git", branch: "main")
```

Then import:

```swift
import TaskOrchestratorSwift
```

### Swift (CocoaPods)

Remote (GitHub):

```ruby
pod 'TaskOrchestratorSwift', :git => 'https://github.com/AikenCod/TaskOrchestratorKit.git', :branch => 'main'
```

Local development:

```ruby
pod 'TaskOrchestratorSwift', :path => '/path/to/TaskOrchestratorKit'
```

## Run Demo App

```bash
cd ExampleApp
pod install
open TaskOrchestratorExample.xcworkspace
```

In the app:

- `运行正常依赖` runs Objective-C normal DAG flow
- `运行循环依赖` runs Objective-C cycle detection flow
- `运行 Swift Demo` runs Swift flow through `TaskOrchestratorSwift`

## Release

- [v0.1.0 Release Note](docs/releases/v0.1.0.md)
- [Changelog](CHANGELOG.md)

## License

MIT. See [LICENSE](LICENSE).
