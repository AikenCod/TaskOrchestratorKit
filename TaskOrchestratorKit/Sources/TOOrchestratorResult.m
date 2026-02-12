#import "TOOrchestratorResult.h"

@implementation TOOrchestratorResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _runID = [[NSUUID UUID] UUIDString];
        _success = YES;
        _orderedTaskIDs = @[];
        _skippedTaskIDs = @[];
        _errorsByTaskID = @{};
    }
    return self;
}

@end
