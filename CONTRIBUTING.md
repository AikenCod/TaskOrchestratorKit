# Contributing

Thanks for your interest in contributing.

## Workflow

1. Fork the repository
2. Create a feature branch
3. Keep changes focused and testable
4. Open a pull request with clear context

## Pull Request Checklist

- Code builds successfully
- New behavior is covered by demo or tests
- Public API changes are documented
- No generated/user-local files are committed

## Commit Style

Use short, action-oriented commit messages, for example:

- `Add SW task timeout guard`
- `Fix cycle detection error path`
- `Update README quick start`

## Local Validation

### Swift package

```bash
cd TaskOrchestratorSwift
swift build
swift run DemoRunner
```

### iOS demo app

```bash
cd ExampleApp
pod install
open TaskOrchestratorExample.xcworkspace
```

## Code of Conduct

Please be respectful and constructive in discussions and reviews.
