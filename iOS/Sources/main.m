#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <MediaPlayer/MediaPlayer.h>

static UIColor *TPMuted(void) { return [UIColor colorWithWhite:0.72 alpha:1]; }

static NSString *TPTime(double seconds) {
    if (!isfinite(seconds) || seconds < 0) seconds = 0;
    int total = (int)seconds;
    return [NSString stringWithFormat:@"%d:%02d", total / 60, total % 60];
}

@interface TPRecord : UIView
@end
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

@interface TrimPlaylistViewController : UIViewController <UIDocumentPickerDelegate, UITextFieldDelegate, WKNavigationDelegate, UIGestureRecognizerDelegate>
@property(nonatomic, strong) NSMutableArray<NSMutableDictionary *> *playlists;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *history;
@property(nonatomic, assign) NSInteger selected;
@property(nonatomic, assign) NSInteger currentTrack;
@property(nonatomic, assign) NSInteger repeatMode;
@property(nonatomic, assign) BOOL shuffle;
@property(nonatomic, assign) BOOL seeking;
@property(nonatomic, assign) BOOL fullscreen;
@property(nonatomic, assign) NSInteger downloadType;
@property(nonatomic, assign) NSInteger downloadMode;
@property(nonatomic, assign) NSInteger downloadFormat;
@property(nonatomic, assign) NSInteger downloadAuth;
@property(nonatomic, assign) NSInteger downloadPlatform;
@property(nonatomic, assign) NSInteger downloadQuality;
@property(nonatomic, assign) NSInteger downloadAudio;
@property(nonatomic, assign) BOOL downloadBusy;
@property(nonatomic, assign) BOOL streamBusy;
@property(nonatomic, assign) NSInteger onlineType;
@property(nonatomic, assign) NSInteger onlineFormat;
@property(nonatomic, copy) NSString *onlineDraft;
@property(nonatomic, strong) NSMutableArray *onlineChoices;
@property(nonatomic, strong) NSMutableSet *onlinePicked;
@property(nonatomic, strong) NSMutableArray *downloadChoices;
@property(nonatomic, strong) NSMutableSet *downloadPicked;
@property(nonatomic, copy) NSString *downloadChoiceUrl;
@property(nonatomic, strong) NSMutableArray *savedFiles;
@property(nonatomic, strong) NSMutableSet *savedPicked;
@property(nonatomic, assign) BOOL downloadCleared;
@property(nonatomic, assign) float downloadFraction;
@property(nonatomic, copy) NSString *cookieName;
@property(nonatomic, copy) NSString *latestLine;
@property(nonatomic, copy) NSString *latestIpa;
@property(nonatomic, assign) BOOL updateChecking;
@property(nonatomic, copy) NSString *draftUrl;
@property(nonatomic, copy) NSString *draftName;
@property(nonatomic, copy) NSString *draftStart;
@property(nonatomic, copy) NSString *draftEnd;
@property(nonatomic, copy) NSString *draftVolume;
@property(nonatomic, copy) NSString *qualityName;
@property(nonatomic, copy) NSString *pickKind;
@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerItem *observed;
@property(nonatomic, strong) id tick;
@property(nonatomic, strong) UIView *content;
@property(nonatomic, strong) UIStackView *mini;
@property(nonatomic, strong) UILabel *miniTitle;
@property(nonatomic, strong) UIButton *miniPlay;
@property(nonatomic, strong) UISlider *seekSlider;
@property(nonatomic, strong) UILabel *timeLabel;
@property(nonatomic, strong) UILabel *totalLabel;
@property(nonatomic, strong) UIButton *playButton;
@property(nonatomic, strong) UITextView *editor;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, copy) NSString *editorPath;
@property(nonatomic, assign) NSInteger motion;
@property(nonatomic, assign) BOOL metaQueued;
@property(nonatomic, strong) UILabel *signInStatus;
@property(nonatomic, strong) UIView *navScrim;
@property(nonatomic, strong) UIView *navPanel;
@property(nonatomic, strong) NSLayoutConstraint *navLeading;
@property(nonatomic, strong) UIView *downloadBar;
@property(nonatomic, strong) UIView *downloadTrack;
@property(nonatomic, strong) UIView *downloadFill;
@property(nonatomic, strong) UILabel *downloadLabel;
@property(nonatomic, strong) UIButton *downloadClear;
@property(nonatomic, strong) NSLayoutConstraint *fillWidth;
@property(nonatomic, strong) NSLayoutConstraint *downloadBarHeight;
@end

@implementation TrimPlaylistViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.history = [NSMutableArray arrayWithObject:@0];
    self.onlineChoices = [NSMutableArray array];
    self.onlinePicked = [NSMutableSet set];
    self.downloadChoices = [NSMutableArray array];
    self.downloadPicked = [NSMutableSet set];
    self.downloadChoiceUrl = @"";
    self.savedFiles = [NSMutableArray array];
    self.savedPicked = [NSMutableSet set];
    self.currentTrack = -1;
    self.qualityName = @"Source";
    [self loadTrim];
    [self loadLibrary];
    self.player = [[AVPlayer alloc] init];
    self.content = [[UIView alloc] init];
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    self.mini = [[UIStackView alloc] init];
    self.mini.axis = UILayoutConstraintAxisHorizontal;
    self.mini.alignment = UIStackViewAlignmentCenter;
    self.mini.spacing = 8;
    self.mini.layoutMargins = UIEdgeInsetsMake(8, 10, 8, 10);
    self.mini.layoutMarginsRelativeArrangement = YES;
    self.mini.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
    self.mini.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPlayer)];
    [self.mini addGestureRecognizer:tap];
    self.downloadBar = [[UIView alloc] init];
    self.downloadBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    self.downloadLabel = [[UILabel alloc] init];
    self.downloadLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.downloadLabel.textColor = TPMuted();
    self.downloadLabel.numberOfLines = 2;
    self.downloadClear = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.downloadClear setTitle:@"Clear" forState:UIControlStateNormal];
    self.downloadClear.translatesAutoresizingMaskIntoConstraints = NO;
    [self.downloadClear addTarget:self action:@selector(clearDownload) forControlEvents:UIControlEventTouchUpInside];
    self.downloadTrack = [[UIView alloc] init];
    self.downloadTrack.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadTrack.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
    self.downloadFill = [[UIView alloc] init];
    self.downloadFill.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadFill.backgroundColor = [UIColor colorWithRed:0.2 green:0.46 blue:1 alpha:1];
    [self.downloadTrack addSubview:self.downloadFill];
    [self.downloadBar addSubview:self.downloadLabel];
    [self.downloadBar addSubview:self.downloadClear];
    [self.downloadBar addSubview:self.downloadTrack];
    self.fillWidth = [self.downloadFill.widthAnchor constraintEqualToConstant:0];
    self.downloadBarHeight = [self.downloadBar.heightAnchor constraintEqualToConstant:0];
    [self.view addSubview:self.content];
    [self.view addSubview:self.downloadBar];
    [self.view addSubview:self.mini];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.content.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.content.bottomAnchor constraintEqualToAnchor:self.downloadBar.topAnchor],
        [self.downloadBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.downloadBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.downloadBar.bottomAnchor constraintEqualToAnchor:self.mini.topAnchor],
        self.downloadBarHeight,
        [self.downloadLabel.topAnchor constraintEqualToAnchor:self.downloadBar.topAnchor constant:8],
        [self.downloadLabel.leadingAnchor constraintEqualToAnchor:self.downloadBar.leadingAnchor constant:16],
        [self.downloadLabel.trailingAnchor constraintEqualToAnchor:self.downloadClear.leadingAnchor constant:-8],
        [self.downloadClear.centerYAnchor constraintEqualToAnchor:self.downloadLabel.centerYAnchor],
        [self.downloadClear.trailingAnchor constraintEqualToAnchor:self.downloadBar.trailingAnchor constant:-16],
        [self.downloadTrack.topAnchor constraintEqualToAnchor:self.downloadLabel.bottomAnchor constant:6],
        [self.downloadTrack.leadingAnchor constraintEqualToAnchor:self.downloadBar.leadingAnchor constant:16],
        [self.downloadTrack.trailingAnchor constraintEqualToAnchor:self.downloadBar.trailingAnchor constant:-16],
        [self.downloadTrack.heightAnchor constraintEqualToConstant:6],
        [self.downloadFill.leadingAnchor constraintEqualToAnchor:self.downloadTrack.leadingAnchor],
        [self.downloadFill.topAnchor constraintEqualToAnchor:self.downloadTrack.topAnchor],
        [self.downloadFill.bottomAnchor constraintEqualToAnchor:self.downloadTrack.bottomAnchor],
        self.fillWidth,
        [self.mini.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mini.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mini.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.mini.heightAnchor constraintEqualToConstant:64],
    ]];
    __weak typeof(self) weakSelf = self;
    self.tick = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.4, 600) queue:dispatch_get_main_queue() usingBlock:^(__unused CMTime time) { [weakSelf refreshClock]; }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveLibrary) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [self installRemoteCommands];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self installNav];
    [self show];
}

- (void)dealloc {
    if (self.tick) [self.player removeTimeObserver:self.tick];
    [self stopObserving];
}

- (NSInteger)page { return self.history.lastObject.integerValue; }
- (void)push:(NSInteger)page { self.motion = 1; [self.history addObject:@(page)]; [self show]; }
- (void)pop { if (self.history.count > 1) { self.motion = -1; [self.history removeLastObject]; [self show]; } }
- (void)go:(NSInteger)page { self.motion = 0; [self.history removeAllObjects]; [self.history addObject:@(page)]; [self show]; }

- (void)show {
    self.view.backgroundColor = [self darkTheme] ? UIColor.blackColor : [UIColor colorWithWhite:0.96 alpha:1];
    for (UIView *view in self.content.subviews) [view removeFromSuperview];
    self.seekSlider = nil; self.playButton = nil; self.webView = nil;
    UIView *page = nil;
    switch (self.page) {
        case 1: page = [self detailPage]; break;
        case 2: page = [self playerPage]; break;
        case 3: page = [self queuePage]; break;
        case 4: page = [self urlPage]; break;
        case 5: page = [self editorPage]; break;
        case 6: page = [self signInPage]; break;
        case 7: page = [self settingsPage]; break;
        case 8: page = [self aboutPage]; break;
        case 9: page = [self onlinePage]; break;
        case 10: page = [self savedPage]; break;
        default: page = [self listPage]; break;
    }
    page.translatesAutoresizingMaskIntoConstraints = NO;
    [self.content addSubview:page];
    [NSLayoutConstraint activateConstraints:@[[page.topAnchor constraintEqualToAnchor:self.content.topAnchor], [page.bottomAnchor constraintEqualToAnchor:self.content.bottomAnchor], [page.leadingAnchor constraintEqualToAnchor:self.content.leadingAnchor], [page.trailingAnchor constraintEqualToAnchor:self.content.trailingAnchor]]];
    NSInteger direction = self.motion;
    self.motion = 0;
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    CGFloat height = UIScreen.mainScreen.bounds.size.height;
    if (direction > 0 && (self.page == 2 || self.page == 3)) {
        page.transform = CGAffineTransformMakeTranslation(0, height);
        [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ page.transform = CGAffineTransformIdentity; } completion:nil];
    } else if (direction > 0) {
        page.transform = CGAffineTransformMakeTranslation(width, 0);
        [UIView animateWithDuration:0.24 animations:^{ page.transform = CGAffineTransformIdentity; }];
    } else if (direction < 0 && (self.page == 1 || self.page == 2 || self.page == 0)) {
        page.transform = CGAffineTransformMakeTranslation(0, -height * 0.08);
        [UIView animateWithDuration:0.24 animations:^{ page.transform = CGAffineTransformIdentity; }];
    }
    [self refreshMini];
    [self placeDownload];
}

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

- (NSMutableDictionary *)currentPlaylist { if (self.selected < 0 || self.selected >= (NSInteger)self.playlists.count) self.selected = 0; return self.playlists[self.selected]; }
- (NSMutableArray *)tracks { return self.currentPlaylist[@"tracks"]; }
- (NSDictionary *)currentSong { return (self.currentTrack >= 0 && self.currentTrack < (NSInteger)self.tracks.count) ? self.tracks[self.currentTrack] : nil; }
- (NSString *)lineFor:(NSDictionary *)track {
    NSMutableDictionary *song = [track isKindOfClass:NSMutableDictionary.class] ? (NSMutableDictionary *)track : nil;
    NSString *artist = song[@"artist"];
    if (!artist.length) artist = [self guessArtist:track[@"title"] ?: @""];
    [self loadMeta:song];
    double duration = [song[@"duration"] doubleValue];
    if (duration <= 0 && track == [self currentSong]) {
        double item = CMTimeGetSeconds(self.player.currentItem.duration);
        if (isfinite(item) && item > 0) duration = item;
    }
    return duration > 0 ? [NSString stringWithFormat:@"%@ · %@", artist, TPTime(duration)] : artist;
}
- (NSString *)guessArtist:(NSString *)title {
    NSString *name = [title stringByDeletingPathExtension];
    NSArray *parts = [name componentsSeparatedByString:@" - "];
    if (parts.count >= 3 && [parts[0] rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) return parts[1];
    if (parts.count >= 2 && [parts[0] rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound) return parts[0];
    return @"Unknown artist";
}
- (void)loadMeta:(NSMutableDictionary *)track {
    if (!track || track[@"metaTried"]) return;
    NSString *uri = track[@"uri"] ?: @"";
    if (![uri hasPrefix:@"file:"] && ![uri hasPrefix:@"/"]) { track[@"metaTried"] = @YES; return; }
    track[@"metaTried"] = @YES;
    NSURL *url = [uri hasPrefix:@"/"] ? [NSURL fileURLWithPath:uri] : [NSURL URLWithString:uri];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        NSArray *artists = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
        NSString *artist = [artists.firstObject stringValue];
        Float64 duration = CMTimeGetSeconds(asset.duration);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (artist.length) track[@"artist"] = artist;
            if (isfinite(duration) && duration > 0) track[@"duration"] = @(duration);
            [self publishNowPlaying];
            if (self.metaQueued || (self.page != 1 && self.page != 3)) return;
            self.metaQueued = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.metaQueued = NO;
                if (self.page == 1 || self.page == 3) [self show];
            });
        });
    });
}

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

