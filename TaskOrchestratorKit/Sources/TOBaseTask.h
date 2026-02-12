#import <Foundation/Foundation.h>
#import "TOOrchestratorTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface TOBaseTask : NSObject <TOOrchestratorTask>

@property (nonatomic, copy) NSString *taskIdentifier;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, copy) NSArray<NSString *> *dependencies;
@property (nonatomic, assign) TOExecutionMode executionMode;
@property (nonatomic, assign) BOOL continueOnFailure;

- (instancetype)initWithIdentifier:(NSString *)identifier;

/// 子类可覆盖异步接口，无需自行写 semaphore。
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
