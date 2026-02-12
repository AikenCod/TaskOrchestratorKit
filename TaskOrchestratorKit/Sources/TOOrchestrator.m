#import "TOOrchestrator.h"
#import "TOMemoryStateStore.h"
#import <pthread/pthread.h>
#import <stdatomic.h>

static const void *kTORegistryQueueKey = &kTORegistryQueueKey;
static const void *kTOExecutionQueueKey = &kTOExecutionQueueKey;

@interface TORegisteredTaskEntry : NSObject
@property (nonatomic, strong) id<TOOrchestratorTask> task;
@property (nonatomic, assign) NSInteger registerIndex;
@property (nonatomic, assign) NSInteger inDegree;
@property (nonatomic, strong) NSMutableArray<NSString *> *dependents;
@end

@implementation TORegisteredTaskEntry
- (instancetype)init {
    self = [super init];
    if (self) {
        _dependents = [NSMutableArray arrayWithCapacity:8];
    }
    return self;
}
@end

@interface TOOrchestrator ()
@property (nonatomic, strong) NSMutableArray<id<TOOrchestratorTask>> *tasks;
@property (nonatomic, strong, readwrite) TOOrchestratorConfig *config;
@property (nonatomic, strong) dispatch_queue_t registryQueue;
@property (nonatomic, strong) dispatch_queue_t executionQueue;
@property (nonatomic, strong) dispatch_queue_t resultQueue;
@end

@implementation TOOrchestrator

- (instancetype)initWithConfig:(TOOrchestratorConfig *)config {
    self = [super init];
    if (self) {
        _tasks = [NSMutableArray array];
        _config = config ?: [[TOOrchestratorConfig alloc] init];
        _stateStore = [[TOMemoryStateStore alloc] init];
        _registryQueue = dispatch_queue_create("com.local.taskorchestrator.registry", DISPATCH_QUEUE_SERIAL);
        _executionQueue = dispatch_queue_create("com.local.taskorchestrator.execution", DISPATCH_QUEUE_SERIAL);
        _resultQueue = dispatch_queue_create("com.local.taskorchestrator.result", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_registryQueue, kTORegistryQueueKey, (void *)kTORegistryQueueKey, NULL);
        dispatch_queue_set_specific(_executionQueue, kTOExecutionQueueKey, (void *)kTOExecutionQueueKey, NULL);
    }
    return self;
}

- (void)registerTask:(id<TOOrchestratorTask>)task {
    if (!task || task.taskIdentifier.length == 0) {
        return;
    }

    if (dispatch_get_specific(kTORegistryQueueKey)) {
        [self.tasks addObject:task];
        return;
    }

    dispatch_sync(self.registryQueue, ^{
        [self.tasks addObject:task];
    });
}

- (void)clearTasks {
    if (dispatch_get_specific(kTORegistryQueueKey)) {
        [self.tasks removeAllObjects];
        return;
    }

    dispatch_sync(self.registryQueue, ^{
        [self.tasks removeAllObjects];
    });
}

- (TOOrchestratorResult *)runWithContext:(NSMutableDictionary *)context {
    if (dispatch_get_specific(kTOExecutionQueueKey)) {
        return [self runLockedWithContext:context];
    }

    __block TOOrchestratorResult *finalResult = nil;
    dispatch_sync(self.executionQueue, ^{
        finalResult = [self runLockedWithContext:context];
    });
    return finalResult;
}

