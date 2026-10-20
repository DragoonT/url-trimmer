#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (SettingsPages)

- (BOOL)darkTheme { return [[NSUserDefaults standardUserDefaults] objectForKey:@"dark"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"dark"] : YES; }

- (BOOL)notesOn { return [[NSUserDefaults standardUserDefaults] objectForKey:@"notes"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"notes"] : YES; }

- (UIView *)settingsPage {
    UIStackView *page = [[UIStackView alloc] init];
    page.axis = UILayoutConstraintAxisVertical;
    page.spacing = 12;
    page.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    page.layoutMarginsRelativeArrangement = YES;
    [page addArrangedSubview:[self titleRow:@"Settings"]];
    [page addArrangedSubview:[self lab:@"Theme" size:14 color:TPMuted() bold:NO]];
    UIStackView *themes = [[UIStackView alloc] initWithArrangedSubviews:@[[self actionPill:@"moon.fill" title:@"Dark" filled:[self darkTheme] action:@selector(useDark)], [self actionPill:@"sun.max.fill" title:@"Light" filled:![self darkTheme] action:@selector(useLight)]]];
    themes.spacing = 10;
    [page addArrangedSubview:themes];
    [page addArrangedSubview:[self lab:@"Notification" size:14 color:TPMuted() bold:NO]];
    [page addArrangedSubview:[self lab:@"Show the playing song on the lock screen." size:13 color:TPMuted() bold:NO]];
    [page addArrangedSubview:[self actionPill:@"bell.fill" title:([self notesOn] ? @"Notifications on" : @"Notifications off") filled:[self notesOn] action:@selector(toggleNotes)]];
    [page addArrangedSubview:[self lab:@"Update" size:14 color:TPMuted() bold:NO]];
    UIColor *ink = [self darkTheme] ? UIColor.whiteColor : UIColor.blackColor;
    [page addArrangedSubview:[self lab:[NSString stringWithFormat:@"This version %@", [self appVersion]] size:15 color:ink bold:NO]];
    [page addArrangedSubview:[self lab:(self.latestLine.length ? self.latestLine : @"Latest version") size:15 color:ink bold:NO]];
    if (self.latestIpa.length) [page addArrangedSubview:[self actionPill:@"arrow.down.circle" title:@"Update" filled:YES action:@selector(openLatestIpa)]];
    [page addArrangedSubview:[self actionPill:@"arrow.clockwise" title:@"Check for update" filled:NO action:@selector(checkForUpdate)]];
    if (!self.latestLine.length && !self.updateChecking) dispatch_async(dispatch_get_main_queue(), ^{ [self checkForUpdate]; });
    return page;
}

- (NSString *)appVersion { return @"0.1.0"; }

- (void)openLatestIpa {
    NSURL *url = [NSURL URLWithString:self.latestIpa ?: @""];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)useDark { [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"dark"]; self.view.backgroundColor = UIColor.blackColor; [self show]; }

- (void)useLight { [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"dark"]; self.view.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1]; [self show]; }

- (void)toggleNotes {
    [[NSUserDefaults standardUserDefaults] setBool:![self notesOn] forKey:@"notes"];
    if (![self notesOn]) MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = nil;
    [self show];
}

- (UIView *)aboutPage {
    UIStackView *page = [[UIStackView alloc] init];
    page.axis = UILayoutConstraintAxisVertical;
    page.spacing = 12;
    page.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    page.layoutMarginsRelativeArrangement = YES;
    [page addArrangedSubview:[self titleRow:@"About"]];
    [page addArrangedSubview:[self lab:@"Trim Playlist" size:28 color:UIColor.whiteColor bold:YES]];
    [page addArrangedSubview:[self lab:@"Play the songs you keep on this phone. Trim URL saves the file on the phone. Add it to a playlist yourself." size:15 color:TPMuted() bold:NO]];
    UIButton *github = [self tap:@"GitHub" color:UIColor.whiteColor action:@selector(openGitHub)];
    github.backgroundColor = [UIColor colorWithRed:0.2 green:0.46 blue:1 alpha:1];
    github.layer.cornerRadius = 12;
    github.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [page addArrangedSubview:github];
    return page;
}

- (void)openGitHub { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/DragoonT/url-trimmer"] options:@{} completionHandler:nil]; }

- (BOOL)version:(NSString *)remote isNewerThan:(NSString *)local {
    NSArray *left = [remote componentsSeparatedByString:@"."];
    NSArray *right = [local componentsSeparatedByString:@"."];
    NSUInteger width = MAX(left.count, right.count);
    for (NSUInteger index = 0; index < width; index++) {
        NSInteger a = index < left.count ? [left[index] integerValue] : 0;
        NSInteger b = index < right.count ? [right[index] integerValue] : 0;
        if (a != b) return a > b;
    }
    return NO;
}

- (void)checkForUpdate {
    if (self.updateChecking) return;
    self.updateChecking = YES;
    self.latestLine = @"Checking…";
    if (self.page == 7) [self show];
    NSURL *url = [NSURL URLWithString:@"https://dragoont.github.io/url-trimmer/latest.json"];
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        NSString *line = @"Latest version unavailable";
        NSString *ipa = @"";
        NSDictionary *json = (!error && data) ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *remote = json[@"version"];
        if ([remote isKindOfClass:NSString.class] && remote.length) {
            line = [NSString stringWithFormat:@"Latest version %@", remote];
            if ([self version:remote isNewerThan:[self appVersion]] && [json[@"ios"] isKindOfClass:NSString.class]) ipa = json[@"ios"];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.updateChecking = NO;
            self.latestLine = line;
            self.latestIpa = ipa;
            if (self.page == 7) [self show];
        });
    }] resume];
}
@end
