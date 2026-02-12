# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-02-12

### Added

- Objective-C task orchestrator core (`TaskOrchestratorKit`) with:
  - deterministic ordering (priority + registration order)
  - DAG dependency scheduling and cycle detection
  - mixed execution modes (serial/main/concurrent)
  - idempotent state store and observer callbacks
- Swift-native task orchestrator (`TaskOrchestratorSwift`) with:
  - actor-based orchestrator and state store
  - async/await task execution
  - timeout controls and run result aggregation
- iOS ExampleApp with both Objective-C and Swift demo flows.
- CocoaPods support for both products:
  - `TaskOrchestratorKit`
  - `TaskOrchestratorSwift`
- SPM support via repository root `Package.swift`.
- Bilingual documentation (Chinese / English).
- GitHub templates and CI workflow.

### Notes

- This is the first public release.
- Swift public API uses unified `SW*` naming convention.