- (TOOrchestratorResult *)runLockedWithContext:(NSMutableDictionary *)context {
    TOOrchestratorResult *result = [[TOOrchestratorResult alloc] init];
    NSMutableDictionary *runtimeContext = context ?: [NSMutableDictionary dictionary];

    __block NSArray<id<TOOrchestratorTask>> *taskSnapshot = nil;
    if (dispatch_get_specific(kTORegistryQueueKey)) {
        taskSnapshot = [self.tasks copy];
    } else {
        dispatch_sync(self.registryQueue, ^{
            taskSnapshot = [self.tasks copy];
        });
    }

    NSMutableArray<NSString *> *ordered = [NSMutableArray arrayWithCapacity:taskSnapshot.count];
    NSMutableArray<NSString *> *skipped = [NSMutableArray arrayWithCapacity:8];
    NSMutableDictionary<NSString *, NSError *> *errors = [NSMutableDictionary dictionaryWithCapacity:4];

    [self safeMonitorDidStartRun:result.runID];

    NSError *graphError = nil;
    NSDictionary<NSString *, TORegisteredTaskEntry *> *entryByID = [self buildGraphWithTasks:taskSnapshot error:&graphError];
    if (graphError) {
        result.success = NO;
        result.failedTaskID = @"<graph>";
        result.errorsByTaskID = @{ @"<graph>": graphError };
        [self safeMonitorDidFinishRun:result.runID success:NO];
        return result;
    }

    NSMutableArray<TORegisteredTaskEntry *> *ready = [NSMutableArray array];
    [entryByID enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, TORegisteredTaskEntry * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.inDegree == 0) {
            [ready addObject:obj];
        }
    }];

    NSInteger completedCount = 0;
    BOOL shouldStop = NO;

    while (!shouldStop && completedCount < entryByID.count) {
        if (ready.count == 0) {
            NSError *cycleError = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                                      code:-2003
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Dependency cycle detected.", @"cyclePath": [self cyclePathInGraph:entryByID]}];
            result.success = NO;
            result.failedTaskID = @"<cycle>";
            errors[@"<cycle>"] = cycleError;
            break;
        }

        [ready sortUsingComparator:^NSComparisonResult(TORegisteredTaskEntry * _Nonnull a, TORegisteredTaskEntry * _Nonnull b) {
            NSInteger ap = [self priorityForTask:a.task];
            NSInteger bp = [self priorityForTask:b.task];
            if (ap > bp) { return NSOrderedAscending; }
            if (ap < bp) { return NSOrderedDescending; }
            if (a.registerIndex < b.registerIndex) { return NSOrderedAscending; }
            if (a.registerIndex > b.registerIndex) { return NSOrderedDescending; }
            return NSOrderedSame;
        }];

        NSArray<TORegisteredTaskEntry *> *wave = [ready copy];
        [ready removeAllObjects];

        NSMutableArray<TORegisteredTaskEntry *> *normalEntries = [NSMutableArray array];
        NSMutableArray<TORegisteredTaskEntry *> *backgroundEntries = [NSMutableArray array];

        for (TORegisteredTaskEntry *entry in wave) {
            if ([self executionModeForTask:entry.task] == TOExecutionModeConcurrent) {
                [backgroundEntries addObject:entry];
            } else {
                [normalEntries addObject:entry];
            }
        }

        NSMutableArray<TORegisteredTaskEntry *> *succeededEntries = [NSMutableArray array];

        for (TORegisteredTaskEntry *entry in normalEntries) {
            BOOL recorded = NO;
            BOOL ok = [self executeEntry:entry
                                   runID:result.runID
                                 context:runtimeContext
                                 ordered:ordered
                                 skipped:skipped
                                  errors:errors
                           acceptResults:NULL
                                recorded:&recorded];
            if (recorded) {
                completedCount += 1;
            }
            if (ok && recorded) {
                [succeededEntries addObject:entry];
            } else if (recorded) {
                result.success = NO;
                result.failedTaskID = entry.task.taskIdentifier;
                shouldStop = ![self continueOnFailureForTask:entry.task];
                if (shouldStop) { break; }
            }
        }

        if (!shouldStop && backgroundEntries.count > 0) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_semaphore_t limiter = dispatch_semaphore_create(MAX(1, self.config.maxBackgroundConcurrency));
            dispatch_queue_t lock = dispatch_queue_create("com.local.taskorchestrator.bgresult", DISPATCH_QUEUE_SERIAL);
            atomic_bool acceptResults;
            atomic_init(&acceptResults, true);
            atomic_bool *acceptResultsPtr = &acceptResults;

            NSMutableArray<TORegisteredTaskEntry *> *bgSucceeded = [NSMutableArray array];
            NSMutableArray<TORegisteredTaskEntry *> *bgFailed = [NSMutableArray array];

            for (TORegisteredTaskEntry *entry in backgroundEntries) {
                dispatch_semaphore_wait(limiter, DISPATCH_TIME_FOREVER);
                dispatch_group_enter(group);
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                    BOOL recorded = NO;
                    BOOL ok = [self executeEntry:entry
                                           runID:result.runID
                                         context:runtimeContext
                                         ordered:ordered
                                         skipped:skipped
                                          errors:errors
                                   acceptResults:acceptResultsPtr
                                        recorded:&recorded];

                    dispatch_sync(lock, ^{
                        if (recorded) {
                            if (ok) {
                                [bgSucceeded addObject:entry];
                            } else {
                                [bgFailed addObject:entry];
                            }
                        }
                    });
                    dispatch_semaphore_signal(limiter);
                    dispatch_group_leave(group);
                });
            }

            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.config.backgroundWaveTimeoutSeconds * NSEC_PER_SEC));
            long waitResult = dispatch_group_wait(group, timeout);
            if (waitResult != 0) {
                atomic_store(acceptResultsPtr, false);
                NSError *timeoutError = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                                            code:-2004
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Background wave timeout."}];
                dispatch_sync(self.resultQueue, ^{
                    errors[@"<timeout>"] = timeoutError;
                });
                result.success = NO;
                result.failedTaskID = @"<timeout>";
                shouldStop = YES;
            }

            completedCount += (bgSucceeded.count + bgFailed.count);
            [succeededEntries addObjectsFromArray:bgSucceeded];

            if (bgFailed.count > 0) {
                TORegisteredTaskEntry *firstFailed = bgFailed.firstObject;
                result.success = NO;
                if (!result.failedTaskID.length) {
                    result.failedTaskID = firstFailed.task.taskIdentifier;
                }

                __block BOOL allRequireStop = YES;
                dispatch_sync(self.resultQueue, ^{
                    for (TORegisteredTaskEntry *failed in bgFailed) {
                        if ([self continueOnFailureForTask:failed.task]) {
                            allRequireStop = NO;
                        }
                        if (!errors[failed.task.taskIdentifier]) {
                            errors[failed.task.taskIdentifier] = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                                                                      code:-2101
                                                                                  userInfo:@{NSLocalizedDescriptionKey: @"Background task failed."}];
                        }
                    }
                });
                shouldStop = shouldStop || allRequireStop;
            }
        }

        for (TORegisteredTaskEntry *successEntry in succeededEntries) {
            for (NSString *dependentID in successEntry.dependents) {
                TORegisteredTaskEntry *depEntry = entryByID[dependentID];
                depEntry.inDegree -= 1;
                if (depEntry.inDegree == 0) {
                    [ready addObject:depEntry];
                }
            }
        }
    }

    result.orderedTaskIDs = [ordered copy];
    result.skippedTaskIDs = [skipped copy];
    result.errorsByTaskID = [errors copy];

    if (errors.count > 0 && result.failedTaskID.length == 0) {
        result.success = NO;
    }

    [self safeMonitorDidFinishRun:result.runID success:result.success];
    return result;
}