- (UIView *)listPage {
    UIStackView *list = [[UIStackView alloc] init];
    list.axis = UILayoutConstraintAxisVertical;
    list.spacing = 8;
    list.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    list.layoutMarginsRelativeArrangement = YES;
    [list addArrangedSubview:[self titleRow:@"Trim Playlist"]];
    if (!self.playlists.count) [list addArrangedSubview:[self lab:@"No playlists yet." size:15 color:TPMuted() bold:NO]];
    [self.playlists enumerateObjectsUsingBlock:^(NSDictionary *playlist, NSUInteger index, __unused BOOL *stop) {
        TPRecord *art = [[TPRecord alloc] init];
        [art.widthAnchor constraintEqualToConstant:56].active = YES;
        [art.heightAnchor constraintEqualToConstant:56].active = YES;
        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[[self lab:playlist[@"name"] size:16 color:UIColor.whiteColor bold:YES], [self lab:[NSString stringWithFormat:@"%@ songs", @([playlist[@"tracks"] count])] size:13 color:TPMuted() bold:NO]]];
        text.axis = UILayoutConstraintAxisVertical;
        UIButton *more = [self tap:@"⋮" color:UIColor.whiteColor action:@selector(playlistMore:)];
        more.tag = (NSInteger)index;
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[art, text, more]];
        row.spacing = 12;
        row.alignment = UIStackViewAlignmentCenter;
        UIButton *open = [UIButton buttonWithType:UIButtonTypeCustom];
        open.tag = (NSInteger)index;
        [open addTarget:self action:@selector(openPlaylist:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:open];
        open.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[[open.topAnchor constraintEqualToAnchor:row.topAnchor], [open.bottomAnchor constraintEqualToAnchor:row.bottomAnchor], [open.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [open.trailingAnchor constraintEqualToAnchor:more.leadingAnchor]]];
        [list addArrangedSubview:row];
    }];
    UIButton *create = [self tap:@"+  New playlist" color:UIColor.blackColor action:@selector(createPlaylist)];
    create.backgroundColor = UIColor.whiteColor;
    create.layer.cornerRadius = 22;
    [list addArrangedSubview:create];
    return [self fill:list];
}
- (void)openPlaylist:(UIButton *)sender { self.selected = sender.tag; [self saveLibrary]; [self push:1]; }
- (void)playlistMore:(UIButton *)sender {
    self.selected = sender.tag;
    BOOL inside = self.page == 1;
    NSArray *options = inside ? @[@"Add files", @"Add download", @"Online", @"Rename", @"Delete"] : @[@"Open", @"Rename", @"Delete"];
    [self choose:self.currentPlaylist[@"name"] options:options done:^(__unused NSInteger index, NSString *text) {
        if ([text isEqualToString:@"Open"]) [self push:1];
        else if ([text isEqualToString:@"Add files"]) [self pickFiles];
        else if ([text isEqualToString:@"Add download"]) [self openSaved];
        else if ([text isEqualToString:@"Online"]) { [self.onlineChoices removeAllObjects]; [self.onlinePicked removeAllObjects]; [self push:9]; }
        else if ([text isEqualToString:@"Rename"]) [self renamePlaylist];
        else [self deletePlaylist];
    }];
}

- (UIView *)detailPage {
    UIButton *back = [self tap:@"←" color:UIColor.whiteColor action:@selector(pop)];
    UIButton *more = [self tap:@"⋮" color:UIColor.whiteColor action:@selector(playlistMore:)];
    more.tag = self.selected;
    UIView *spacer = [[UIView alloc] init];
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[back, spacer, more]];
    TPRecord *art = [[TPRecord alloc] init];
    [art.widthAnchor constraintEqualToConstant:108].active = YES;
    [art.heightAnchor constraintEqualToConstant:108].active = YES;
    UIStackView *titles = [[UIStackView alloc] initWithArrangedSubviews:@[[self lab:self.currentPlaylist[@"name"] size:26 color:UIColor.whiteColor bold:YES], [self lab:[NSString stringWithFormat:@"Playlist · %lu songs", (unsigned long)self.tracks.count] size:14 color:TPMuted() bold:NO]]];
    titles.axis = UILayoutConstraintAxisVertical;
    UIStackView *head = [[UIStackView alloc] initWithArrangedSubviews:@[art, titles]];
    head.spacing = 14;
    head.alignment = UIStackViewAlignmentCenter;
    UIButton *shuffle = [self actionPill:@"shuffle" title:@"Shuffle" filled:self.shuffle action:@selector(shufflePlay)];
    UIButton *play = [self actionPill:@"play.fill" title:@"Play" filled:YES action:@selector(playFirst)];
    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[shuffle, play]];
    actions.spacing = 10;
    UIStackView *songs = [[UIStackView alloc] init];
    songs.axis = UILayoutConstraintAxisVertical;
    songs.spacing = 4;
    if (!self.tracks.count) [songs addArrangedSubview:[self lab:@"No songs yet. Use ⋮ to add files or an online song." size:14 color:TPMuted() bold:NO]];
    [self.tracks enumerateObjectsUsingBlock:^(NSDictionary *track, NSUInteger index, __unused BOOL *stop) {
        [songs addArrangedSubview:[self songRow:track index:(NSInteger)index art:46 selected:((NSInteger)index == self.currentTrack)]];
    }];
    UIStackView *page = [[UIStackView alloc] initWithArrangedSubviews:@[top, head, actions, songs]];
    page.axis = UILayoutConstraintAxisVertical;
    page.spacing = 14;
    page.layoutMargins = UIEdgeInsetsMake(12, 16, 24, 16);
    page.layoutMarginsRelativeArrangement = YES;
    return [self fill:page];
}

- (UIView *)playerPage {
    NSDictionary *track = [self currentSong];
    UIButton *down = [self tap:@"⌄" color:UIColor.whiteColor action:(self.fullscreen ? @selector(exitFull) : @selector(pop))];
    UIView *spacer = [[UIView alloc] init];
    NSMutableArray *topItems = [NSMutableArray arrayWithObjects:down, spacer, nil];
    if ([track[@"video"] boolValue] && !self.fullscreen) {
        UIButton *quality = [self tap:self.qualityName color:UIColor.whiteColor action:@selector(pickQuality)];
        UIButton *full = [self tap:@"Fullscreen" color:UIColor.whiteColor action:@selector(enterFull)];
        [topItems addObject:quality];
        [topItems addObject:full];
    }
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:topItems];
    top.alignment = UIStackViewAlignmentCenter;
    UIView *stage = [[UIView alloc] init];
    stage.backgroundColor = UIColor.blackColor;
    [stage.heightAnchor constraintEqualToConstant:self.fullscreen ? 420 : 280].active = YES;
    if ([track[@"video"] boolValue]) {
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        layer.videoGravity = AVLayerVideoGravityResizeAspect;
        layer.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width - 32, self.fullscreen ? 420 : 280);
        [stage.layer addSublayer:layer];
    } else {
        TPRecord *art = [[TPRecord alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width - 32, 280)];
        [stage addSubview:art];
    }
    self.timeLabel = [self lab:@"0:00" size:12 color:TPMuted() bold:NO];
    self.totalLabel = [self lab:@"0:00" size:12 color:TPMuted() bold:NO];
    self.seekSlider = [[UISlider alloc] init];
    [self.seekSlider addTarget:self action:@selector(seekMoved) forControlEvents:UIControlEventValueChanged];
    [self.seekSlider addTarget:self action:@selector(seekEnded) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    UIStackView *times = [[UIStackView alloc] initWithArrangedSubviews:@[self.timeLabel, self.seekSlider, self.totalLabel]];
    times.spacing = 8;
    times.alignment = UIStackViewAlignmentCenter;
    UIButton *shuffle = [self iconButton:@"shuffle" point:22 action:@selector(toggleShuffle)];
    shuffle.tintColor = self.shuffle ? [UIColor colorWithRed:0.31 green:0.63 blue:1 alpha:1] : UIColor.whiteColor;
    UIButton *prev = [self iconButton:@"backward.end.fill" point:22 action:@selector(previous)];
    self.playButton = [self iconButton:(self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying ? @"pause.fill" : @"play.fill") point:26 action:@selector(toggle)];
    self.playButton.backgroundColor = UIColor.whiteColor;
    self.playButton.tintColor = UIColor.blackColor;
    self.playButton.layer.cornerRadius = 34;
    [self.playButton.widthAnchor constraintEqualToConstant:68].active = YES;
    [self.playButton.heightAnchor constraintEqualToConstant:68].active = YES;
    UIButton *next = [self iconButton:@"forward.end.fill" point:22 action:@selector(next)];
    NSString *repeatName = self.repeatMode == 2 ? @"repeat.1" : @"repeat";
    UIButton *repeat = [self iconButton:repeatName point:22 action:@selector(cycleRepeat)];
    repeat.tintColor = self.repeatMode ? [UIColor colorWithRed:0.31 green:0.63 blue:1 alpha:1] : UIColor.whiteColor;
    UIStackView *controls = [[UIStackView alloc] initWithArrangedSubviews:@[shuffle, prev, self.playButton, next, repeat]];
    controls.distribution = UIStackViewDistributionEqualSpacing;
    controls.alignment = UIStackViewAlignmentCenter;
    UIButton *upNext = [self tap:@"QUEUE" color:UIColor.whiteColor action:@selector(openQueue)];
    UIStackView *page = [[UIStackView alloc] initWithArrangedSubviews:@[top, stage, [self lab:track[@"title"] ?: @"Select a track" size:22 color:UIColor.whiteColor bold:YES], [self lab:track ? [self lineFor:track] : @" " size:14 color:TPMuted() bold:NO], times, controls, upNext]];
    page.axis = UILayoutConstraintAxisVertical;
    page.spacing = 14;
    page.layoutMargins = UIEdgeInsetsMake(12, 16, 20, 16);
    page.layoutMarginsRelativeArrangement = YES;
    return page;
}
- (void)openQueue { [self push:3]; }
- (void)enterFull { self.fullscreen = YES; [self show]; }
- (void)exitFull { self.fullscreen = NO; [self show]; }
- (void)pickQuality {
    [self choose:@"Quality" options:@[@"Source", @"1080p", @"720p", @"480p", @"360p"] done:^(__unused NSInteger index, NSString *text) {
        self.qualityName = text;
        [self toast:[text isEqualToString:@"Source"] ? @"Playing the file's own quality" : @"This file has one copy. Source is its quality."];
        [self show];
    }];
}

- (UIView *)queuePage {
    UIStackView *songs = [[UIStackView alloc] init];
    songs.axis = UILayoutConstraintAxisVertical;
    songs.spacing = 6;
    songs.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    songs.layoutMarginsRelativeArrangement = YES;
    UILabel *title = [self lab:@"QUEUE" size:16 color:UIColor.whiteColor bold:YES];
    title.textAlignment = NSTextAlignmentCenter;
    [songs addArrangedSubview:title];
    [songs addArrangedSubview:[self lab:@"Playing from" size:12 color:TPMuted() bold:NO]];
    [songs addArrangedSubview:[self lab:self.currentPlaylist[@"name"] size:18 color:UIColor.whiteColor bold:YES]];
    UIStackView *list = [[UIStackView alloc] init];
    list.axis = UILayoutConstraintAxisVertical;
    list.spacing = 6;
    [self.tracks enumerateObjectsUsingBlock:^(NSDictionary *track, NSUInteger index, __unused BOOL *stop) {
        [list addArrangedSubview:[self songRow:track index:(NSInteger)index art:44 selected:((NSInteger)index == self.currentTrack)]];
    }];
    [songs addArrangedSubview:list];
    UIView *handle = [[UIView alloc] init];
    handle.backgroundColor = [UIColor colorWithWhite:0.75 alpha:1];
    handle.layer.cornerRadius = 2.5;
    [handle.heightAnchor constraintEqualToConstant:5].active = YES;
    [handle.widthAnchor constraintEqualToConstant:46].active = YES;
    UIView *handleRow = [[UIView alloc] init];
    [handleRow addSubview:handle];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[[handle.centerXAnchor constraintEqualToAnchor:handleRow.centerXAnchor], [handle.topAnchor constraintEqualToAnchor:handleRow.topAnchor], [handle.bottomAnchor constraintEqualToAnchor:handleRow.bottomAnchor]]];
    [songs insertArrangedSubview:handleRow atIndex:0];
    UIScrollView *scroll = (UIScrollView *)[self fill:songs];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragQueue:)];
    pan.delegate = self;
    [scroll addGestureRecognizer:pan];
    return scroll;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return [gesture.view isKindOfClass:UIScrollView.class];
}
- (void)dragQueue:(UIPanGestureRecognizer *)pan {
    UIScrollView *scroll = (UIScrollView *)pan.view;
    CGPoint moved = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateChanged) {
        if (scroll.contentOffset.y <= 0 && moved.y > 0) scroll.transform = CGAffineTransformMakeTranslation(0, moved.y);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (scroll.transform.ty > 140) {
            [UIView animateWithDuration:0.2 animations:^{ scroll.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height); } completion:^(__unused BOOL done) {
                if (self.history.count > 1) [self.history removeLastObject];
                self.motion = 0;
                [self show];
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{ scroll.transform = CGAffineTransformIdentity; }];
        }
    }
}

