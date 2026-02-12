#import "TOMemoryStateStore.h"

static const void *kTOStateStoreQueueKey = &kTOStateStoreQueueKey;

@interface TOMemoryStateStore ()
@property (nonatomic, strong) NSMutableSet<NSString *> *completed;
@property (nonatomic, strong) dispatch_queue_t lockQueue;
@end

@implementation TOMemoryStateStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _completed = [NSMutableSet set];
        _lockQueue = dispatch_queue_create("com.local.taskorchestrator.state", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_lockQueue, kTOStateStoreQueueKey, (void *)kTOStateStoreQueueKey, NULL);
    }
    return self;
}

- (BOOL)isTaskCompleted:(NSString *)taskIdentifier {
    if (taskIdentifier.length == 0) { return NO; }

    if (dispatch_get_specific(kTOStateStoreQueueKey)) {
        return [self.completed containsObject:taskIdentifier];
    }

    __block BOOL done = NO;
    dispatch_sync(self.lockQueue, ^{
        done = [self.completed containsObject:taskIdentifier];
    });
    return done;
}

- (void)markTaskCompleted:(NSString *)taskIdentifier {
    if (taskIdentifier.length == 0) { return; }

    if (dispatch_get_specific(kTOStateStoreQueueKey)) {
        [self.completed addObject:taskIdentifier];
        return;
    }

    dispatch_sync(self.lockQueue, ^{
        [self.completed addObject:taskIdentifier];
    });
}

- (void)resetAll {
    if (dispatch_get_specific(kTOStateStoreQueueKey)) {
        [self.completed removeAllObjects];
        return;
    }

    dispatch_sync(self.lockQueue, ^{
        [self.completed removeAllObjects];
    });
}

@end
