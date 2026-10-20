#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (OnlinePage)

- (UIView *)onlinePage {
    UIStackView *form = [[UIStackView alloc] init];
    form.axis = UILayoutConstraintAxisVertical;
    form.spacing = 8;
    form.layoutMargins = UIEdgeInsetsMake(16, 16, 28, 16);
    form.layoutMarginsRelativeArrangement = YES;
    [form addArrangedSubview:[self titleRow:@"Online"]];
    [form addArrangedSubview:[self tap:@"Back to playlist" color:UIColor.whiteColor action:@selector(pop)]];
    [form addArrangedSubview:[self lab:@"This plays with internet data. The video stays online and is not saved on this phone." size:13 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self lab:@"Add" size:13 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self menuField:(self.onlineType ? @"Entire playlist" : @"Single video") action:@selector(pickOnlineType)]];
    [form addArrangedSubview:[self lab:@"Video URL" size:13 color:TPMuted() bold:NO]];
    UITextField *url = [self input:@"https://…"];
    url.tag = 80;
    url.text = self.onlineDraft;
    url.keyboardType = UIKeyboardTypeURL;
    [url addTarget:self action:@selector(onlineDraftChanged:) forControlEvents:UIControlEventEditingChanged];
    [form addArrangedSubview:url];
    [form addArrangedSubview:[self lab:@"Authentication" size:13 color:TPMuted() bold:NO]];
    NSArray *auth = @[@"Cookie file", @"Platform account", @"No authentication"];
    [form addArrangedSubview:[self menuField:auth[self.downloadAuth] action:@selector(pickAuth)]];
    if (self.downloadAuth == 0) {
        [form addArrangedSubview:[self lab:@"Cookies" size:13 color:TPMuted() bold:NO]];
        [form addArrangedSubview:[self menuField:(self.cookieName.length ? self.cookieName : @"No cookies") action:@selector(pickCookie)]];
        [form addArrangedSubview:[self tap:@"Create new" color:UIColor.whiteColor action:@selector(createCookie)]];
    }
    if (self.downloadAuth == 1) {
        NSArray *platforms = @[@"YouTube", @"Facebook", @"Instagram", @"X / Twitter", @"TikTok", @"Twitch"];
        [form addArrangedSubview:[self lab:@"Platform" size:13 color:TPMuted() bold:NO]];
        [form addArrangedSubview:[self menuField:platforms[self.downloadPlatform] action:@selector(pickPlatform)]];
        BOOL connected = [[NSUserDefaults standardUserDefaults] boolForKey:[self platformKey]];
        [form addArrangedSubview:[self lab:(connected ? @"Signed in on this iPhone." : @"Not signed in.") size:13 color:TPMuted() bold:NO]];
        [form addArrangedSubview:[self tap:(connected ? @"Open sign-in again" : @"Sign in") color:UIColor.whiteColor action:@selector(openSignIn)]];
    }
    [form addArrangedSubview:[self lab:@"Format" size:13 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self menuField:(self.onlineFormat ? @"Audio only" : @"MP4 video") action:@selector(pickOnlineFormat)]];
    [form addArrangedSubview:[self tap:@"Load" color:UIColor.whiteColor action:@selector(loadOnline)]];
    if (self.onlineType == 0 && self.onlineChoices.count) {
        [form addArrangedSubview:[self lab:@"Choose the videos to add." size:13 color:TPMuted() bold:NO]];
        [self.onlineChoices enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger index, __unused BOOL *stop) {
            BOOL picked = [self.onlinePicked containsObject:@(index)];
            NSString *title = [NSString stringWithFormat:@"%@  %@", picked ? @"✓" : @"○", entry[@"title"] ?: @""];
            UIButton *row = [self tap:title color:UIColor.whiteColor action:@selector(toggleOnline:)];
            row.tag = (NSInteger)index;
            row.accessibilityIdentifier = @"choice";
            row.backgroundColor = picked ? [UIColor colorWithWhite:0.22 alpha:1] : [UIColor colorWithWhite:0.14 alpha:1];
            row.layer.cornerRadius = 10;
            row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            row.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
            row.titleLabel.numberOfLines = 2;
            [form addArrangedSubview:row];
        }];
        [form addArrangedSubview:[self tap:@"Add selected" color:UIColor.whiteColor action:@selector(addSelectedOnline)]];
    }
    return [self fill:form];
}