- (NSDictionary<NSString *, TORegisteredTaskEntry *> *)buildGraphWithTasks:(NSArray<id<TOOrchestratorTask>> *)tasks
                                                                      error:(NSError **)error {
    NSMutableDictionary<NSString *, TORegisteredTaskEntry *> *entryByID = [NSMutableDictionary dictionaryWithCapacity:tasks.count];

    [tasks enumerateObjectsUsingBlock:^(id<TOOrchestratorTask>  _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        if (task.taskIdentifier.length == 0) {
            return;
        }
        TORegisteredTaskEntry *entry = [[TORegisteredTaskEntry alloc] init];
        entry.task = task;
        entry.registerIndex = (NSInteger)idx;
        entry.inDegree = 0;
        entryByID[task.taskIdentifier] = entry;
    }];

    if (entryByID.count != tasks.count) {
        if (error) {
            *error = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                         code:-2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Duplicate or empty taskIdentifier found."}];
        }
        return nil;
    }

    __block NSError *localError = nil;
    [entryByID enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull taskID, TORegisteredTaskEntry * _Nonnull entry, BOOL * _Nonnull stop) {
        if (localError) {
            *stop = YES;
            return;
        }

        NSArray<NSString *> *deps = [self dependenciesForTask:entry.task];
        for (NSString *depID in deps) {
            TORegisteredTaskEntry *depEntry = entryByID[depID];
            if (!depEntry) {
                if (self.config.strictDependencyCheck) {
                    localError = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                                     code:-2002
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Task %@ depends on missing task %@", taskID, depID]}];
                    *stop = YES;
                    break;
                }
                continue;
            }
            entry.inDegree += 1;
            [depEntry.dependents addObject:taskID];
        }
    }];

    if (localError) {
        if (error) { *error = localError; }
        return nil;
    }

    NSString *cyclePath = [self cyclePathInGraph:entryByID];
    if (cyclePath.length > 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                         code:-2003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Dependency cycle detected.", @"cyclePath": cyclePath}];
        }
        return nil;
    }

    return entryByID;
}

- (NSString *)cyclePathInGraph:(NSDictionary<NSString *, TORegisteredTaskEntry *> *)graph {
    NSMutableDictionary<NSString *, NSNumber *> *state = [NSMutableDictionary dictionaryWithCapacity:graph.count];
    NSMutableArray<NSString *> *path = [NSMutableArray arrayWithCapacity:graph.count];

    for (NSString *taskID in graph.allKeys) {
        if ([state[taskID] integerValue] == 0) {
            NSString *cycle = [self dfsFindCycleFrom:taskID graph:graph state:state path:path];
            if (cycle.length > 0) {
                return cycle;
            }
        }
    }
    return @"";
}

