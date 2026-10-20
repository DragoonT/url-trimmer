#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (PlaylistPages)

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
@end
