#import "TOOrchestratorConfig.h"

@implementation TOOrchestratorConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _maxBackgroundConcurrency = 4;
        _strictDependencyCheck = YES;
        _backgroundWaveTimeoutSeconds = 30.0;
    }
    return self;
}

- (void)setMaxBackgroundConcurrency:(NSInteger)maxBackgroundConcurrency {
    _maxBackgroundConcurrency = MAX(1, MIN(maxBackgroundConcurrency, 16));
}

- (void)setBackgroundWaveTimeoutSeconds:(NSTimeInterval)backgroundWaveTimeoutSeconds {
    if (backgroundWaveTimeoutSeconds <= 0) {
        _backgroundWaveTimeoutSeconds = 30.0;
    } else {
        _backgroundWaveTimeoutSeconds = MIN(backgroundWaveTimeoutSeconds, 300.0);
    }
}

@end