- (NSString *)dfsFindCycleFrom:(NSString *)taskID
                         graph:(NSDictionary<NSString *, TORegisteredTaskEntry *> *)graph
                         state:(NSMutableDictionary<NSString *, NSNumber *> *)state
                          path:(NSMutableArray<NSString *> *)path {
    state[taskID] = @(1);
    [path addObject:taskID];

    TORegisteredTaskEntry *entry = graph[taskID];
    for (NSString *depID in [self dependenciesForTask:entry.task]) {
        if (!graph[depID]) { continue; }
        NSInteger depState = [state[depID] integerValue];
        if (depState == 1) {
            NSUInteger idx = [path indexOfObject:depID];
            if (idx != NSNotFound) {
                NSArray<NSString *> *cycle = [path subarrayWithRange:NSMakeRange(idx, path.count - idx)];
                return [[cycle arrayByAddingObject:depID] componentsJoinedByString:@" -> "];
            }
            return [NSString stringWithFormat:@"%@ -> %@", taskID, depID];
        }
        if (depState == 0) {
            NSString *cycle = [self dfsFindCycleFrom:depID graph:graph state:state path:path];
            if (cycle.length > 0) {
                return cycle;
            }
        }
    }

    [path removeLastObject];
    state[taskID] = @(2);
    return @"";
}

