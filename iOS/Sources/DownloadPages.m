#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (DownloadPages)

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
@end
