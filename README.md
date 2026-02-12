# TaskOrchestratorKit

Deterministic task orchestration for app startup workflows, with both Objective-C and Swift implementations.

[中文文档](docs/README.zh-CN.md) | [English Docs](docs/README.en.md)

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

## License

MIT. See [LICENSE](LICENSE).
