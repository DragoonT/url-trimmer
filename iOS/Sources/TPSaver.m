#import "TPSaver.h"

@implementation TPSaver
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    (void)session; (void)task;
    self.expected = response.expectedContentLength;
    self.contentType = response.MIMEType ?: @"";
    if ([response isKindOfClass:NSHTTPURLResponse.class]) self.status = [(NSHTTPURLResponse *)response statusCode];
    completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    (void)session; (void)task;
    [self.handle writeData:data];
    self.got += (long long)data.length;
    if (self.expected > 0 && self.progress) {
        float fraction = (float)self.got / (float)self.expected;
        dispatch_async(dispatch_get_main_queue(), ^{ self.progress(fraction); });
    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    (void)session; (void)task;
    self.error = error;
    dispatch_semaphore_signal(self.gate);
}
@end
