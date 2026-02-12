#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TOOrchestratorResult : NSObject
@property (nonatomic, copy) NSString *runID;
@property (nonatomic, assign) BOOL success;
@property (nonatomic, copy) NSArray<NSString *> *orderedTaskIDs;
@property (nonatomic, copy) NSArray<NSString *> *skippedTaskIDs;
@property (nonatomic, copy, nullable) NSString *failedTaskID;
@property (nonatomic, strong) NSDictionary<NSString *, NSError *> *errorsByTaskID;
@end

NS_ASSUME_NONNULL_END
