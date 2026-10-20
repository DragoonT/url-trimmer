#import "TPRecord.h"

@implementation TPRecord
- (void)drawRect:(CGRect)rect {
    CGFloat c = MIN(rect.size.width, rect.size.height) / 2;
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    [[UIColor colorWithWhite:0.22 alpha:1] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:8] fill];
    [[UIColor colorWithWhite:0.12 alpha:1] setFill];
    [[UIBezierPath bezierPathWithArcCenter:center radius:c * 0.72 startAngle:0 endAngle:M_PI * 2 clockwise:YES] fill];
    [[UIColor colorWithWhite:0.32 alpha:1] setFill];
    [[UIBezierPath bezierPathWithArcCenter:center radius:c * 0.28 startAngle:0 endAngle:M_PI * 2 clockwise:YES] fill];
    [[UIColor colorWithWhite:0.08 alpha:1] setFill];
    [[UIBezierPath bezierPathWithArcCenter:center radius:c * 0.08 startAngle:0 endAngle:M_PI * 2 clockwise:YES] fill];
}
@end
