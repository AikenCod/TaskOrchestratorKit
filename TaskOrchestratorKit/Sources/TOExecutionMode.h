#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TOExecutionMode) {
    /// 串行执行 - 在当前线程同步执行，多个串行任务逐个运行
    TOExecutionModeSerial = 0,
    /// 主线程执行 - 强制在主线程同步执行，逐个运行
    TOExecutionModeMain = 1,
    /// 并发执行 - 在当前线程启动，但允许并发执行（多个任务同时运行）
    TOExecutionModeConcurrent = 2,
};

NS_ASSUME_NONNULL_END
