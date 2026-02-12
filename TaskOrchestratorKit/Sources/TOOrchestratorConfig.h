#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TOOrchestratorConfig : NSObject

@property (nonatomic, assign) NSInteger maxBackgroundConcurrency;
@property (nonatomic, assign) BOOL strictDependencyCheck;
@property (nonatomic, assign) NSTimeInterval backgroundWaveTimeoutSeconds;

@end

NS_ASSUME_NONNULL_END