- (BOOL)runTask:(id<TOOrchestratorTask>)task
        withMode:(TOExecutionMode)mode
         context:(NSMutableDictionary *)context
           error:(NSError * _Nullable __autoreleasing *)error {

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_queue_t stateQueue = dispatch_queue_create("com.local.taskorchestrator.runtask.state", DISPATCH_QUEUE_SERIAL);

    __block BOOL success = NO;
    __block NSError *asyncError = nil;
    __block BOOL completed = NO;

    TOTaskCompletionBlock completion = ^(BOOL ok, NSError * _Nullable err) {
        __block BOOL shouldSignal = NO;
        dispatch_sync(stateQueue, ^{
            if (completed) {
                return;
            }
            completed = YES;
            success = ok;
            asyncError = err;
            shouldSignal = YES;
        });
        if (shouldSignal) {
            dispatch_semaphore_signal(sem);
        }
    };

    void (^invokeTask)(void) = ^{
        if ([task respondsToSelector:@selector(executeWithContext:completion:)]) {
            [task executeWithContext:context completion:completion];
        } else {
            NSError *syncError = nil;
            BOOL ok = [task executeWithContext:context error:&syncError];
            completion(ok, syncError);
        }
    };

    if (mode == TOExecutionModeMain) {
        if (pthread_main_np() != 0) {
            invokeTask();
        } else {
            dispatch_sync(dispatch_get_main_queue(), invokeTask);
        }
    } else {
        invokeTask();
    }

    __block BOOL isCompleted = NO;
    dispatch_sync(stateQueue, ^{
        isCompleted = completed;
    });

    if (!isCompleted) {
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.config.backgroundWaveTimeoutSeconds * NSEC_PER_SEC));
        long waitResult = dispatch_semaphore_wait(sem, timeout);
        if (waitResult != 0) {
            NSLog(@"[TaskOrchestratorKit] WARNING: task %@ timeout - completion not returned in %.2fs", task.taskIdentifier ?: @"<unknown>", self.config.backgroundWaveTimeoutSeconds);

            __block BOOL markTimeout = NO;
            dispatch_sync(stateQueue, ^{
                if (!completed) {
                    completed = YES;
                    markTimeout = YES;
                }
            });

            if (markTimeout) {
                if ([task respondsToSelector:@selector(cancel)]) {
                    [task cancel];
                }
                asyncError = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                                 code:-2200
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Task %@ execution timeout.", task.taskIdentifier ?: @"<unknown>"]}];
                success = NO;
            }
        }
    }

    if (error) {
        *error = asyncError;
    }
    return success;
}
- (BOOL)executeEntry:(TORegisteredTaskEntry *)entry
               runID:(NSString *)runID
             context:(NSMutableDictionary *)context
             ordered:(NSMutableArray<NSString *> *)ordered
             skipped:(NSMutableArray<NSString *> *)skipped
              errors:(NSMutableDictionary<NSString *, NSError *> *)errors
       acceptResults:(atomic_bool *)acceptResults
            recorded:(BOOL *)recorded {

    if (recorded) {
        *recorded = NO;
    }

    if (acceptResults != NULL && !atomic_load(acceptResults)) {
        return NO;
    }

    NSString *taskID = entry.task.taskIdentifier ?: @"<unknown>";

    __block BOOL alreadyCompleted = NO;
    dispatch_sync(self.resultQueue, ^{
        alreadyCompleted = [self.stateStore isTaskCompleted:taskID];
        if (alreadyCompleted) {
            [ordered addObject:taskID];
            [skipped addObject:taskID];
        }
    });

    if (alreadyCompleted) {
        [self safeMonitorDidSkipTask:taskID runID:runID reason:@"idempotent-state-store"];
        if (recorded) {
            *recorded = YES;
        }
        return YES;
    }

    NSMutableDictionary *taskContext = [context mutableCopy] ?: [NSMutableDictionary dictionary];

    if ([entry.task respondsToSelector:@selector(prepareWithContext:)]) {
        [entry.task prepareWithContext:taskContext];
    }

    [self safeMonitorWillStartTask:taskID runID:runID];

    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    NSError *taskError = nil;
    TOExecutionMode mode = [self executionModeForTask:entry.task];
    BOOL success = [self runTask:entry.task withMode:mode context:taskContext error:&taskError];

    if (acceptResults != NULL && !atomic_load(acceptResults)) {
        return NO;
    }

    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    double costMs = (end - start) * 1000.0;

    __block NSError *finalError = taskError;
    dispatch_sync(self.resultQueue, ^{
        [ordered addObject:taskID];

        if (success) {
            [context addEntriesFromDictionary:taskContext];
            [self.stateStore markTaskCompleted:taskID];
        } else if (finalError) {
            errors[taskID] = finalError;
        } else {
            NSError *fallbackError = [NSError errorWithDomain:@"TaskOrchestratorKit"
                                                         code:-2100
                                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Task %@ failed with unknown error", taskID]}];
            errors[taskID] = fallbackError;
            finalError = fallbackError;
        }
    });

    [self safeMonitorDidFinishTask:taskID runID:runID success:success durationMs:costMs error:finalError];

    if (recorded) {
        *recorded = YES;
    }

    return success;
}
- (NSInteger)priorityForTask:(id<TOOrchestratorTask>)task {
    if ([task respondsToSelector:@selector(priority)]) {
        return task.priority;
    }
    return 0;
}

- (NSArray<NSString *> *)dependenciesForTask:(id<TOOrchestratorTask>)task {
    if ([task respondsToSelector:@selector(dependencies)] && task.dependencies.count > 0) {
        return task.dependencies;
    }
    return @[];
}

- (TOExecutionMode)executionModeForTask:(id<TOOrchestratorTask>)task {
    if ([task respondsToSelector:@selector(executionMode)]) {
        return task.executionMode;
    }
    return TOExecutionModeSerial;
}

- (BOOL)continueOnFailureForTask:(id<TOOrchestratorTask>)task {
    if ([task respondsToSelector:@selector(continueOnFailure)]) {
        return task.continueOnFailure;
    }
    return NO;
}

#pragma mark - Safe monitor callback

- (void)safeMonitorDidStartRun:(NSString *)runID {
    @try {
        [self.monitor orchestratorDidStartRun:runID];
    } @catch (__unused NSException *exception) {
    }
}

- (void)safeMonitorWillStartTask:(NSString *)taskID runID:(NSString *)runID {
    @try {
        [self.monitor orchestratorWillStartTask:taskID runID:runID];
    } @catch (__unused NSException *exception) {
    }
}

- (void)safeMonitorDidSkipTask:(NSString *)taskID runID:(NSString *)runID reason:(NSString *)reason {
    @try {
        [self.monitor orchestratorDidSkipTask:taskID runID:runID reason:reason];
    } @catch (__unused NSException *exception) {
    }
}

- (void)safeMonitorDidFinishTask:(NSString *)taskID runID:(NSString *)runID success:(BOOL)success durationMs:(double)durationMs error:(NSError *)error {
    @try {
        [self.monitor orchestratorDidFinishTask:taskID runID:runID success:success durationMs:durationMs error:error];
    } @catch (__unused NSException *exception) {
    }
}

- (void)safeMonitorDidFinishRun:(NSString *)runID success:(BOOL)success {
    @try {
        [self.monitor orchestratorDidFinishRun:runID success:success];
    } @catch (__unused NSException *exception) {
    }
}

@end
