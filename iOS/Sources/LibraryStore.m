#import "TrimPlaylistViewController.h"

@implementation TrimPlaylistViewController (LibraryStore)

- (NSMutableDictionary *)currentPlaylist { if (self.selected < 0 || self.selected >= (NSInteger)self.playlists.count) self.selected = 0; return self.playlists[self.selected]; }

- (NSMutableArray *)tracks { return self.currentPlaylist[@"tracks"]; }

- (NSDictionary *)currentSong { return (self.currentTrack >= 0 && self.currentTrack < (NSInteger)self.tracks.count) ? self.tracks[self.currentTrack] : nil; }

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
@end
