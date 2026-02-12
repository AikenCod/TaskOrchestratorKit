import TaskOrchestratorSwift

#if DEMO_RUNNER
@main
struct DemoRunner {
    static func main() async {
        await SWDemoScenarioRunner.runAll()
    }
}
#endif
