Pod::Spec.new do |s|
  s.name             = 'TaskOrchestratorSwift'
  s.version          = '0.1.0'
  s.summary          = 'A deterministic task orchestrator implemented in Swift concurrency.'
  s.description      = <<-DESC
TaskOrchestratorSwift provides deterministic DAG task scheduling with
actor isolation, async/await execution, mixed execution lanes, and
run-level monitoring/result reporting.
  DESC

  s.homepage         = 'https://local.private/TaskOrchestratorSwift'
  s.license          = { :type => 'MIT', :text => 'Private local library for internal usage.' }
  s.author           = { 'LocalTeam' => 'local@company.com' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '13.0'
  s.requires_arc     = true
  s.swift_version    = '5.5'

  s.source_files     = 'TaskOrchestratorSwift/Sources/TaskOrchestratorSwift/**/*.swift'
  s.frameworks       = 'Foundation'
end
