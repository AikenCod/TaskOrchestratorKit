#import <Foundation/Foundation.h>
#import "TOExecutionMode.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^TOTaskCompletionBlock)(BOOL success, NSError * _Nullable error);

@protocol TOOrchestratorTask <NSObject>

@property (nonatomic, copy, readonly) NSString *taskIdentifier;

/// 同步任务
- (BOOL)executeWithContext:(NSMutableDictionary *)context error:(NSError * _Nullable * _Nullable)error;

@optional
/// 异步任务
- (void)executeWithContext:(NSMutableDictionary *)context completion:(TOTaskCompletionBlock)completion;

- (void)cancel;

@property (nonatomic, assign, readonly) NSInteger priority;
@property (nonatomic, copy, readonly) NSArray<NSString *> *dependencies;
@property (nonatomic, assign, readonly) TOExecutionMode executionMode;
@property (nonatomic, assign, readonly) BOOL continueOnFailure;
- (void)prepareWithContext:(NSMutableDictionary *)context;

@end

NS_ASSUME_NONNULL_END