- (UIView *)urlPage {
    UIStackView *form = [[UIStackView alloc] init];
    form.axis = UILayoutConstraintAxisVertical;
    form.spacing = 8;
    form.layoutMargins = UIEdgeInsetsMake(16, 16, 28, 16);
    form.layoutMarginsRelativeArrangement = YES;
    [form addArrangedSubview:[self titleRow:@"Trim URL"]];
    [form addArrangedSubview:[self tap:@"Back to playlist" color:UIColor.whiteColor action:@selector(backToList)]];
    [form addArrangedSubview:[self lab:@"Download type" size:13 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self menuField:(self.downloadType ? @"Entire playlist" : @"Single video") action:@selector(pickType)]];
    [form addArrangedSubview:[self lab:@"Video URL" size:13 color:TPMuted() bold:NO]];
    UITextField *url = [self input:@"https://…"];
    url.tag = 70;
    url.text = self.draftUrl;
    url.keyboardType = UIKeyboardTypeURL;
    [url addTarget:self action:@selector(draftChanged:) forControlEvents:UIControlEventEditingChanged];
    [form addArrangedSubview:url];
    [form addArrangedSubview:[self lab:@"Mode" size:13 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self menuField:(self.downloadMode ? @"Trim" : @"Full download") action:@selector(pickMode)]];
    [form addArrangedSubview:[self lab:@"Format" size:13 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self menuField:(self.downloadFormat ? @"MP3 music" : @"MP4 video") action:@selector(pickFormat)]];
    if (self.downloadFormat == 0) { [form addArrangedSubview:[self lab:@"Video quality" size:13 color:TPMuted() bold:NO]]; [form addArrangedSubview:[self menuField:[self videoQualities][(NSUInteger)MIN(self.downloadQuality, 4)] action:@selector(pickVideoQuality)]]; }
    else { [form addArrangedSubview:[self lab:@"MP3 quality" size:13 color:TPMuted() bold:NO]]; [form addArrangedSubview:[self menuField:[self audioQualities][(NSUInteger)MIN(self.downloadAudio, 6)] action:@selector(pickAudioQuality)]]; }
    if (!self.downloadType && self.downloadMode) {
        [form addArrangedSubview:[self lab:@"Filename (optional)" size:13 color:TPMuted() bold:NO]];
        UITextField *name = [self input:@"Use original title"]; name.tag = 73; name.text = self.draftName; [name addTarget:self action:@selector(draftChanged:) forControlEvents:UIControlEventEditingChanged]; [form addArrangedSubview:name];
        [form addArrangedSubview:[self lab:@"Start" size:13 color:TPMuted() bold:NO]];
        UITextField *start = [self input:@"0:00"]; start.tag = 71; start.text = self.draftStart; [start addTarget:self action:@selector(draftChanged:) forControlEvents:UIControlEventEditingChanged]; [form addArrangedSubview:start];
        [form addArrangedSubview:[self lab:@"End" size:13 color:TPMuted() bold:NO]];
        UITextField *end = [self input:@"3:30"]; end.tag = 72; end.text = self.draftEnd; [end addTarget:self action:@selector(draftChanged:) forControlEvents:UIControlEventEditingChanged]; [form addArrangedSubview:end];
        [form addArrangedSubview:[self lab:@"The saved file is cut from Start to End." size:12 color:TPMuted() bold:NO]];
    }
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
    [form addArrangedSubview:[self lab:@"Volume multiplier" size:13 color:TPMuted() bold:NO]];
    UITextField *volume = [self input:@"1"]; volume.tag = 74; volume.text = self.draftVolume.length ? self.draftVolume : @"1"; [volume addTarget:self action:@selector(draftChanged:) forControlEvents:UIControlEventEditingChanged]; [form addArrangedSubview:volume];
    [form addArrangedSubview:[self lab:@"1 = original volume · 2 = boost" size:12 color:TPMuted() bold:NO]];
    [form addArrangedSubview:[self lab:@"The file stays in Downloads. Add it to a playlist from the playlist menu." size:12 color:TPMuted() bold:NO]];
    BOOL picking = self.downloadType == 0 && self.downloadChoices.count > 0;
    if (picking) {
        [form addArrangedSubview:[self lab:(self.downloadMode == 1 ? @"Choose one video. Nothing is downloaded until you continue." : @"Choose the videos in this playlist. Nothing is downloaded until you continue.") size:13 color:TPMuted() bold:NO]];
        [self.downloadChoices enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger index, __unused BOOL *stop) {
            BOOL picked = [self.downloadPicked containsObject:@(index)];
            NSString *title = [NSString stringWithFormat:@"%@  %@", picked ? @"✓" : @"○", entry[@"title"] ?: @""];
            UIButton *row = [self tap:title color:UIColor.whiteColor action:@selector(toggleDownloadChoice:)];
            row.tag = (NSInteger)index;
            row.accessibilityIdentifier = @"choice";
            row.backgroundColor = picked ? [UIColor colorWithWhite:0.22 alpha:1] : [UIColor colorWithWhite:0.14 alpha:1];
            row.layer.cornerRadius = 10;
            row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            row.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
            row.titleLabel.numberOfLines = 2;
            [form addArrangedSubview:row];
        }];
    }
    [form addArrangedSubview:[self tap:(picking ? @"Download selected" : @"Start download") color:UIColor.whiteColor action:@selector(startDownload)]];
    return [self fill:form];
}
- (void)backToList { [self go:0]; }
- (void)pickType { [self choose:@"Download type" options:@[@"Single video", @"Entire playlist"] done:^(NSInteger index, __unused NSString *text) { self.downloadType = index; if (index == 1) self.downloadMode = 0; [self.downloadChoices removeAllObjects]; [self.downloadPicked removeAllObjects]; self.downloadChoiceUrl = @""; [self saveTrim]; [self show]; }]; }
- (void)pickMode { [self choose:@"Mode" options:@[@"Full download", @"Trim"] done:^(NSInteger index, __unused NSString *text) { self.downloadMode = index; if (index == 1 && self.downloadPicked.count > 1) { NSNumber *keep = [self.downloadPicked.allObjects sortedArrayUsingSelector:@selector(compare:)].firstObject; [self.downloadPicked removeAllObjects]; if (keep) [self.downloadPicked addObject:keep]; } [self saveTrim]; [self show]; }]; }
- (void)pickFormat { [self choose:@"Format" options:@[@"MP4 video", @"MP3 music"] done:^(NSInteger index, __unused NSString *text) { self.downloadFormat = index; [self saveTrim]; [self show]; }]; }
- (void)pickVideoQuality { [self choose:@"Video quality" options:[self videoQualities] done:^(NSInteger index, __unused NSString *text) { self.downloadQuality = index; [self saveTrim]; [self show]; }]; }
- (void)pickAudioQuality { [self choose:@"MP3 quality" options:[self audioQualities] done:^(NSInteger index, __unused NSString *text) { self.downloadAudio = index; [self saveTrim]; [self show]; }]; }
- (void)pickAuth { [self choose:@"Authentication" options:@[@"Cookie file", @"Platform account", @"No authentication"] done:^(NSInteger index, __unused NSString *text) { self.downloadAuth = index; [self saveTrim]; [self show]; }]; }
- (void)pickPlatform { [self choose:@"Platform" options:@[@"YouTube", @"Facebook", @"Instagram", @"X / Twitter", @"TikTok", @"Twitch"] done:^(NSInteger index, __unused NSString *text) { self.downloadPlatform = index; [self saveTrim]; [self show]; }]; }
- (void)pickCookie {
    NSMutableArray *names = [NSMutableArray arrayWithObject:@"No cookies"];
    for (NSURL *url in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self cookiesDirectory] includingPropertiesForKeys:nil options:0 error:nil]) if ([url.pathExtension.lowercaseString isEqualToString:@"txt"]) [names addObject:url.lastPathComponent];
    [self choose:@"Cookies" options:names done:^(NSInteger index, NSString *text) { self.cookieName = index == 0 ? @"" : text; [self saveTrim]; [self show]; }];
}
- (void)createCookie {
    [self choose:@"Create cookie file" options:@[@"Manual .txt", @"Import .txt file"] done:^(NSInteger index, __unused NSString *text) {
        if (index == 1) { self.pickKind = @"cookie"; [self presentPicker:@[@"public.text", @"public.plain-text"]]; return; }
        UIAlertController *ask = [UIAlertController alertControllerWithTitle:@"Cookie file name" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [ask addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"cookies"; }];
        [ask addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [ask addAction:[UIAlertAction actionWithTitle:@"Edit" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSString *name = ask.textFields.firstObject.text.length ? ask.textFields.firstObject.text : @"cookies";
            if (![name.lowercaseString hasSuffix:@".txt"]) name = [name stringByAppendingString:@".txt"];
            self.cookieName = name;
            [self saveTrim];
            self.editorPath = [[self cookiesDirectory] URLByAppendingPathComponent:name].path;
            if (![[NSFileManager defaultManager] fileExistsAtPath:self.editorPath]) [@"# Netscape HTTP Cookie File\n" writeToFile:self.editorPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [self push:5];
        }]];
        [self presentViewController:ask animated:YES completion:nil];
    }];
}
- (void)openSignIn { [self push:6]; }
- (void)toggleDownloadChoice:(UIButton *)sender {
    NSNumber *index = @(sender.tag);
    if (self.downloadMode == 1) {
        [self.downloadPicked removeAllObjects];
        [self.downloadPicked addObject:index];
    } else if ([self.downloadPicked containsObject:index]) {
        [self.downloadPicked removeObject:index];
    } else {
        [self.downloadPicked addObject:index];
    }
    [self paintChoicesFrom:sender choices:self.downloadChoices picked:self.downloadPicked];
}
- (void)loadDownloadChoices:(NSString *)page {
    self.downloadBusy = YES;
    [self toast:@"Loading playlist…"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            NSString *cookie = [self authCookieForPage:page];
            NSArray *found = [self catalog:page cookie:cookie];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.downloadBusy = NO;
                [self.downloadChoices removeAllObjects];
                [self.downloadChoices addObjectsFromArray:found];
                [self.downloadPicked removeAllObjects];
                self.downloadChoiceUrl = page;
                [self show];
            });
        } @catch (NSException *ex) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.downloadBusy = NO;
                [self toast:ex.reason ?: @"Couldn't read that playlist"];
            });
        }
    });
}
- (void)startDownload {
    UITextField *url = [self.content viewWithTag:70];
    NSString *value = [url.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![value hasPrefix:@"http://"] && ![value hasPrefix:@"https://"]) { [self toast:@"Enter a video or playlist URL"]; return; }
    if (self.downloadBusy) { [self toast:@"A download is already running"]; return; }
    [self saveTrim];
    BOOL trimming = self.downloadType == 0 && self.downloadMode == 1;
    double trimStart = 0, trimEnd = 0;
    if (trimming) {
        @try {
            trimStart = [self clock:self.draftStart];
            trimEnd = [self clock:self.draftEnd];
        } @catch (NSException *ex) {
            [self toast:ex.reason ?: @"Use seconds, MM:SS or HH:MM:SS"];
            return;
        }
        if (trimStart < 0 || trimEnd <= trimStart) { [self toast:@"End must be after start"]; return; }
    }
    NSString *trimName = [self.draftName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    BOOL playlist = [value containsString:@"list="];
    if (self.downloadType == 0 && playlist) {
        if (![self.downloadChoiceUrl isEqualToString:value] || self.downloadChoices.count == 0) {
            [self loadDownloadChoices:value];
            return;
        }
        NSMutableArray *chosen = [NSMutableArray array];
        NSArray *order = [self.downloadPicked.allObjects sortedArrayUsingSelector:@selector(compare:)];
        for (NSNumber *index in order) {
            if (index.integerValue >= 0 && index.integerValue < (NSInteger)self.downloadChoices.count) [chosen addObject:self.downloadChoices[(NSUInteger)index.integerValue][@"url"] ?: @""];
        }
        if (!chosen.count) { [self toast:@"Select a video"]; return; }
        [self beginDownload:chosen trim:trimming start:trimStart end:trimEnd name:trimName];
        return;
    }
    [self beginDownload:@[value] trim:trimming start:trimStart end:trimEnd name:trimName];
}
- (void)beginDownload:(NSArray *)pages trim:(BOOL)trim start:(double)start end:(double)end name:(NSString *)name {
    self.downloadBusy = YES;
    self.downloadCleared = NO;
    BOOL audio = self.downloadFormat == 1;
    NSInteger quality = self.downloadQuality;
    [self reportDownload:@"Starting · 0%" fraction:0];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            NSMutableArray *items = [NSMutableArray array];
            for (NSString *page in pages) {
                NSString *cookie = [self authCookieForPage:page];
                [items addObjectsFromArray:[self resolvePage:page audio:audio quality:quality cookie:cookie]];
            }
            [items enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger index, __unused BOOL *stop) {
                NSString *place = items.count > 1 ? [NSString stringWithFormat:@"%lu/%lu · ", (unsigned long)(index + 1), (unsigned long)items.count] : @"";
                [self saveItem:item cookie:nil place:place trim:trim start:start end:end name:name];
            }];
            NSString *word = items.count == 1 ? @"file" : @"files";
            [self reportDownload:[NSString stringWithFormat:@"Saved %lu %@ · 100%%", (unsigned long)items.count, word] fraction:1];
        } @catch (NSException *ex) {
            [self reportDownload:(ex.reason.length ? ex.reason : @"Download failed") fraction:0];
        }
        self.downloadBusy = NO;
    });
}
- (double)clock:(NSString *)value {
    NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray *parts = [text componentsSeparatedByString:@":"];
    if (!text.length || parts.count < 1 || parts.count > 3) @throw [NSException exceptionWithName:@"time" reason:@"Use seconds, MM:SS or HH:MM:SS" userInfo:nil];
    double result = 0;
    for (NSString *part in parts) {
        if (!part.length) @throw [NSException exceptionWithName:@"time" reason:@"Use seconds, MM:SS or HH:MM:SS" userInfo:nil];
        result = result * 60 + part.doubleValue;
    }
    return result;
}
- (NSArray *)videoQualities { return @[@"Best available", @"1080", @"720", @"480", @"360"]; }
- (NSArray *)audioQualities { return @[@"Best quality (VBR)", @"320 kbps", @"256 kbps", @"192 kbps", @"128 kbps", @"96 kbps", @"64 kbps"]; }
- (void)loadTrim {
    NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
    self.downloadType = [prefs integerForKey:@"trim-type"];
    self.downloadMode = [prefs integerForKey:@"trim-mode"];
    self.downloadFormat = [prefs integerForKey:@"trim-format"];
    self.downloadQuality = [prefs integerForKey:@"trim-quality"];
    self.downloadAudio = [prefs integerForKey:@"trim-audio"];
    self.downloadAuth = [prefs objectForKey:@"trim-auth"] ? [prefs integerForKey:@"trim-auth"] : 2;
    self.downloadPlatform = [prefs integerForKey:@"trim-platform"];
    self.cookieName = [prefs stringForKey:@"trim-cookie"] ?: @"";
    self.draftUrl = [prefs stringForKey:@"trim-url"] ?: @"";
    self.draftName = [prefs stringForKey:@"trim-name"] ?: @"";
    self.draftStart = [prefs stringForKey:@"trim-start"] ?: @"";
    self.draftEnd = [prefs stringForKey:@"trim-end"] ?: @"";
    self.draftVolume = [prefs stringForKey:@"trim-volume"] ?: @"1";
}
- (void)saveTrim {
    NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
    [prefs setInteger:self.downloadType forKey:@"trim-type"];
    [prefs setInteger:self.downloadMode forKey:@"trim-mode"];
    [prefs setInteger:self.downloadFormat forKey:@"trim-format"];
    [prefs setInteger:self.downloadQuality forKey:@"trim-quality"];
    [prefs setInteger:self.downloadAudio forKey:@"trim-audio"];
    [prefs setInteger:self.downloadAuth forKey:@"trim-auth"];
    [prefs setInteger:self.downloadPlatform forKey:@"trim-platform"];
    [prefs setObject:(self.cookieName ?: @"") forKey:@"trim-cookie"];
    [prefs setObject:(self.draftUrl ?: @"") forKey:@"trim-url"];
    [prefs setObject:(self.draftName ?: @"") forKey:@"trim-name"];
    [prefs setObject:(self.draftStart ?: @"") forKey:@"trim-start"];
    [prefs setObject:(self.draftEnd ?: @"") forKey:@"trim-end"];
    [prefs setObject:(self.draftVolume.length ? self.draftVolume : @"1") forKey:@"trim-volume"];
}
- (void)draftChanged:(UITextField *)field {
    NSString *text = field.text ?: @"";
    if (field.tag == 70) {
        if (![text isEqualToString:self.downloadChoiceUrl ?: @""]) {
            [self.downloadChoices removeAllObjects];
            [self.downloadPicked removeAllObjects];
            self.downloadChoiceUrl = @"";
        }
        self.draftUrl = text;
    }
    else if (field.tag == 73) self.draftName = text;
    else if (field.tag == 71) self.draftStart = text;
    else if (field.tag == 72) self.draftEnd = text;
    else if (field.tag == 74) self.draftVolume = text.length ? text : @"1";
    [self saveTrim];
}
- (void)reportDownload:(NSString *)text fraction:(float)fraction {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.downloadCleared) return;
        self.downloadFraction = fraction;
        self.downloadLabel.text = text;
        [self placeDownload];
    });
}
- (void)placeDownload {
    BOOL onUrl = !self.downloadCleared && self.page == 4 && self.downloadLabel.text.length > 0;
    self.downloadBarHeight.constant = onUrl ? 56 : 0;
    [self.view layoutIfNeeded];
    self.fillWidth.constant = self.downloadTrack.bounds.size.width * MAX(0.f, MIN(1.f, self.downloadFraction));
}
- (void)clearDownload { self.downloadCleared = YES; self.downloadBarHeight.constant = 0; }
- (NSString *)authCookieForPage:(NSString *)page {
    if (self.downloadAuth == 2) return nil;
    NSURL *parsed = [NSURL URLWithString:page];
    NSString *host = parsed.host.length ? parsed.host : @"www.youtube.com";
    if ([page containsString:@"youtu"]) host = @"www.youtube.com";
    if (self.downloadAuth == 1) return [self websiteCookiesForHost:host];
    if (!self.cookieName.length) return nil;
    NSString *path = [[self cookiesDirectory] URLByAppendingPathComponent:self.cookieName].path;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (!line.length || [line hasPrefix:@"#"]) continue;
        NSArray *parts = [line componentsSeparatedByString:@"\t"];
        if (parts.count < 7) continue;
        NSString *domain = [parts[0] hasPrefix:@"."] ? [parts[0] substringFromIndex:1] : parts[0];
        NSString *lower = domain.lowercaseString;
        NSString *target = host.lowercaseString;
        if (![target isEqualToString:lower] && ![target hasSuffix:[@"." stringByAppendingString:lower]] && ![lower hasSuffix:target]) continue;
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", parts[5], parts[6]]];
    }
    return pairs.count ? [pairs componentsJoinedByString:@"; "] : nil;
}
- (NSString *)websiteCookiesForHost:(NSString *)host {
    __block NSString *cookie = nil;
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WKWebsiteDataStore defaultDataStore].httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            NSMutableArray *pairs = [NSMutableArray array];
            for (NSHTTPCookie *item in cookies) {
                NSString *domain = [item.domain hasPrefix:@"."] ? [item.domain substringFromIndex:1] : item.domain;
                if ([host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]]) [pairs addObject:[NSString stringWithFormat:@"%@=%@", item.name, item.value]];
            }
            cookie = pairs.count ? [pairs componentsJoinedByString:@"; "] : nil;
            dispatch_semaphore_signal(gate);
        }];
    });
    dispatch_semaphore_wait(gate, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    return cookie;
}
- (NSArray *)resolvePage:(NSString *)page audio:(BOOL)audio quality:(NSInteger)quality cookie:(NSString *)cookie {
    BOOL youtube = [page containsString:@"youtube.com"] || [page containsString:@"youtu.be"];
    NSString *list = [self firstMatch:@"[?&]list=([A-Za-z0-9_-]+)" in:page];
    if (youtube && list.length) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *video in [self playlistIds:list cookie:cookie]) [items addObject:[self youtubeItem:video audio:audio quality:quality cookie:cookie split:YES]];
        if (!items.count) @throw [NSException exceptionWithName:@"download" reason:@"No videos were found in that playlist" userInfo:nil];
        return items;
    }
    if (youtube) {
        NSString *video = [self firstMatch:@"(?:v=|youtu\\.be/|shorts/|embed/)([A-Za-z0-9_-]{11})" in:page];
        if (!video.length) @throw [NSException exceptionWithName:@"download" reason:@"That YouTube link has no video" userInfo:nil];
        return @[[self youtubeItem:video audio:audio quality:quality cookie:cookie split:YES]];
    }
    return @[[self directItem:page cookie:cookie]];
}
- (NSArray *)catalog:(NSString *)page cookie:(NSString *)cookie {
    BOOL youtube = [page containsString:@"youtube.com"] || [page containsString:@"youtu.be"];
    if (!youtube) {
        NSString *name = page.lastPathComponent.length ? page.lastPathComponent : @"Online";
        return @[@{@"title": name, @"url": page}];
    }
    NSString *list = [self firstMatch:@"[?&]list=([A-Za-z0-9_-]+)" in:page];
    if (list.length) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *entry in [self playlistEntries:list cookie:cookie]) {
            [rows addObject:@{@"title": entry[@"title"], @"url": [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", entry[@"id"]]}];
        }
        return rows;
    }
    NSString *video = [self firstMatch:@"(?:v=|youtu\\.be/|shorts/|embed/)([A-Za-z0-9_-]{11})" in:page];
    if (!video.length) @throw [NSException exceptionWithName:@"download" reason:@"That YouTube link has no video" userInfo:nil];
    NSDictionary *item = [self youtubeItem:video audio:NO quality:0 cookie:cookie split:NO];
    NSString *title = [item[@"title"] length] ? item[@"title"] : video;
    NSRange cut = [title rangeOfString:@" · "];
    if (cut.location != NSNotFound) title = [title substringToIndex:cut.location];
    return @[@{@"title": title, @"url": [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", video]}];
}
- (NSArray *)playlistEntries:(NSString *)list cookie:(NSString *)cookie {
    NSString *page = [NSString stringWithFormat:@"https://www.youtube.com/playlist?list=%@", list];
    NSData *data = [self http:page method:@"GET" body:nil cookie:cookie headers:@{@"User-Agent": @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36", @"Accept-Language": @"en"}];
    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\"videoId\":\"([A-Za-z0-9_-]{11})\"" options:0 error:nil];
    NSRegularExpression *titleRe = [NSRegularExpression regularExpressionWithPattern:@"\"title\":\\{\"runs\":\\[\\{\"text\":\"((?:\\\\.|[^\"\\\\])*)\"" options:0 error:nil];
    for (NSTextCheckingResult *hit in [re matchesInString:html options:0 range:NSMakeRange(0, html.length)]) {
        NSString *video = [html substringWithRange:[hit rangeAtIndex:1]];
        if ([seen containsObject:video]) continue;
        NSUInteger start = NSMaxRange(hit.range);
        if (start >= html.length) continue;
        NSUInteger len = MIN((NSUInteger)900, html.length - start);
        NSString *window = [html substringWithRange:NSMakeRange(start, len)];
        NSTextCheckingResult *titleHit = [titleRe firstMatchInString:window options:0 range:NSMakeRange(0, window.length)];
        NSString *title = video;
        if (titleHit && titleHit.numberOfRanges > 1) title = [self jsonText:[window substringWithRange:[titleHit rangeAtIndex:1]]];
        if (!title.length) title = video;
        [seen addObject:video];
        [rows addObject:@{@"id": video, @"title": title}];
    }
    if (!rows.count) @throw [NSException exceptionWithName:@"download" reason:@"No videos were found in that playlist" userInfo:nil];
    return rows;
}
- (NSString *)jsonText:(NSString *)raw {
    return [[[raw stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""] stringByReplacingOccurrencesOfString:@"\\u0026" withString:@"&"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
}
- (NSString *)firstMatch:(NSString *)pattern in:(NSString *)text {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult *hit = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!hit || hit.numberOfRanges < 2) return @"";
    return [text substringWithRange:[hit rangeAtIndex:1]];
}
- (NSArray *)playlistIds:(NSString *)list cookie:(NSString *)cookie {
    NSMutableArray *ids = [NSMutableArray array];
    @try {
        NSString *body = [NSString stringWithFormat:@"{\"browseId\":\"VL%@\",\"context\":{\"client\":{\"clientName\":\"WEB\",\"clientVersion\":\"2.20250301.01.00\",\"hl\":\"en\"}}}", list];
        NSData *data = [self http:@"https://www.youtube.com/youtubei/v1/browse?prettyPrint=false" method:@"POST" body:[body dataUsingEncoding:NSUTF8StringEncoding] cookie:cookie headers:@{@"Content-Type": @"application/json", @"User-Agent": @"Mozilla/5.0"}];
        [self collectVideoIds:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] into:ids];
    } @catch (NSException *ex) { (void)ex; }
    if (!ids.count) {
        NSString *page = [NSString stringWithFormat:@"https://www.youtube.com/playlist?list=%@", list];
        NSData *data = [self http:page method:@"GET" body:nil cookie:cookie headers:@{@"User-Agent": @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36", @"Accept-Language": @"en"}];
        [self collectVideoIds:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] into:ids];
    }
    if (!ids.count) @throw [NSException exceptionWithName:@"download" reason:@"No videos were found in that playlist" userInfo:nil];
    return ids;
}
- (void)collectVideoIds:(NSString *)text into:(NSMutableArray *)ids {
    if (!text.length) return;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\"videoId\":\"([A-Za-z0-9_-]{11})\"" options:0 error:nil];
    for (NSTextCheckingResult *hit in [re matchesInString:text options:0 range:NSMakeRange(0, text.length)]) {
        NSString *video = [text substringWithRange:[hit rangeAtIndex:1]];
        if (![ids containsObject:video]) [ids addObject:video];
    }
}
- (NSString *)playbackURL:(NSString *)page audio:(BOOL)audio cookie:(NSString *)cookie {
    BOOL youtube = [page containsString:@"youtube.com"] || [page containsString:@"youtu.be"];
    if (!youtube) return page;
    NSString *video = [self firstMatch:@"(?:v=|youtu\\.be/|shorts/|embed/)([A-Za-z0-9_-]{11})" in:page];
    if (!video.length) @throw [NSException exceptionWithName:@"download" reason:@"That YouTube link has no video" userInfo:nil];
    return [self youtubeItem:video audio:audio quality:0 cookie:cookie split:NO][@"url"] ?: @"";
}
- (NSDictionary *)youtubeItem:(NSString *)video audio:(BOOL)audio quality:(NSInteger)quality cookie:(NSString *)cookie split:(BOOL)split {
    NSString *body = [NSString stringWithFormat:@"{\"videoId\":\"%@\",\"context\":{\"client\":{\"clientName\":\"ANDROID\",\"clientVersion\":\"20.10.38\",\"androidSdkVersion\":30,\"hl\":\"en\",\"gl\":\"US\"}}}", video];
    NSDictionary *headers = @{@"Content-Type": @"application/json", @"User-Agent": @"com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip"};
    NSData *data = [self http:@"https://www.youtube.com/youtubei/v1/player?prettyPrint=false" method:@"POST" body:[body dataUsingEncoding:NSUTF8StringEncoding] cookie:nil headers:headers];
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:(data ?: [NSData data]) options:0 error:nil];
    NSDictionary *status = root[@"playabilityStatus"];
    if ([status[@"status"] isEqualToString:@"LOGIN_REQUIRED"] && cookie.length) {
        data = [self http:@"https://www.youtube.com/youtubei/v1/player?prettyPrint=false" method:@"POST" body:[body dataUsingEncoding:NSUTF8StringEncoding] cookie:cookie headers:headers];
        root = [NSJSONSerialization JSONObjectWithData:(data ?: [NSData data]) options:0 error:nil];
        status = root[@"playabilityStatus"];
    }
    if ([status[@"status"] isEqualToString:@"LOGIN_REQUIRED"]) {
        NSString *reason = cookie.length ? @"YouTube did not accept the saved login for this video" : @"Sign in to YouTube, then start the download again";
        @throw [NSException exceptionWithName:@"download" reason:reason userInfo:nil];
    }
    if (status && ![status[@"status"] isEqualToString:@"OK"]) {
        NSString *reason = [status[@"reason"] length] ? status[@"reason"] : @"YouTube did not allow this video";
        @throw [NSException exceptionWithName:@"download" reason:reason userInfo:nil];
    }
    NSString *title = [root[@"videoDetails"][@"title"] length] ? root[@"videoDetails"][@"title"] : video;
    NSDictionary *streaming = root[@"streamingData"];
    if (!streaming) @throw [NSException exceptionWithName:@"download" reason:[@"YouTube did not give a file for " stringByAppendingString:title] userInfo:nil];
    NSDictionary *chosen = nil;
    NSString *audioUrl = @"";
    if (!audio && split) {
        NSDictionary *picture = [self pickHighVideo:streaming quality:quality];
        NSDictionary *sound = [self pickAudio:streaming];
        if (picture && sound) {
            chosen = picture;
            audioUrl = sound[@"url"] ?: @"";
        }
    }
    if (!chosen) chosen = audio ? [self pickAudio:streaming] : [self pickVideo:streaming quality:quality];
    if (!chosen) @throw [NSException exceptionWithName:@"download" reason:@"YouTube locked this file. Sign-in covers private videos. The Windows app unlocks signed files and can cut or convert them." userInfo:nil];
    NSString *mime = chosen[@"mimeType"] ?: @"";
    NSString *ext = @"mp4";
    if (audio && [mime containsString:@"webm"]) ext = @"webm";
    else if ([mime containsString:@"audio"]) ext = @"m4a";
    NSString *shown = title;
    if (audioUrl.length) shown = [NSString stringWithFormat:@"%@ · %ldp", title, (long)[chosen[@"height"] integerValue]];
    NSString *combined = [self pickVideo:streaming quality:quality][@"url"] ?: @"";
    NSString *address = chosen[@"url"] ?: @"";
    if ([combined isEqualToString:address]) combined = @"";
    return @{@"title": shown, @"url": address, @"audioUrl": audioUrl, @"ext": ext, @"video": @(!audio), @"fallback": combined};
}
- (NSDictionary *)pickAudio:(NSDictionary *)streaming {
    NSDictionary *best = nil;
    for (NSDictionary *item in streaming[@"adaptiveFormats"]) {
        NSString *mime = item[@"mimeType"] ?: @"";
        if (![mime hasPrefix:@"audio/"] || ![item[@"url"] length]) continue;
        if (!best) { best = item; continue; }
        BOOL itemMp4 = [mime containsString:@"mp4"];
        BOOL bestMp4 = [best[@"mimeType"] containsString:@"mp4"];
        if ((itemMp4 && !bestMp4) || (itemMp4 == bestMp4 && [item[@"bitrate"] integerValue] > [best[@"bitrate"] integerValue])) best = item;
    }
    return best;
}
- (NSDictionary *)pickHighVideo:(NSDictionary *)streaming quality:(NSInteger)quality {
    NSArray *heights = @[@0, @1080, @720, @480, @360];
    NSInteger maxHeight = quality >= 0 && quality < (NSInteger)heights.count ? [heights[(NSUInteger)quality] integerValue] : 0;
    NSDictionary *best = nil;
    for (NSDictionary *item in streaming[@"adaptiveFormats"]) {
        NSString *mime = item[@"mimeType"] ?: @"";
        if (![mime hasPrefix:@"video/mp4"] || ![mime containsString:@"avc1"] || ![item[@"url"] length]) continue;
        NSInteger height = [item[@"height"] integerValue];
        if (height <= 0 || (maxHeight > 0 && height > maxHeight)) continue;
        if (!best || height > [best[@"height"] integerValue]) best = item;
    }
    return best;
}
- (NSDictionary *)pickVideo:(NSDictionary *)streaming quality:(NSInteger)quality {
    NSArray *heights = @[@0, @1080, @720, @480, @360];
    NSInteger maxHeight = quality >= 0 && quality < (NSInteger)heights.count ? [heights[(NSUInteger)quality] integerValue] : 0;
    NSDictionary *best = nil;
    for (NSDictionary *item in streaming[@"formats"]) {
        if (![item[@"url"] length]) continue;
        NSInteger height = [item[@"height"] integerValue];
        if (maxHeight > 0 && height > maxHeight) continue;
        if (!best || height > [best[@"height"] integerValue]) best = item;
    }
    if (!best) for (NSDictionary *item in streaming[@"formats"]) if ([item[@"url"] length]) best = item;
    return best;
}
- (NSDictionary *)directItem:(NSString *)page cookie:(NSString *)cookie {
    NSInteger status = 0;
    NSString *type = @"";
    [self probe:page cookie:cookie status:&status type:&type];
    if (status >= 400 && status != 405 && status != 501) @throw [NSException exceptionWithName:@"download" reason:[NSString stringWithFormat:@"The link returned %ld", (long)status] userInfo:nil];
    if ([type hasPrefix:@"text/html"]) @throw [NSException exceptionWithName:@"download" reason:@"That page is not a media file this phone can save" userInfo:nil];
    NSString *path = [[page componentsSeparatedByString:@"?"].firstObject lastPathComponent];
    NSString *ext = path.pathExtension.lowercaseString;
    if (ext.length < 2 || ext.length > 4) ext = [type hasPrefix:@"video"] ? @"mp4" : @"m4a";
    BOOL video = [type hasPrefix:@"video"] || [@[@"mp4", @"m4v", @"mov", @"mkv", @"webm"] containsObject:ext];
    return @{@"title": path.length ? path : @"Download", @"url": page, @"ext": ext, @"video": @(video)};
}
- (void)probe:(NSString *)page cookie:(NSString *)cookie status:(NSInteger *)status type:(NSString **)type {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:page]];
    request.HTTPMethod = @"HEAD";
    if (cookie.length) [request setValue:cookie forHTTPHeaderField:@"Cookie"];
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    __block NSInteger code = 0;
    __block NSString *mime = @"";
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, __unused NSError *error) {
        mime = response.MIMEType ?: @"";
        if ([response isKindOfClass:NSHTTPURLResponse.class]) code = [(NSHTTPURLResponse *)response statusCode];
        dispatch_semaphore_signal(gate);
    }] resume];
    dispatch_semaphore_wait(gate, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    if (status) *status = code;
    if (type) *type = mime;
}
- (NSData *)http:(NSString *)url method:(NSString *)method body:(NSData *)body cookie:(NSString *)cookie headers:(NSDictionary *)headers {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = method;
    request.HTTPBody = body;
    request.timeoutInterval = 40;
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    if (cookie.length) [request setValue:cookie forHTTPHeaderField:@"Cookie"];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, __unused BOOL *stop) { [request setValue:value forHTTPHeaderField:key]; }];
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSInteger code = 0;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *got, NSURLResponse *response, __unused NSError *error) {
        data = got;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) code = [(NSHTTPURLResponse *)response statusCode];
        dispatch_semaphore_signal(gate);
    }] resume];
    dispatch_semaphore_wait(gate, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_SEC));
    if (code >= 400) @throw [NSException exceptionWithName:@"download" reason:[NSString stringWithFormat:@"YouTube returned %ld", (long)code] userInfo:nil];
    return data ?: [NSData data];
}
- (void)saveItem:(NSDictionary *)item cookie:(NSString *)cookie place:(NSString *)place trim:(BOOL)trim start:(double)start end:(double)end name:(NSString *)name {
    NSString *path = nil;
    @try {
        path = [self saveParts:item cookie:cookie place:place];
    } @catch (NSException *error) {
        if (![error.reason containsString:@"403"] || ![item[@"fallback"] length]) @throw error;
        NSMutableDictionary *plain = [item mutableCopy];
        plain[@"url"] = item[@"fallback"];
        plain[@"audioUrl"] = @"";
        plain[@"ext"] = @"mp4";
        path = [self saveParts:plain cookie:nil place:place];
    }
    if (trim && path.length) {
        [self reportDownload:[NSString stringWithFormat:@"Trimming %@ · %@", item[@"title"] ?: @"track", place] fraction:0.98];
        NSString *raw = item[@"title"] ?: @"track";
        NSString *title = name.length ? name : [raw componentsSeparatedByString:@" · "].firstObject;
        [self cutPath:path start:start end:end title:title];
    }
}
- (NSString *)saveParts:(NSDictionary *)item cookie:(NSString *)cookie place:(NSString *)place {
    NSString *title = item[@"title"] ?: @"track";
    NSString *clean = [[title componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\/:*?\"<>|"]] componentsJoinedByString:@" "];
    clean = [clean stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length > 80) clean = [clean substringToIndex:80];
    if (!clean.length) clean = @"track";
    NSString *stored = [NSString stringWithFormat:@"%.0f-%@.%@", [NSDate date].timeIntervalSince1970 * 1000, clean, item[@"ext"] ?: @"mp4"];
    NSURL *dest = [[self tracksDirectory] URLByAppendingPathComponent:stored];
    NSString *audioUrl = item[@"audioUrl"];
    if (audioUrl.length) {
        NSString *videoPart = [dest.path stringByAppendingString:@".video.mp4"];
        NSString *audioPart = [dest.path stringByAppendingString:@".audio.m4a"];
        __weak typeof(self) weakSelf = self;
        [self downloadURL:item[@"url"] toPath:videoPart cookie:cookie progress:^(float fraction) {
            [weakSelf reportDownload:[NSString stringWithFormat:@"Downloading %@ · %@%d%%", title, place, (int)(fraction * 80)] fraction:fraction * 0.8f];
        }];
        [self downloadURL:audioUrl toPath:audioPart cookie:cookie progress:^(float fraction) {
            [weakSelf reportDownload:[NSString stringWithFormat:@"Downloading audio · %@%d%%", place, 80 + (int)(fraction * 15)] fraction:0.8f + fraction * 0.15f];
        }];
        [self reportDownload:[NSString stringWithFormat:@"Joining %@ · %@96%%", title, place] fraction:0.96f];
        [self joinVideo:videoPart audio:audioPart toPath:dest.path];
        [[NSFileManager defaultManager] removeItemAtPath:videoPart error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:audioPart error:nil];
    } else {
        __weak typeof(self) weakSelf = self;
        [self downloadURL:item[@"url"] toPath:dest.path cookie:cookie progress:^(float fraction) {
            int percent = fraction < 0 ? 0 : (int)(fraction * 100);
            [weakSelf reportDownload:[NSString stringWithFormat:@"Downloading %@ · %@%d%%", title, place, percent] fraction:fraction];
        }];
    }
    [self reportDownload:[NSString stringWithFormat:@"Downloading %@ · %@100%%", title, place] fraction:1];
    return dest.path;
}
- (void)cutPath:(NSString *)path start:(double)start end:(double)end title:(NSString *)title {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
    dispatch_semaphore_t ready = dispatch_semaphore_create(0);
    [asset loadValuesAsynchronouslyForKeys:@[@"duration", @"tracks"] completionHandler:^{ dispatch_semaphore_signal(ready); }];
    dispatch_semaphore_wait(ready, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
    double length = CMTimeGetSeconds(asset.duration);
    if (!isfinite(length) || length <= start) @throw [NSException exceptionWithName:@"trim" reason:@"That range is outside the file" userInfo:nil];
    double stop = MIN(end, length);
    if (stop <= start) @throw [NSException exceptionWithName:@"trim" reason:@"End must be after start" userInfo:nil];
    CMTimeRange range = CMTimeRangeMake(CMTimeMakeWithSeconds(start, 600), CMTimeMakeWithSeconds(stop - start, 600));
    AVMutableComposition *mix = [AVMutableComposition composition];
    for (AVMediaType kind in @[AVMediaTypeVideo, AVMediaTypeAudio]) {
        for (AVAssetTrack *track in [asset tracksWithMediaType:kind]) {
            AVMutableCompositionTrack *out = [mix addMutableTrackWithMediaType:kind preferredTrackID:kCMPersistentTrackID_Invalid];
            NSError *error = nil;
            if (![out insertTimeRange:range ofTrack:track atTime:kCMTimeZero error:&error]) {
                @throw [NSException exceptionWithName:@"trim" reason:(error.localizedDescription ?: @"Could not trim that file") userInfo:nil];
            }
        }
    }
    BOOL audioOnly = [mix tracksWithMediaType:AVMediaTypeVideo].count == 0;
    NSString *ext = audioOnly ? @"m4a" : (path.pathExtension.length ? path.pathExtension : @"mp4");
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"\\/:*?\"<>|"];
    NSString *clean = [[title componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@" "];
    clean = [clean stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length > 80) clean = [clean substringToIndex:80];
    if (!clean.length) clean = @"track";
    NSString *folder = path.stringByDeletingLastPathComponent;
    NSString *outPath = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", clean, ext]];
    NSInteger number = 2;
    while ([NSFileManager.defaultManager fileExistsAtPath:outPath]) {
        outPath = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ %ld.%@", clean, (long)number, ext]];
        number += 1;
    }
    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:mix presetName:AVAssetExportPresetPassthrough];
    export.outputURL = [NSURL fileURLWithPath:outPath];
    export.outputFileType = audioOnly ? AVFileTypeAppleM4A : AVFileTypeMPEG4;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [export exportAsynchronouslyWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 180 * NSEC_PER_SEC));
    if (export.status != AVAssetExportSessionStatusCompleted) {
        [NSFileManager.defaultManager removeItemAtPath:outPath error:nil];
        AVAssetExportSession *again = [[AVAssetExportSession alloc] initWithAsset:mix presetName:(audioOnly ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality)];
        again.outputURL = [NSURL fileURLWithPath:outPath];
        again.outputFileType = audioOnly ? AVFileTypeAppleM4A : AVFileTypeMPEG4;
        dispatch_semaphore_t second = dispatch_semaphore_create(0);
        [again exportAsynchronouslyWithCompletionHandler:^{ dispatch_semaphore_signal(second); }];
        dispatch_semaphore_wait(second, dispatch_time(DISPATCH_TIME_NOW, 180 * NSEC_PER_SEC));
        if (again.status != AVAssetExportSessionStatusCompleted) {
            [NSFileManager.defaultManager removeItemAtPath:outPath error:nil];
            @throw [NSException exceptionWithName:@"trim" reason:(again.error.localizedDescription ?: @"Could not trim that file") userInfo:nil];
        }
    }
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}
- (void)downloadURL:(NSString *)url toPath:(NSString *)path cookie:(NSString *)cookie progress:(void (^)(float))progress {
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    TPSaver *saver = [TPSaver new];
    saver.handle = handle;
    saver.gate = dispatch_semaphore_create(0);
    saver.progress = progress;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setValue:@"com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip" forHTTPHeaderField:@"User-Agent"];
    NSString *host = request.URL.host.lowercaseString ?: @"";
    if (cookie.length && ([host hasSuffix:@"youtube.com"] || [host hasSuffix:@"youtu.be"])) [request setValue:cookie forHTTPHeaderField:@"Cookie"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:saver delegateQueue:nil];
    [[session dataTaskWithRequest:request] resume];
    dispatch_semaphore_wait(saver.gate, DISPATCH_TIME_FOREVER);
    [handle closeFile];
    [session finishTasksAndInvalidate];
    if (saver.error || saver.status >= 400 || saver.got < 32 || [saver.contentType hasPrefix:@"text/html"]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        @throw [NSException exceptionWithName:@"download" reason:(saver.status >= 400 ? [NSString stringWithFormat:@"Download stopped (%ld)", (long)saver.status] : @"That page is not a media file this phone can save") userInfo:nil];
    }
}
- (void)joinVideo:(NSString *)videoPath audio:(NSString *)audioPath toPath:(NSString *)outPath {
    AVURLAsset *video = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
    AVURLAsset *audio = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:audioPath] options:nil];
    AVAssetTrack *picture = [self track:AVMediaTypeVideo inAsset:video];
    AVAssetTrack *sound = [self track:AVMediaTypeAudio inAsset:audio];
    if (!picture || !sound) @throw [NSException exceptionWithName:@"download" reason:@"Could not join the high quality video and its audio" userInfo:nil];
    AVMutableComposition *mix = [AVMutableComposition composition];
    NSError *error = nil;
    AVMutableCompositionTrack *videoTrack = [mix addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:picture.timeRange ofTrack:picture atTime:kCMTimeZero error:&error];
    if (error) @throw [NSException exceptionWithName:@"download" reason:error.localizedDescription userInfo:nil];
    videoTrack.preferredTransform = picture.preferredTransform;
    AVMutableCompositionTrack *audioTrack = [mix addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    error = nil;
    [audioTrack insertTimeRange:sound.timeRange ofTrack:sound atTime:kCMTimeZero error:&error];
    if (error) @throw [NSException exceptionWithName:@"download" reason:error.localizedDescription userInfo:nil];
    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:mix presetName:AVAssetExportPresetPassthrough];
    export.outputURL = [NSURL fileURLWithPath:outPath];
    export.outputFileType = AVFileTypeMPEG4;
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    [export exportAsynchronouslyWithCompletionHandler:^{ dispatch_semaphore_signal(gate); }];
    dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
    if (export.status != AVAssetExportSessionStatusCompleted) {
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
        AVAssetExportSession *again = [[AVAssetExportSession alloc] initWithAsset:mix presetName:AVAssetExportPresetHighestQuality];
        again.outputURL = [NSURL fileURLWithPath:outPath];
        again.outputFileType = AVFileTypeMPEG4;
        dispatch_semaphore_t retry = dispatch_semaphore_create(0);
        [again exportAsynchronouslyWithCompletionHandler:^{ dispatch_semaphore_signal(retry); }];
        dispatch_semaphore_wait(retry, DISPATCH_TIME_FOREVER);
        if (again.status != AVAssetExportSessionStatusCompleted) {
            [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
            NSString *reason = again.error.localizedDescription.length ? again.error.localizedDescription : @"Could not join the high quality video and its audio";
            @throw [NSException exceptionWithName:@"download" reason:reason userInfo:nil];
        }
    }
}
- (AVAssetTrack *)track:(AVMediaType)type inAsset:(AVAsset *)asset {
    __block AVAssetTrack *found = nil;
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    [asset loadTracksWithMediaType:type completionHandler:^(NSArray<AVAssetTrack *> *tracks, __unused NSError *error) {
        found = tracks.firstObject;
        dispatch_semaphore_signal(gate);
    }];
    dispatch_semaphore_wait(gate, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    return found;
}

- (UIView *)editorPage {
    UILabel *name = [self lab:self.editorPath.lastPathComponent size:18 color:UIColor.whiteColor bold:YES];
    self.editor = [[UITextView alloc] init];
    self.editor.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    self.editor.textColor = UIColor.whiteColor;
    self.editor.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.editor.text = [NSString stringWithContentsOfFile:self.editorPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
    UIButton *save = [self tap:@"Save" color:UIColor.whiteColor action:@selector(saveEditor)];
    UIStackView *page = [[UIStackView alloc] initWithArrangedSubviews:@[name, [self lab:@"Type the cookie file here, the same way you would in a text editor." size:13 color:TPMuted() bold:NO], self.editor, save]];
    page.axis = UILayoutConstraintAxisVertical;
    page.spacing = 8;
    page.layoutMargins = UIEdgeInsetsMake(12, 16, 12, 16);
    page.layoutMarginsRelativeArrangement = YES;
    return page;
}
- (void)saveEditor {
    [self.editor.text writeToFile:self.editorPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self toast:[@"Saved " stringByAppendingString:self.editorPath.lastPathComponent]];
    [self pop];
}

- (UIView *)signInPage {
    NSArray *names = @[@"YouTube", @"Facebook", @"Instagram", @"X / Twitter", @"TikTok", @"Twitch"];
    NSArray *urls = @[
        @"https://accounts.google.com/ServiceLogin?service=youtube&hl=en&passive=true&continue=https%3A%2F%2Fm.youtube.com%2F",
        @"https://m.facebook.com/login",
        @"https://www.instagram.com/accounts/login/",
        @"https://x.com/i/flow/login",
        @"https://www.tiktok.com/login",
        @"https://www.twitch.tv/login"
    ];
    UILabel *title = [self lab:names[self.downloadPlatform] size:18 color:UIColor.whiteColor bold:YES];
    UIButton *done = [self tap:@"Done" color:UIColor.whiteColor action:@selector(finishSignIn)];
    done.backgroundColor = [UIColor colorWithRed:0.2 green:0.46 blue:1 alpha:1];
    done.layer.cornerRadius = 12;
    UIStackView *bar = [[UIStackView alloc] initWithArrangedSubviews:@[title, [[UIView alloc] init], done]];
    bar.alignment = UIStackViewAlignmentCenter;
    bar.backgroundColor = UIColor.blackColor;
    self.signInStatus = [self lab:[NSString stringWithFormat:@"Loading %@ inside Trim Playlist", names[self.downloadPlatform]] size:13 color:[UIColor colorWithWhite:0.15 alpha:1] bold:NO];
    self.signInStatus.backgroundColor = [UIColor colorWithRed:0.91 green:0.93 blue:0.95 alpha:1];
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.backgroundColor = UIColor.whiteColor;
    self.webView.opaque = YES;
    self.webView.customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";
    [self.webView setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urls[self.downloadPlatform]]]];
    UIStackView *page = [[UIStackView alloc] initWithArrangedSubviews:@[bar, self.signInStatus, self.webView]];
    page.axis = UILayoutConstraintAxisVertical;
    page.spacing = 0;
    page.backgroundColor = UIColor.whiteColor;
    return page;
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *scheme = navigationAction.request.URL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) decisionHandler(WKNavigationActionPolicyAllow);
    else {
        self.signInStatus.text = @"That link stays inside Trim Playlist";
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.signInStatus.text = @"Sign in on this page, then tap Done";
}
- (NSString *)platformKey { return [NSString stringWithFormat:@"connected-%ld", (long)self.downloadPlatform]; }
- (void)finishSignIn {
    NSArray *markers = @[
        @[@"SAPISID", @"LOGIN_INFO", @"__Secure-1PSID"],
        @[@"c_user"],
        @[@"sessionid", @"ds_user_id"],
        @[@"auth_token"],
        @[@"sessionid"],
        @[@"auth-token"]
    ];
    NSArray *wanted = markers[self.downloadPlatform];
    [self.webView.configuration.websiteDataStore.httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        BOOL found = NO;
        for (NSHTTPCookie *cookie in cookies) {
            if ([wanted containsObject:cookie.name]) found = YES;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!found) { [self toast:@"Finish the login on this page, then tap Done"]; return; }
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[self platformKey]];
            [self toast:@"Signed in"];
            [self pop];
        });
    }];
}

