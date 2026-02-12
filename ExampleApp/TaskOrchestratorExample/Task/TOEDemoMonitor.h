#import <Foundation/Foundation.h>
#import "TOOrchestratorMonitor.h"

NS_ASSUME_NONNULL_BEGIN

@interface TOEDemoMonitor : NSObject <TOOrchestratorMonitor>

@property (nonatomic, copy, readonly) NSString *name;

- (instancetype)initWithName:(NSString *)name;
- (NSString *)joinedLogs;

@end

NS_ASSUME_NONNULL_END
