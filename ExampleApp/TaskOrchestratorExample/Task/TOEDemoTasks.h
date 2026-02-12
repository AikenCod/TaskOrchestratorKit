#import <Foundation/Foundation.h>
#import "TOOrchestrator.h"

NS_ASSUME_NONNULL_BEGIN

@interface TOEDemoTaskBuilder : NSObject

+ (void)registerNormalTasksOnOrchestrator:(TOOrchestrator *)orchestrator;
+ (void)registerCycleTasksOnOrchestrator:(TOOrchestrator *)orchestrator;
+ (NSDictionary<NSString *, NSString *> *)normalTaskExecutionTypes;
+ (NSDictionary<NSString *, NSString *> *)cycleTaskExecutionTypes;

@end

NS_ASSUME_NONNULL_END