- (void)refreshMini {
    for (UIView *view in [self.mini.arrangedSubviews copy]) { [self.mini removeArrangedSubview:view]; [view removeFromSuperview]; }
    NSDictionary *track = [self currentSong];
    BOOL hide = !track || self.page == 2 || self.page == 3 || self.page >= 4;
    self.mini.hidden = hide;
    if (hide) return;
    TPRecord *art = [[TPRecord alloc] init];
    [art.widthAnchor constraintEqualToConstant:42].active = YES;
    [art.heightAnchor constraintEqualToConstant:42].active = YES;
    self.miniTitle = [self lab:track[@"title"] size:14 color:UIColor.whiteColor bold:NO];
    UILabel *meta = [self lab:[self lineFor:track] size:12 color:TPMuted() bold:NO];
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[self.miniTitle, meta]];
    text.axis = UILayoutConstraintAxisVertical;
    UIButton *prev = [self iconButton:@"backward.end.fill" point:16 action:@selector(previous)];
    self.miniPlay = [self iconButton:(self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying ? @"pause.fill" : @"play.fill") point:16 action:@selector(toggle)];
    UIButton *next = [self iconButton:@"forward.end.fill" point:16 action:@selector(next)];
    [self.mini addArrangedSubview:art];
    [self.mini addArrangedSubview:text];
    [self.mini addArrangedSubview:prev];
    [self.mini addArrangedSubview:self.miniPlay];
    [self.mini addArrangedSubview:next];
}
- (void)refreshClock {
    double duration = CMTimeGetSeconds(self.player.currentItem.duration);
    double position = CMTimeGetSeconds(self.player.currentTime);
    if (!self.seeking && isfinite(duration) && duration > 0) {
        self.seekSlider.value = (float)(position / duration);
        self.timeLabel.text = TPTime(position);
        self.totalLabel.text = TPTime(duration);
    }
    BOOL playing = self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    NSString *symbol = playing ? @"pause.fill" : @"play.fill";
    UIImageSymbolConfiguration *big = [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightRegular];
    UIImageSymbolConfiguration *small = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
    [self.playButton setImage:[UIImage systemImageNamed:symbol withConfiguration:big] forState:UIControlStateNormal];
    [self.playButton setTitle:@"" forState:UIControlStateNormal];
    [self.miniPlay setImage:[UIImage systemImageNamed:symbol withConfiguration:small] forState:UIControlStateNormal];
    [self.miniPlay setTitle:@"" forState:UIControlStateNormal];
    [self publishNowPlaying];
}
- (void)installRemoteCommands {
    MPRemoteCommandCenter *center = MPRemoteCommandCenter.sharedCommandCenter;
    [center.playCommand addTarget:self action:@selector(remotePlay:)];
    [center.pauseCommand addTarget:self action:@selector(remotePause:)];
    [center.togglePlayPauseCommand addTarget:self action:@selector(remoteToggle:)];
    [center.nextTrackCommand addTarget:self action:@selector(remoteNext:)];
    [center.previousTrackCommand addTarget:self action:@selector(remotePrevious:)];
}
- (MPRemoteCommandHandlerStatus)remotePlay:(MPRemoteCommandEvent *)event { if (self.player.timeControlStatus != AVPlayerTimeControlStatusPlaying) [self toggle]; return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remotePause:(MPRemoteCommandEvent *)event { if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) [self toggle]; return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remoteToggle:(MPRemoteCommandEvent *)event { [self toggle]; return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remoteNext:(MPRemoteCommandEvent *)event { [self next]; return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remotePrevious:(MPRemoteCommandEvent *)event { [self previous]; return MPRemoteCommandHandlerStatusSuccess; }
- (void)publishNowPlaying {
    if (![self notesOn]) { MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = nil; return; }
    NSDictionary *track = [self currentSong];
    if (!track) { MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = nil; return; }
    double duration = CMTimeGetSeconds(self.player.currentItem.duration);
    double position = CMTimeGetSeconds(self.player.currentTime);
    BOOL playing = self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    NSString *line = [self lineFor:track];
    NSString *artist = [[line componentsSeparatedByString:@" · "] firstObject] ?: @"Unknown artist";
    NSMutableDictionary *info = [@{
        MPMediaItemPropertyTitle: track[@"title"] ?: @"Trim Playlist",
        MPMediaItemPropertyArtist: artist,
        MPMediaItemPropertyAlbumTitle: self.currentPlaylist[@"name"] ?: @"",
        MPNowPlayingInfoPropertyElapsedPlaybackTime: @(isfinite(position) ? position : 0),
        MPNowPlayingInfoPropertyPlaybackRate: @(playing ? 1.0 : 0.0)
    } mutableCopy];
    if (isfinite(duration) && duration > 0) info[MPMediaItemPropertyPlaybackDuration] = @(duration);
    else if ([track[@"duration"] doubleValue] > 0) info[MPMediaItemPropertyPlaybackDuration] = track[@"duration"];
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = info;
}
- (void)seekMoved { self.seeking = YES; }
- (void)seekEnded {
    self.seeking = NO;
    double duration = CMTimeGetSeconds(self.player.currentItem.duration);
    if (isfinite(duration) && duration > 0) [self.player seekToTime:CMTimeMakeWithSeconds(self.seekSlider.value * duration, 600)];
}

- (UIView *)songRow:(NSDictionary *)track index:(NSInteger)index art:(CGFloat)art selected:(BOOL)selected {
    TPRecord *icon = [[TPRecord alloc] init];
    [icon.widthAnchor constraintEqualToConstant:art].active = YES;
    [icon.heightAnchor constraintEqualToConstant:art].active = YES;
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[[self lab:track[@"title"] size:15 color:UIColor.whiteColor bold:NO], [self lab:[self lineFor:track] size:12 color:TPMuted() bold:NO]]];
    text.axis = UILayoutConstraintAxisVertical;
    UIButton *remove = [self tap:@"×" color:TPMuted() action:@selector(removeSong:)];
    remove.tag = index;
    [remove.widthAnchor constraintEqualToConstant:36].active = YES;
    UILabel *grip = [self lab:@"≡" size:22 color:UIColor.whiteColor bold:NO];
    grip.userInteractionEnabled = YES;
    grip.textAlignment = NSTextAlignmentCenter;
    [grip.widthAnchor constraintEqualToConstant:36].active = YES;
    [grip addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragSong:)]];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, text, remove, grip]];
    row.spacing = 10;
    row.alignment = UIStackViewAlignmentCenter;
    row.layoutMargins = UIEdgeInsetsMake(6, 0, 6, 0);
    row.layoutMarginsRelativeArrangement = YES;
    if (selected) row.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    [hit addTarget:self action:@selector(playRow:) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:hit];
    hit.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[[hit.topAnchor constraintEqualToAnchor:row.topAnchor], [hit.bottomAnchor constraintEqualToAnchor:row.bottomAnchor], [hit.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [hit.trailingAnchor constraintEqualToAnchor:text.trailingAnchor], [row.heightAnchor constraintGreaterThanOrEqualToConstant:52]]];
    return row;
}
- (void)dragSong:(UIPanGestureRecognizer *)pan {
    UIView *row = pan.view.superview;
    UIStackView *songs = (UIStackView *)row.superview;
    if (![songs isKindOfClass:UIStackView.class]) return;
    if (pan.state == UIGestureRecognizerStateBegan) {
        row.layer.zPosition = 8;
        row.alpha = 0.96;
        [self setScrolling:songs enabled:NO];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint moved = [pan translationInView:songs];
        row.transform = CGAffineTransformMakeTranslation(0, moved.y);
        NSInteger from = [songs.arrangedSubviews indexOfObject:row];
        if (from == NSNotFound) return;
        CGFloat center = CGRectGetMidY(row.frame) + moved.y;
        NSInteger target = from;
        for (NSUInteger i = 0; i < songs.arrangedSubviews.count; i++) {
            if ((NSInteger)i == from) continue;
            CGFloat mid = CGRectGetMidY(songs.arrangedSubviews[i].frame);
            if ((NSInteger)i > from && center > mid) target = (NSInteger)i;
            if ((NSInteger)i < from && center < mid && (target == from || (NSInteger)i < target)) target = (NSInteger)i;
        }
        CGFloat height = row.bounds.size.height + 6;
        [songs.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *child, NSUInteger index, __unused BOOL *stop) {
            if ((NSInteger)index == from) return;
            CGFloat shift = 0;
            if (from < target && (NSInteger)index > from && (NSInteger)index <= target) shift = -height;
            if (target < from && (NSInteger)index >= target && (NSInteger)index < from) shift = height;
            [UIView animateWithDuration:0.14 animations:^{ child.transform = CGAffineTransformMakeTranslation(0, shift); }];
        }];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        NSInteger from = [songs.arrangedSubviews indexOfObject:row];
        CGPoint moved = [pan translationInView:songs];
        CGFloat center = CGRectGetMidY(row.frame) + moved.y;
        NSInteger target = from;
        for (NSUInteger i = 0; i < songs.arrangedSubviews.count; i++) {
            if ((NSInteger)i == from) continue;
            CGFloat mid = CGRectGetMidY(songs.arrangedSubviews[i].frame);
            if ((NSInteger)i > from && center > mid) target = (NSInteger)i;
            if ((NSInteger)i < from && center < mid && (target == from || (NSInteger)i < target)) target = (NSInteger)i;
        }
        row.transform = CGAffineTransformIdentity;
        row.layer.zPosition = 0;
        row.alpha = 1;
        for (UIView *child in songs.arrangedSubviews) child.transform = CGAffineTransformIdentity;
        if (from != NSNotFound && target != from) {
            [songs removeArrangedSubview:row];
            [row removeFromSuperview];
            [songs insertArrangedSubview:row atIndex:(NSUInteger)target];
            [self relocateFrom:from to:target];
            [songs.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *child, NSUInteger index, __unused BOOL *stop) {
                child.backgroundColor = (NSInteger)index == self.currentTrack ? [UIColor colorWithWhite:0.22 alpha:1] : UIColor.clearColor;
            }];
            [self saveLibrary];
        }
        [self setScrolling:songs enabled:YES];
    }
}
- (void)setScrolling:(UIView *)start enabled:(BOOL)enabled {
    UIView *view = start;
    while (view) {
        if ([view isKindOfClass:UIScrollView.class]) ((UIScrollView *)view).scrollEnabled = enabled;
        view = view.superview;
    }
}
- (void)relocateFrom:(NSInteger)from to:(NSInteger)to {
    if (from == to || from < 0 || to < 0 || from >= (NSInteger)self.tracks.count || to >= (NSInteger)self.tracks.count) return;
    id item = self.tracks[(NSUInteger)from];
    [self.tracks removeObjectAtIndex:(NSUInteger)from];
    [self.tracks insertObject:item atIndex:(NSUInteger)to];
    if (self.currentTrack == from) self.currentTrack = to;
    else if (from < self.currentTrack && to >= self.currentTrack) self.currentTrack -= 1;
    else if (from > self.currentTrack && to <= self.currentTrack) self.currentTrack += 1;
}
- (void)playRow:(UIButton *)sender {
    UIView *row = sender.superview;
    UIStackView *songs = (UIStackView *)row.superview;
    NSInteger index = [songs.arrangedSubviews indexOfObject:row];
    if (index != NSNotFound) [self playIndex:index];
}
- (void)playFirst { if (self.tracks.count) [self playIndex:0]; else [self toast:@"Add a song first"]; }
- (void)shufflePlay { self.shuffle = !self.shuffle; if (self.tracks.count) [self playIndex:self.shuffle ? arc4random_uniform((uint32_t)self.tracks.count) : 0]; else [self show]; }
- (void)toggleShuffle { self.shuffle = !self.shuffle; [self saveLibrary]; [self show]; }
- (void)cycleRepeat { self.repeatMode = (self.repeatMode + 1) % 3; [self saveLibrary]; [self show]; }
- (void)toggle {
    if (self.player.currentItem && self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) { [self.player pause]; [self refreshClock]; return; }
    if (self.player.currentItem) { [self.player play]; return; }
    if (self.currentTrack >= 0) [self playIndex:self.currentTrack];
}
- (void)previous { if (CMTimeGetSeconds(self.player.currentTime) > 3) { [self.player seekToTime:kCMTimeZero]; return; } [self step:-1]; }
- (void)next { [self step:1]; }
- (void)step:(NSInteger)direction {
    if (!self.tracks.count) return;
    NSInteger start = self.currentTrack >= 0 ? self.currentTrack : 0;
    NSInteger next = start + direction;
    if (self.shuffle && self.tracks.count > 1) { while (next == start) next = arc4random_uniform((uint32_t)self.tracks.count); }
    else if (next < 0 || next >= (NSInteger)self.tracks.count) { if (self.repeatMode == 1) next = direction > 0 ? 0 : (NSInteger)self.tracks.count - 1; else return; }
    [self playIndex:next];
}
- (void)trackEnded { if (self.repeatMode == 2) [self playIndex:self.currentTrack]; else [self step:1]; }
- (void)warnNotesOff {
    if ([self notesOn] || self.presentedViewController) return;
    UIAlertController *ask = [UIAlertController alertControllerWithTitle:@"Notifications are off" message:@"Turn notifications on to show the playing song on the lock screen." preferredStyle:UIAlertControllerStyleAlert];
    [ask addAction:[UIAlertAction actionWithTitle:@"Not now" style:UIAlertActionStyleCancel handler:nil]];
    [ask addAction:[UIAlertAction actionWithTitle:@"Turn on" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"notes"];
        [self publishNowPlaying];
    }]];
    [self presentViewController:ask animated:YES completion:nil];
}
- (void)playIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tracks.count) return;
    [self warnNotesOff];
    NSDictionary *track = self.tracks[index];
    NSString *page = track[@"uri"] ?: @"";
    BOOL youtube = [page containsString:@"youtube.com"] || [page containsString:@"youtu.be"];
    if ([track[@"kind"] isEqualToString:@"online"] && youtube) {
        if (self.streamBusy) return;
        self.streamBusy = YES;
        [self toast:@"Opening stream…"];
        BOOL audio = ![track[@"video"] boolValue];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @try {
                NSString *cookie = [self authCookieForPage:@"https://www.youtube.com/watch"];
                NSString *stream = [self playbackURL:page audio:audio cookie:cookie];
                NSURL *url = [NSURL URLWithString:stream ?: @""];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.streamBusy = NO;
                    if (!url.absoluteString.length) { [self toast:@"Couldn't open that stream"]; return; }
                    [self beginPlay:index url:url headers:YES];
                });
            } @catch (NSException *ex) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.streamBusy = NO;
                    [self toast:ex.reason ?: @"Couldn't open that stream"];
                });
            }
        });
        return;
    }
    NSURL *url = [self urlFor:track];
    if (!url) { [self toast:@"That file is no longer available"]; return; }
    [self beginPlay:index url:url headers:NO];
}
- (void)beginPlay:(NSInteger)index url:(NSURL *)url headers:(BOOL)headers {
    self.currentTrack = index;
    [self saveLibrary];
    [self stopObserving];
    AVPlayerItem *item = nil;
    if (headers) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey": @{@"User-Agent": @"com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip"}}];
        item = [AVPlayerItem playerItemWithAsset:asset];
    } else {
        item = [AVPlayerItem playerItemWithURL:url];
    }
    self.observed = item;
    [item addObserver:self forKeyPath:@"status" options:0 context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackEnded) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    [self.player replaceCurrentItemWithPlayerItem:item];
    [self.player play];
    [self show];
}
- (void)stopObserving {
    if (!self.observed) return;
    @try { [self.observed removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.observed];
    self.observed = nil;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    (void)change; (void)context;
    if (object == self.observed && [keyPath isEqualToString:@"status"] && self.observed.status == AVPlayerItemStatusFailed) [self toast:@"Couldn't play that track"];
}
- (NSURL *)urlFor:(NSDictionary *)track {
    if ([track[@"kind"] isEqualToString:@"url"] || [track[@"kind"] isEqualToString:@"online"]) return [NSURL URLWithString:track[@"uri"]];
    NSString *path = [[self tracksDirectory] URLByAppendingPathComponent:track[@"uri"]].path;
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ? [NSURL fileURLWithPath:path] : nil;
}

- (void)pickFiles { self.pickKind = @"media"; [self presentPicker:@[@"public.audio", @"public.movie", @"public.video", @"public.mpeg-4"]]; }
- (void)openSaved {
    NSArray *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self tracksDirectory] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableSet *used = [NSMutableSet set];
    for (NSDictionary *track in self.tracks) if ([track[@"uri"] length]) [used addObject:track[@"uri"]];
    [self.savedFiles removeAllObjects];
    for (NSURL *url in urls) {
        NSString *name = url.lastPathComponent;
        if ([name hasSuffix:@".video.mp4"] || [name hasSuffix:@".audio.m4a"] || [used containsObject:name]) continue;
        [self.savedFiles addObject:name];
    }
    if (!self.savedFiles.count) { [self toast:@"No downloads to add"]; return; }
    [self.savedPicked removeAllObjects];
    [self push:10];
}
- (UIView *)savedPage {
    UIStackView *form = [[UIStackView alloc] init];
    form.axis = UILayoutConstraintAxisVertical;
    form.spacing = 8;
    form.layoutMargins = UIEdgeInsetsMake(16, 16, 28, 16);
    form.layoutMarginsRelativeArrangement = YES;
    [form addArrangedSubview:[self titleRow:@"Downloads"]];
    [form addArrangedSubview:[self tap:@"Back to playlist" color:UIColor.whiteColor action:@selector(pop)]];
    [form addArrangedSubview:[self lab:@"Choose the saved files to add." size:13 color:TPMuted() bold:NO]];
    [self.savedFiles enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, __unused BOOL *stop) {
        BOOL picked = [self.savedPicked containsObject:@(index)];
        NSString *title = name;
        NSRange dash = [name rangeOfString:@"-"];
        if (dash.location != NSNotFound && dash.location < 16) title = [name substringFromIndex:dash.location + 1];
        UIButton *row = [self tap:[NSString stringWithFormat:@"%@  %@", picked ? @"✓" : @"○", title] color:UIColor.whiteColor action:@selector(toggleSaved:)];
        row.tag = (NSInteger)index;
        row.accessibilityIdentifier = @"choice";
        row.backgroundColor = picked ? [UIColor colorWithWhite:0.22 alpha:1] : [UIColor colorWithWhite:0.14 alpha:1];
        row.layer.cornerRadius = 10;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
        row.titleLabel.numberOfLines = 2;
        [form addArrangedSubview:row];
    }];
    [form addArrangedSubview:[self tap:@"Add selected" color:UIColor.whiteColor action:@selector(addSelectedSaved)]];
    return [self fill:form];
}
- (void)toggleSaved:(UIButton *)sender {
    NSNumber *index = @(sender.tag);
    if ([self.savedPicked containsObject:index]) [self.savedPicked removeObject:index];
    else [self.savedPicked addObject:index];
    [self paintChoicesFrom:sender choices:[self savedChoiceRows] picked:self.savedPicked];
}
- (NSArray *)savedChoiceRows {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *name in self.savedFiles) {
        NSString *title = name;
        NSRange dash = [name rangeOfString:@"-"];
        if (dash.location != NSNotFound && dash.location < 16) title = [name substringFromIndex:dash.location + 1];
        [rows addObject:@{@"title": title}];
    }
    return rows;
}
- (void)addSelectedSaved {
    NSArray *order = [self.savedPicked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    if (!order.count) { [self toast:@"Select a file"]; return; }
    for (NSNumber *index in order) {
        if (index.integerValue < 0 || index.integerValue >= (NSInteger)self.savedFiles.count) continue;
        NSString *name = self.savedFiles[(NSUInteger)index.integerValue];
        NSString *title = name;
        NSRange dash = [name rangeOfString:@"-"];
        if (dash.location != NSNotFound && dash.location < 16) title = [name substringFromIndex:dash.location + 1];
        BOOL video = [@[@"mp4", @"m4v", @"mov", @"mkv", @"webm"] containsObject:name.pathExtension.lowercaseString];
        [self.tracks addObject:[@{@"title": title, @"uri": name, @"kind": @"file", @"video": @(video)} mutableCopy]];
    }
    [self saveLibrary];
    [self.savedPicked removeAllObjects];
    [self toast:[NSString stringWithFormat:@"Added %lu", (unsigned long)order.count]];
    [self pop];
}
- (void)presentPicker:(NSArray *)types {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.allowsMultipleSelection = [self.pickKind isEqualToString:@"media"];
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    if ([self.pickKind isEqualToString:@"cookie"]) { [self importCookie:urls.firstObject]; return; }
    for (NSURL *url in urls) [self copyMedia:url];
    [self saveLibrary];
    [self show];
}
- (void)copyMedia:(NSURL *)url {
    BOOL access = [url startAccessingSecurityScopedResource];
    NSString *name = url.lastPathComponent.length ? url.lastPathComponent : @"Track";
    NSString *stored = [NSString stringWithFormat:@"%.0f-%@", [NSDate date].timeIntervalSince1970 * 1000, name];
    NSURL *dest = [[self tracksDirectory] URLByAppendingPathComponent:stored];
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:dest error:nil];
    if (access) [url stopAccessingSecurityScopedResource];
    BOOL video = [@[@"mp4", @"m4v", @"mov", @"mkv", @"webm"] containsObject:name.pathExtension.lowercaseString];
    [self.tracks addObject:[@{@"title": name, @"uri": stored, @"kind": @"file", @"video": @(video)} mutableCopy]];
}
- (void)importCookie:(NSURL *)url {
    if (!url) return;
    BOOL access = [url startAccessingSecurityScopedResource];
    NSString *name = url.lastPathComponent.length ? url.lastPathComponent : @"imported.txt";
    if (![name.lowercaseString hasSuffix:@".txt"]) name = [name stringByAppendingString:@".txt"];
    NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil] ?: @"";
    if (access) [url stopAccessingSecurityScopedResource];
    [text writeToFile:[[self cookiesDirectory] URLByAppendingPathComponent:name].path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.cookieName = name;
    [self saveTrim];
    [self toast:[@"Imported " stringByAppendingString:name]];
    [self show];
}
- (void)removeSong:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.tracks.count) return;
    NSString *title = self.tracks[(NSUInteger)index][@"title"] ?: @"this song";
    UIAlertController *ask = [UIAlertController alertControllerWithTitle:@"Remove this song?" message:title preferredStyle:UIAlertControllerStyleAlert];
    [ask addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ask addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self.tracks removeObjectAtIndex:(NSUInteger)index];
        if (self.currentTrack == index) {
            [self.player pause];
            [self.player replaceCurrentItemWithPlayerItem:nil];
            self.currentTrack = -1;
        } else if (self.currentTrack > index) {
            self.currentTrack -= 1;
        }
        [self saveLibrary];
        [self show];
    }]];
    [self presentViewController:ask animated:YES completion:nil];
}
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
- (void)createPlaylist {
    UIAlertController *ask = [UIAlertController alertControllerWithTitle:@"New playlist" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [ask addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Playlist name"; field.textColor = [self darkTheme] ? UIColor.whiteColor : UIColor.blackColor; }];
        if (@available(iOS 13.0, *)) ask.overrideUserInterfaceStyle = [self darkTheme] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    [ask addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ask addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = ask.textFields.firstObject.text.length ? ask.textFields.firstObject.text : @"New playlist";
        [self.playlists addObject:[@{@"name": name, @"tracks": [NSMutableArray array]} mutableCopy]];
        self.selected = (NSInteger)self.playlists.count - 1;
        self.currentTrack = -1;
        [self saveLibrary];
        [self push:1];
    }]];
    [self presentViewController:ask animated:YES completion:nil];
}
- (void)renamePlaylist {
    UIAlertController *ask = [UIAlertController alertControllerWithTitle:@"Rename" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [ask addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = self.currentPlaylist[@"name"]; field.textColor = [self darkTheme] ? UIColor.whiteColor : UIColor.blackColor; }];
        if (@available(iOS 13.0, *)) ask.overrideUserInterfaceStyle = [self darkTheme] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    [ask addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ask addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (ask.textFields.firstObject.text.length) self.currentPlaylist[@"name"] = ask.textFields.firstObject.text;
        [self saveLibrary];
        [self show];
    }]];
    [self presentViewController:ask animated:YES completion:nil];
}
- (void)deletePlaylist {
    if (self.playlists.count <= 1) { [self toast:@"Keep at least one playlist"]; return; }
    [self.playlists removeObjectAtIndex:self.selected];
    self.selected = 0;
    self.currentTrack = -1;
    [self.player pause];
    [self saveLibrary];
    if (self.page == 1) [self pop]; else [self show];
}

