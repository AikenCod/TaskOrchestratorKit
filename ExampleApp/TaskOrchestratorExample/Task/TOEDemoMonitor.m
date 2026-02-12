#import "TOEDemoMonitor.h"

@interface TOEDemoMonitor ()
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, strong) NSMutableArray<NSString *> *logs;
@property (nonatomic, strong) dispatch_queue_t lockQueue;
@end

@implementation TOEDemoMonitor

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _name = [name copy];
        _logs = [NSMutableArray array];
        _lockQueue = dispatch_queue_create("com.local.taskorchestrator.example.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)appendLog:(NSString *)line {
    dispatch_sync(self.lockQueue, ^{
        [self.logs addObject:line];
    });
    NSLog(@"%@", line);
}

- (NSString *)joinedLogs {
    __block NSArray<NSString *> *snapshot = nil;
    dispatch_sync(self.lockQueue, ^{
        snapshot = [self.logs copy];
    });
    return [snapshot componentsJoinedByString:@"\n"];
}

- (void)orchestratorDidStartRun:(NSString *)runID {
    [self appendLog:[NSString stringWithFormat:@"[%@] run start: %@", self.name, runID]];
}

- (void)orchestratorWillStartTask:(NSString *)taskIdentifier runID:(NSString *)runID {
    [self appendLog:[NSString stringWithFormat:@"[%@] -> %@", self.name, taskIdentifier]];
}

- (void)orchestratorDidSkipTask:(NSString *)taskIdentifier runID:(NSString *)runID reason:(NSString *)reason {
    [self appendLog:[NSString stringWithFormat:@"[%@] skip %@ (%@)", self.name, taskIdentifier, reason]];
}

- (void)orchestratorDidFinishTask:(NSString *)taskIdentifier runID:(NSString *)runID success:(BOOL)success durationMs:(double)durationMs error:(NSError *)error {
    [self appendLog:[NSString stringWithFormat:@"[%@] <- %@ success=%d cost=%.2fms error=%@", self.name, taskIdentifier, success, durationMs, error.localizedDescription ?: @"none"]];
}

- (void)orchestratorDidFinishRun:(NSString *)runID success:(BOOL)success {
    [self appendLog:[NSString stringWithFormat:@"[%@] run finish: %@ success=%d", self.name, runID, success]];
}

@end
