#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TOStateStore <NSObject>
- (BOOL)isTaskCompleted:(NSString *)taskIdentifier;
- (void)markTaskCompleted:(NSString *)taskIdentifier;
- (void)resetAll;
@end

NS_ASSUME_NONNULL_END
