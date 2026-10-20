#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (Navigation)

- (UIView *)titleRow:(NSString *)title {
    UIButton *menu = [self tap:@"☰" color:UIColor.whiteColor action:@selector(openNav)];
    menu.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightRegular];
    [menu.widthAnchor constraintEqualToConstant:40].active = YES;
    [menu.heightAnchor constraintEqualToConstant:40].active = YES;
    UILabel *name = [self lab:title size:20 color:UIColor.whiteColor bold:YES];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[menu, name]];
    row.spacing = 8;
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (void)installNav {
    self.navScrim = [[UIView alloc] init];
    self.navScrim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.navScrim.hidden = YES;
    self.navScrim.translatesAutoresizingMaskIntoConstraints = NO;
    [self.navScrim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeNav)]];
    self.navPanel = [[UIView alloc] init];
    self.navPanel.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    self.navPanel.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *playlist = [self tap:@"Trim Playlist" color:UIColor.whiteColor action:@selector(navPlaylist)];
    playlist.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    playlist.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    UIButton *url = [self tap:@"Trim URL" color:UIColor.whiteColor action:@selector(navUrl)];
    url.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    url.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    UIButton *about = [self tap:@"About" color:UIColor.whiteColor action:@selector(navAbout)];
    about.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    about.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    UIButton *settings = [self tap:@"Settings" color:UIColor.whiteColor action:@selector(navSettings)];
    settings.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    settings.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[[self lab:@"Library" size:13 color:TPMuted() bold:NO], playlist, url, settings, about]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.navPanel addSubview:stack];
    [self.view addSubview:self.navScrim];
    [self.view addSubview:self.navPanel];
    self.navLeading = [self.navPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-280];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.navScrim.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.navScrim.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.navScrim.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.navScrim.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.navPanel.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.navPanel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.navPanel.widthAnchor constraintEqualToConstant:280],
        self.navLeading,
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:28],
        [stack.leadingAnchor constraintEqualToAnchor:self.navPanel.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:self.navPanel.trailingAnchor constant:-18],
    ]];
}

- (void)openNav {
    self.navScrim.hidden = NO;
    self.navScrim.alpha = 0;
    self.navLeading.constant = 0;
    [UIView animateWithDuration:0.22 animations:^{ self.navScrim.alpha = 1; [self.view layoutIfNeeded]; }];
}

- (void)closeNav {
    self.navLeading.constant = -280;
    [UIView animateWithDuration:0.18 animations:^{ self.navScrim.alpha = 0; [self.view layoutIfNeeded]; } completion:^(__unused BOOL done) { self.navScrim.hidden = YES; }];
}

- (void)navPlaylist { [self closeNav]; [self go:0]; }

- (void)navUrl { [self closeNav]; [self go:4]; }

- (void)navSettings { [self closeNav]; [self go:7]; }

- (void)navAbout { [self closeNav]; [self go:8]; }

- (void)openPlayer { if (self.currentSong) [self push:2]; }
@end
