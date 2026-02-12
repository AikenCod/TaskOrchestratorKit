#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TOOrchestratorMonitor <NSObject>
@optional
- (void)orchestratorDidStartRun:(NSString *)runID;
- (void)orchestratorWillStartTask:(NSString *)taskIdentifier runID:(NSString *)runID;
- (void)orchestratorDidSkipTask:(NSString *)taskIdentifier runID:(NSString *)runID reason:(NSString *)reason;
- (void)orchestratorDidFinishTask:(NSString *)taskIdentifier runID:(NSString *)runID success:(BOOL)success durationMs:(double)durationMs error:(NSError * _Nullable)error;
- (void)orchestratorDidFinishRun:(NSString *)runID success:(BOOL)success;
@end

NS_ASSUME_NONNULL_END
