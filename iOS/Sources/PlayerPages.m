#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (PlayerPages)

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
@end
