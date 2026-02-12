#import "TOEDemoTasks.h"
#import "TOBaseTask.h"

@interface TOEEnvTask : TOBaseTask
@end
@implementation TOEEnvTask
- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError **)error {
    context[@"env"] = @"prod";
    context[@"baseURL"] = @"https://api.example.com";
    return YES;
}
@end

@interface TOEFetchConfigTask : TOBaseTask
@end
@implementation TOEFetchConfigTask
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        context[@"featureA"] = @YES;
        context[@"requestTimeout"] = @15;
        if (completion) { completion(YES, nil); }
    });
}
@end

@interface TOELoginTask : TOBaseTask
@end
@implementation TOELoginTask
- (void)simulateLoginRequestWithCompletion:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (completion) { completion(@"token_demo_123", nil); }
    });
}
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion {
    [self simulateLoginRequestWithCompletion:^(NSString * _Nullable token, NSError * _Nullable requestError) {
        if (token.length > 0) {
            context[@"token"] = token;
            if (completion) { completion(YES, nil); }
            return;
        }
        NSError *finalError = requestError ?: [NSError errorWithDomain:@"TaskOrchestratorExample"
                                                                   code:1003
                                                               userInfo:@{NSLocalizedDescriptionKey: @"mock login request failed"}];
        if (completion) { completion(NO, finalError); }
    }];
}
@end

@interface TOEWarmCacheTask : TOBaseTask
@end
@implementation TOEWarmCacheTask
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        context[@"cacheWarm"] = @YES;
        if (completion) { completion(YES, nil); }
    });
}
@end

@interface TOEOptionalProbeTask : TOBaseTask
@end
@implementation TOEOptionalProbeTask
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = [NSError errorWithDomain:@"TaskOrchestratorExample"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"optional probe failed (mock)"}];
        if (completion) { completion(NO, error); }
    });
}
@end

@interface TOERouteTask : TOBaseTask
@end
@implementation TOERouteTask
- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError **)error {
    NSString *token = context[@"token"];
    NSNumber *cacheWarm = context[@"cacheWarm"];
    if (token.length > 0 && [cacheWarm boolValue]) {
        context[@"initialRoute"] = @"home";
        return YES;
    }

    if (error) {
        *error = [NSError errorWithDomain:@"TaskOrchestratorExample"
                                     code:1002
                                 userInfo:@{NSLocalizedDescriptionKey: @"route prerequisites missing"}];
    }
    return NO;
}
@end

@interface TOEAnalyticsTask : TOBaseTask
@end
@implementation TOEAnalyticsTask
- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError **)error {
    context[@"analyticsBoot"] = @"done";
    return YES;
}
@end

@interface TOECycleATask : TOBaseTask
@end
@implementation TOECycleATask
- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError **)error {
    context[@"cycleA"] = @"A";
    return YES;
}
@end

@interface TOECycleBTask : TOBaseTask
@end
@implementation TOECycleBTask
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion {
    context[@"cycleB"] = @"B";
    if (completion) { completion(YES, nil); }
}
@end

@interface TOECycleCTask : TOBaseTask
@end
@implementation TOECycleCTask
- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError **)error {
    context[@"cycleC"] = @"C";
    return YES;
}
@end

@implementation TOEDemoTaskBuilder

+ (void)registerNormalTasksOnOrchestrator:(TOOrchestrator *)orchestrator {
    TOEEnvTask *env = [[TOEEnvTask alloc] initWithIdentifier:@"01_env_prepare"];
    env.priority = 100;

    TOEFetchConfigTask *remoteConfig = [[TOEFetchConfigTask alloc] initWithIdentifier:@"02_fetch_remote_config"];
    remoteConfig.priority = 80;
    remoteConfig.dependencies = @[@"01_env_prepare"];
    remoteConfig.executionMode = TOExecutionModeConcurrent;

    TOELoginTask *login = [[TOELoginTask alloc] initWithIdentifier:@"03_login"];
    login.priority = 70;
    login.dependencies = @[@"02_fetch_remote_config"];
    login.executionMode = TOExecutionModeConcurrent;

    TOEWarmCacheTask *warmCache = [[TOEWarmCacheTask alloc] initWithIdentifier:@"04_warm_cache"];
    warmCache.priority = 60;
    warmCache.dependencies = @[@"02_fetch_remote_config"];
    warmCache.executionMode = TOExecutionModeConcurrent;

    TOEOptionalProbeTask *probe = [[TOEOptionalProbeTask alloc] initWithIdentifier:@"05_optional_probe"];
    probe.priority = 50;
    probe.dependencies = @[@"02_fetch_remote_config"];
    probe.executionMode = TOExecutionModeConcurrent;
    probe.continueOnFailure = YES;

    TOERouteTask *route = [[TOERouteTask alloc] initWithIdentifier:@"06_route_main_thread"];
    route.priority = 40;
    route.dependencies = @[@"03_login", @"04_warm_cache"];
    route.executionMode = TOExecutionModeMain;

    TOEAnalyticsTask *analytics = [[TOEAnalyticsTask alloc] initWithIdentifier:@"07_boot_analytics"];
    analytics.priority = 30;
    analytics.dependencies = @[@"06_route_main_thread"];

    [orchestrator registerTask:env];
    [orchestrator registerTask:remoteConfig];
    [orchestrator registerTask:login];
    [orchestrator registerTask:warmCache];
    [orchestrator registerTask:probe];
    [orchestrator registerTask:route];
    [orchestrator registerTask:analytics];
}

+ (void)registerCycleTasksOnOrchestrator:(TOOrchestrator *)orchestrator {
    TOECycleATask *a = [[TOECycleATask alloc] initWithIdentifier:@"cycle_A"];
    a.dependencies = @[@"cycle_C"];

    TOECycleBTask *b = [[TOECycleBTask alloc] initWithIdentifier:@"cycle_B"];
    b.dependencies = @[@"cycle_A"];

    TOECycleCTask *c = [[TOECycleCTask alloc] initWithIdentifier:@"cycle_C"];
    c.dependencies = @[@"cycle_B"];

    [orchestrator registerTask:a];
    [orchestrator registerTask:b];
    [orchestrator registerTask:c];
}

+ (NSDictionary<NSString *,NSString *> *)normalTaskExecutionTypes {
    return @{
        @"01_env_prepare": @"sync",
        @"02_fetch_remote_config": @"async",
        @"03_login": @"async",
        @"04_warm_cache": @"async",
        @"05_optional_probe": @"async",
        @"06_route_main_thread": @"sync",
        @"07_boot_analytics": @"sync"
    };
}

+ (NSDictionary<NSString *,NSString *> *)cycleTaskExecutionTypes {
    return @{
        @"cycle_A": @"sync",
        @"cycle_B": @"async",
        @"cycle_C": @"sync"
    };
}

@end
