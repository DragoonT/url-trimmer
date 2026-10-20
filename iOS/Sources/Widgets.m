#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (Widgets)

- (UILabel *)lab:(NSString *)text size:(CGFloat)size color:(UIColor *)color bold:(BOOL)bold {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    CGFloat white = 0, alpha = 0;
    if (![self darkTheme] && [color getWhite:&white alpha:&alpha] && white > 0.9) color = UIColor.blackColor;
    label.textColor = color;
    label.numberOfLines = 2;
    label.font = [UIFont systemFontOfSize:size weight:bold ? UIFontWeightBold : UIFontWeightRegular];
    return label;
}

- (UIButton *)actionPill:(NSString *)symbol title:(NSString *)title filled:(BOOL)filled action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    [button setTitle:[@"  " stringByAppendingString:title] forState:UIControlStateNormal];
    button.tintColor = filled ? UIColor.blackColor : ([self darkTheme] ? UIColor.whiteColor : UIColor.blackColor);
    [button setTitleColor:button.tintColor forState:UIControlStateNormal];
    button.backgroundColor = filled ? UIColor.whiteColor : UIColor.clearColor;
    button.layer.cornerRadius = 22;
    button.layer.borderWidth = filled ? 0 : 1;
    button.layer.borderColor = ([self darkTheme] ? UIColor.whiteColor : UIColor.blackColor).CGColor;
    button.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 18);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)tap:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)iconButton:(NSString *)symbol point:(CGFloat)point action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:point weight:UIImageSymbolWeightRegular];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    button.tintColor = [self darkTheme] ? UIColor.whiteColor : UIColor.blackColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    NSLayoutConstraint *width = [button.widthAnchor constraintEqualToConstant:point + 26];
    width.priority = UILayoutPriorityDefaultHigh;
    width.active = YES;
    [button.heightAnchor constraintEqualToConstant:point + 26].active = YES;
    return button;
}

- (UITextField *)input:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.textColor = [self darkTheme] ? UIColor.whiteColor : UIColor.blackColor;
    field.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1];
    field.layer.cornerRadius = 10;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [field.heightAnchor constraintEqualToConstant:44].active = YES;
    return field;
}

- (UIButton *)menuField:(NSString *)title action:(SEL)action {
    UIButton *button = [self tap:[NSString stringWithFormat:@"%@   ▾", title] color:UIColor.whiteColor action:action];
    button.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1];
    button.layer.cornerRadius = 10;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    return button;
}

- (void)choose:(NSString *)title options:(NSArray<NSString *> *)options done:(void (^)(NSInteger index, NSString *text))done {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [options enumerateObjectsUsingBlock:^(NSString *item, NSUInteger index, __unused BOOL *stop) {
        [sheet addAction:[UIAlertAction actionWithTitle:item style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { done((NSInteger)index, item); }]];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (UIView *)fill:(UIView *)child {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:child];
    [NSLayoutConstraint activateConstraints:@[[child.topAnchor constraintEqualToAnchor:scroll.topAnchor], [child.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor], [child.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor], [child.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor], [child.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]]];
    return scroll;
}

- (void)toast:(NSString *)message {
    UILabel *label = [self lab:message size:14 color:UIColor.whiteColor bold:YES];
    label.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 10;
    label.clipsToBounds = YES;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[[label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor], [label.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-80], [label.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-40], [label.heightAnchor constraintGreaterThanOrEqualToConstant:36]]];
    [UIView animateWithDuration:0.25 delay:1.8 options:0 animations:^{ label.alpha = 0; } completion:^(__unused BOOL done) { [label removeFromSuperview]; }];
}
@end
