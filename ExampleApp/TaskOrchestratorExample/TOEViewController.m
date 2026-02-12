#import "TOEViewController.h"

#import "TOOrchestrator.h"
#import "Task/TOEDemoTasks.h"
#import "Task/TOEDemoMonitor.h"
#import "TaskOrchestratorExample-Swift.h"

@interface TOEViewController ()
@property (nonatomic, strong) UIButton *normalButton;
@property (nonatomic, strong) UIButton *cycleButton;
@property (nonatomic, strong) UIButton *swiftButton;
@property (nonatomic, strong) UITextView *textView;
@end

@implementation TOEViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"TaskOrchestrator Debug";

    self.normalButton = [self buildButtonWithTitle:@"运行正常依赖" action:@selector(runNormalFlow)];
    self.cycleButton = [self buildButtonWithTitle:@"运行循环依赖" action:@selector(runCycleFlow)];
    self.swiftButton = [self buildButtonWithTitle:@"运行 Swift Demo" action:@selector(runSwiftFlow)];

    self.textView = [[UITextView alloc] init];
    self.textView.editable = NO;
    self.textView.font = [UIFont systemFontOfSize:13.0];
    self.textView.text = @"点击上方按钮开始调试。";
    self.textView.layer.borderColor = [UIColor colorWithWhite:0.88 alpha:1.0].CGColor;
    self.textView.layer.borderWidth = 1.0;
    self.textView.layer.cornerRadius = 8.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.normalButton, self.cycleButton, self.swiftButton]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 12.0;
    stack.distribution = UIStackViewDistributionFillEqually;

    [self.view addSubview:stack];
    [self.view addSubview:self.textView];

    stack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12.0],
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16.0],
        [stack.heightAnchor constraintEqualToConstant:40.0],

        [self.textView.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:12.0],
        [self.textView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16.0],
        [self.textView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16.0],
        [self.textView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12.0],
    ]];
}

- (UIButton *)buildButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    button.layer.cornerRadius = 8.0;
    button.backgroundColor = [UIColor colorWithRed:0.22 green:0.52 blue:0.95 alpha:1.0];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)runNormalFlow {
    [self runScenarioWithName:@"normal"
                  taskTypes:[TOEDemoTaskBuilder normalTaskExecutionTypes]
                 buildTasks:^(TOOrchestrator *orchestrator) {
        [TOEDemoTaskBuilder registerNormalTasksOnOrchestrator:orchestrator];
    }];
}

- (void)runCycleFlow {
    [self runScenarioWithName:@"cycle"
                  taskTypes:[TOEDemoTaskBuilder cycleTaskExecutionTypes]
                 buildTasks:^(TOOrchestrator *orchestrator) {
        [TOEDemoTaskBuilder registerCycleTasksOnOrchestrator:orchestrator];
    }];
}

- (void)runSwiftFlow {
    self.normalButton.enabled = NO;
    self.cycleButton.enabled = NO;
    self.swiftButton.enabled = NO;
    self.textView.text = @"[swift] 运行中...";

    [TOESwiftDemoBridge runScenario:@"normal" completion:^(NSString * _Nonnull output) {
        self.textView.text = output ?: @"(empty)";
        self.normalButton.enabled = YES;
        self.cycleButton.enabled = YES;
        self.swiftButton.enabled = YES;
    }];
}

- (void)runScenarioWithName:(NSString *)name
                  taskTypes:(NSDictionary<NSString *, NSString *> *)taskTypes
                 buildTasks:(void (^)(TOOrchestrator *orchestrator))builder {
    self.normalButton.enabled = NO;
    self.cycleButton.enabled = NO;
    self.swiftButton.enabled = NO;
    self.textView.text = [NSString stringWithFormat:@"[%@] 运行中...", name];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        TOOrchestratorConfig *config = [[TOOrchestratorConfig alloc] init];
        config.maxBackgroundConcurrency = 3;
        config.backgroundWaveTimeoutSeconds = 20;

        TOOrchestrator *orchestrator = [[TOOrchestrator alloc] initWithConfig:config];
        TOEDemoMonitor *monitor = [[TOEDemoMonitor alloc] initWithName:name];
        orchestrator.monitor = monitor;

        builder(orchestrator);

        NSMutableDictionary *context = [NSMutableDictionary dictionary];
        TOOrchestratorResult *result = [orchestrator runWithContext:context];

        NSString *orderText = result.orderedTaskIDs.count > 0 ? [result.orderedTaskIDs componentsJoinedByString:@" -> "] : @"(none)";
        NSString *cyclePath = [self cyclePathFromResult:result];

        NSMutableString *typedOrder = [NSMutableString string];
        for (NSString *taskID in result.orderedTaskIDs) {
            NSString *type = taskTypes[taskID] ?: @"unknown";
            [typedOrder appendFormat:@"%@(%@) ", taskID, type];
        }

        NSMutableString *output = [NSMutableString string];
        [output appendFormat:@"场景: %@\n", name];
        [output appendFormat:@"success: %d\n", result.success];
        [output appendFormat:@"failedTaskID: %@\n", result.failedTaskID ?: @"none"];
        [output appendFormat:@"ordered: %@\n", orderText];
        [output appendFormat:@"orderedWithType: %@\n", typedOrder.length > 0 ? typedOrder : @"(none)"];
        if (cyclePath.length > 0) {
            [output appendFormat:@"cyclePath: %@\n", cyclePath];
        }
        [output appendFormat:@"errors: %@\n", result.errorsByTaskID ?: @{}];
        [output appendString:@"\n---- Monitor Logs ----\n"];
        [output appendString:[monitor joinedLogs]];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.textView.text = output;
            self.normalButton.enabled = YES;
            self.cycleButton.enabled = YES;
            self.swiftButton.enabled = YES;
        });
    });
}

- (NSString *)cyclePathFromResult:(TOOrchestratorResult *)result {
    NSArray<NSString *> *keys = @[@"<graph>", @"<cycle>"];
    for (NSString *key in keys) {
        NSError *error = result.errorsByTaskID[key];
        NSString *path = error.userInfo[@"cyclePath"];
        if (path.length > 0) {
            return path;
        }
    }
    return @"";
}

@end
