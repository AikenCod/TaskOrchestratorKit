# TaskOrchestratorKit (English)

A deterministic startup task orchestration framework with both Objective-C and Swift implementations.

## Features

- Deterministic ordering (priority + registration order)
- DAG dependency scheduling with cycle detection
- Mixed execution lanes: serial / main-thread / concurrent
- Pluggable state store with idempotent skipping
- Observer callbacks for full run visibility
- Structured run result for diagnostics and control flow

## Repository Structure

- `TaskOrchestratorKit/` Objective-C implementation
- `TaskOrchestratorSwift/` Swift-native implementation (SPM + CocoaPods)
- `ExampleApp/` iOS demo app for runtime verification

## Installation

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

In `Package.swift`:

```swift
.package(url: "https://github.com/<YOUR_ORG>/TaskOrchestratorKit.git", branch: "main")
```

Then add the product dependency: `TaskOrchestratorSwift`

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

## Quick Usage

### Objective-C

```objc
TOOrchestratorConfig *config = [TOOrchestratorConfig new];
TOOrchestrator *orchestrator = [[TOOrchestrator alloc] initWithConfig:config];
TOOrchestratorResult *result = [orchestrator runWithContext:[NSMutableDictionary dictionary]];
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

## Run the Demo App

```bash
cd ExampleApp
pod install
open TaskOrchestratorExample.xcworkspace
```

In-app buttons:

- `运行正常依赖`: Objective-C normal DAG flow
- `运行循环依赖`: Objective-C cycle detection flow
- `运行 Swift Demo`: Swift flow using `TaskOrchestratorSwift`

## Contributing

See `CONTRIBUTING.md` at repository root.

## License

MIT. See `LICENSE`.
