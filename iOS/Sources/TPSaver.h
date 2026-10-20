#import <Foundation/Foundation.h>

@interface TPSaver : NSObject <NSURLSessionDataDelegate>
@property(nonatomic, strong) NSFileHandle *handle;
@property(nonatomic, assign) long long expected;
@property(nonatomic, assign) long long got;
@property(nonatomic, copy) void (^progress)(float);
@property(nonatomic, strong) dispatch_semaphore_t gate;
@property(nonatomic, assign) NSInteger status;
@property(nonatomic, copy) NSString *contentType;
@property(nonatomic, strong) NSError *error;
@end
