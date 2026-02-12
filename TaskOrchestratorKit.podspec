Pod::Spec.new do |s|
  s.name             = 'TaskOrchestratorKit'
  s.version          = '0.1.0'
  s.summary          = 'A deterministic task orchestrator for app launch and startup workflows.'
  s.description      = <<-DESC
TaskOrchestratorKit provides deterministic startup task scheduling with:
- stable ordering (priority + registration index)
- DAG dependency resolution
- idempotent state store
- mixed execution modes (sync/main/background)
- monitor hooks and run result reporting
  DESC

  s.homepage         = 'https://local.private/TaskOrchestratorKit'
  s.license          = { :type => 'MIT', :text => 'Private local library for internal usage.' }
  s.author           = { 'LocalTeam' => 'local@company.com' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '13.0'
  s.requires_arc     = true

  s.source_files     = 'TaskOrchestratorKit/Sources/**/*.{h,m}'
  s.public_header_files = 'TaskOrchestratorKit/Sources/**/*.h'

  s.frameworks       = 'Foundation'
end