- (NSURL *)tracksDirectory { NSURL *docs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject; NSURL *dir = [docs URLByAppendingPathComponent:@"Tracks"]; [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil]; return dir; }
- (NSURL *)cookiesDirectory { NSURL *docs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject; NSURL *dir = [docs URLByAppendingPathComponent:@"Cookies"]; [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil]; return dir; }

- (void)loadLibrary {
    NSData *data = [[[NSUserDefaults standardUserDefaults] stringForKey:@"library-v2"] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *root = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
    if ([root isKindOfClass:NSDictionary.class]) {
        self.playlists = [root[@"playlists"] mutableCopy] ?: [NSMutableArray array];
        self.selected = [root[@"selected"] integerValue];
        self.currentTrack = [root[@"currentTrack"] integerValue];
        self.repeatMode = (int)[root[@"repeatMode"] integerValue];
        self.shuffle = [root[@"shuffle"] boolValue];
    } else self.playlists = [NSMutableArray array];
    if (!self.playlists.count) [self.playlists addObject:[@{@"name": @"My playlist", @"tracks": [NSMutableArray array]} mutableCopy]];
    for (NSMutableDictionary *playlist in self.playlists) if (![playlist[@"tracks"] isKindOfClass:NSMutableArray.class]) playlist[@"tracks"] = [playlist[@"tracks"] mutableCopy] ?: [NSMutableArray array];
    if (self.selected >= (NSInteger)self.playlists.count) self.selected = 0;
}
- (void)saveLibrary {
    NSDictionary *root = @{@"selected": @(self.selected), @"currentTrack": @(self.currentTrack), @"repeatMode": @(self.repeatMode), @"shuffle": @(self.shuffle), @"playlists": self.playlists ?: @[]};
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data) [[NSUserDefaults standardUserDefaults] setObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:@"library-v2"];
}
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

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = [[TrimPlaylistViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); } }
