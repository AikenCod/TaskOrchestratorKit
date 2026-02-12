#import <Foundation/Foundation.h>
#import "TOOrchestratorTask.h"
#import "TOStateStore.h"
#import "TOOrchestratorConfig.h"
#import "TOOrchestratorMonitor.h"
#import "TOOrchestratorResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface TOOrchestrator : NSObject

@property (nonatomic, strong) id<TOStateStore> stateStore;
@property (nonatomic, weak, nullable) id<TOOrchestratorMonitor> monitor;
@property (nonatomic, strong, readonly) TOOrchestratorConfig *config;

- (instancetype)initWithConfig:(nullable TOOrchestratorConfig *)config;
- (void)registerTask:(id<TOOrchestratorTask>)task;
- (void)clearTasks;
- (TOOrchestratorResult *)runWithContext:(nullable NSMutableDictionary *)context;

@end

NS_ASSUME_NONNULL_END