- (void)pickOnlineType { [self choose:@"Add" options:@[@"Single video", @"Entire playlist"] done:^(NSInteger index, __unused NSString *text) { self.onlineType = index; [self.onlineChoices removeAllObjects]; [self.onlinePicked removeAllObjects]; [self show]; }]; }

- (void)pickOnlineFormat { [self choose:@"Format" options:@[@"MP4 video", @"Audio only"] done:^(NSInteger index, __unused NSString *text) { self.onlineFormat = index; [self show]; }]; }

- (void)onlineDraftChanged:(UITextField *)field { self.onlineDraft = field.text ?: @""; }

- (void)loadOnline {
    UITextField *field = (UITextField *)[self.view viewWithTag:80];
    if ([field isKindOfClass:UITextField.class]) self.onlineDraft = field.text ?: @"";
    NSString *entered = self.onlineDraft ?: @"";
    if (![entered hasPrefix:@"http://"] && ![entered hasPrefix:@"https://"]) { [self toast:@"Enter a video or playlist URL"]; return; }
    if (self.streamBusy) return;
    self.streamBusy = YES;
    [self toast:@"Loading…"];
    NSInteger type = self.onlineType;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            NSString *cookie = [self authCookieForPage:entered];
            NSArray *found = [self catalog:entered cookie:cookie];
            BOOL playlist = [entered containsString:@"list="];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.streamBusy = NO;
                if (!playlist || type == 1) [self addOnline:found];
                else {
                    [self.onlineChoices removeAllObjects];
                    [self.onlineChoices addObjectsFromArray:found];
                    [self.onlinePicked removeAllObjects];
                    [self show];
                }
            });
        } @catch (NSException *ex) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.streamBusy = NO;
                [self toast:ex.reason ?: @"Couldn't read that URL"];
            });
        }
    });
}

- (void)toggleOnline:(UIButton *)sender {
    NSNumber *index = @(sender.tag);
    if ([self.onlinePicked containsObject:index]) [self.onlinePicked removeObject:index];
    else [self.onlinePicked addObject:index];
    [self paintChoicesFrom:sender choices:self.onlineChoices picked:self.onlinePicked];
}

- (void)paintChoicesFrom:(UIView *)row choices:(NSArray *)choices picked:(NSSet *)picked {
    UIStackView *stack = (UIStackView *)row.superview;
    if (![stack isKindOfClass:UIStackView.class]) return;
    for (UIView *child in stack.arrangedSubviews) {
        if (![child isKindOfClass:UIButton.class] || !child.accessibilityIdentifier.length) continue;
        UIButton *button = (UIButton *)child;
        NSInteger index = button.tag;
        if (index < 0 || index >= (NSInteger)choices.count) continue;
        BOOL on = [picked containsObject:@(index)];
        NSString *title = choices[(NSUInteger)index][@"title"] ?: @"";
        [button setTitle:[NSString stringWithFormat:@"%@  %@", on ? @"✓" : @"○", title] forState:UIControlStateNormal];
        button.backgroundColor = on ? [UIColor colorWithWhite:0.22 alpha:1] : [UIColor colorWithWhite:0.14 alpha:1];
    }
}

- (void)addSelectedOnline {
    NSMutableArray *chosen = [NSMutableArray array];
    NSArray *order = [self.onlinePicked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *index in order) {
        if (index.integerValue >= 0 && index.integerValue < (NSInteger)self.onlineChoices.count) [chosen addObject:self.onlineChoices[(NSUInteger)index.integerValue]];
    }
    if (!chosen.count) { [self toast:@"Select a video"]; return; }
    [self addOnline:chosen];
}

- (void)addOnline:(NSArray *)entries {
    BOOL video = self.onlineFormat == 0;
    for (NSDictionary *entry in entries) {
        [self.tracks addObject:[@{@"title": entry[@"title"] ?: @"Online", @"uri": entry[@"url"] ?: @"", @"kind": @"online", @"video": @(video)} mutableCopy]];
    }
    [self saveLibrary];
    [self.onlineChoices removeAllObjects];
    [self.onlinePicked removeAllObjects];
    [self toast:[NSString stringWithFormat:@"Added %lu", (unsigned long)entries.count]];
    [self pop];
}
@end
