#import "TrimPlaylistViewController.h"

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
