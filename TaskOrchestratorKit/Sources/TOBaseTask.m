#import "TOBaseTask.h"

@implementation TOBaseTask

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _taskIdentifier = [identifier copy];
        _priority = 0;
        _dependencies = @[];
        _executionMode = TOExecutionModeSerial;
        _continueOnFailure = NO;
    }
    return self;
}

- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError * _Nullable __autoreleasing *)error {
#if DEBUG
    NSAssert(NO, @"Task %@ must override executeWithContext:error: or executeWithContext:completion:", self.taskIdentifier ?: @"<unknown>");
#endif
    if (error) {
        *error = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                     code:-1000
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Task %@ does not override execute method", self.taskIdentifier ?: @"<unknown>"]}];
    }
    return NO;
}

- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion {
    NSError *error = nil;
    BOOL ok = [self executeWithContext:context error:&error];
    if (completion) {
        completion(ok, error);
    }
}

- (void)cancel {
}

- (void)prepareWithContext:(NSMutableDictionary *)context {
}

@end
