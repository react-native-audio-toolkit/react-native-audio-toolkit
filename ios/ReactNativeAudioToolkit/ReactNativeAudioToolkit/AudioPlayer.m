//
//  AudioPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016 Futurice.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "AudioPlayer.h"
#import "Helpers.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"
#import "ReactPlayer.h"
#import "ReactPlayerItem.h"
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVAsset.h>

@interface AudioPlayer ()

@property (nonatomic, strong) NSMutableDictionary *playerPool;
@property (nonatomic, strong) NSMutableDictionary *callbackPool;
@property (nonatomic, strong) NSNumber *lastPlayerId;

@end

@implementation AudioPlayer

@synthesize bridge = _bridge;

- (id)init {
    self = [super init];
    if (self != nil) {
        // Setting session and check if we got interrupted
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionInterruptionNotification:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:session];
        _callbackPool = [NSMutableDictionary new];
    }
    return self;
}

- (NSMutableDictionary *)playerPool {
    if (!_playerPool) {
        _playerPool = [NSMutableDictionary new];
    }
    return _playerPool;
}

- (ReactPlayer *)playerForKey:(nonnull NSNumber *)key {
    return _playerPool[key];
}

- (NSNumber *)keyForPlayer:(nonnull ReactPlayer *)player {
    return [[_playerPool allKeysForObject:player] firstObject];
}

- (void)setLastPlayerId:(nonnull NSNumber *)id {
    if (!_lastPlayerId) {
        _lastPlayerId = [NSNumber new];
    }

    _lastPlayerId = id;
}

- (NSNumber *)getLastPlayerId {
    return _lastPlayerId;
}

- (void)dealloc {
    for (ReactPlayer *player in [self playerPool]) {
        [player removeObserver:self forKeyPath:@"status"];

        NSNumber *playerId = [self keyForPlayer:player];
        [self destroyPlayerWithId:playerId];
    }
    _playerPool = nil;
}

- (NSURL *)findUrlForPath:(NSString *)path {
    NSURL *url = nil;

    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               path,
                               nil];

    NSString *possibleUrl = [NSString pathWithComponents:pathComponents];

    if (![[NSFileManager defaultManager] fileExistsAtPath:possibleUrl]) {
        NSString *fileWithoutExtension = [path stringByDeletingPathExtension];
        NSString *extension = [path pathExtension];
        NSString *urlString = [[NSBundle mainBundle] pathForResource:fileWithoutExtension ofType:extension];
        if (urlString) {
            url = [NSURL fileURLWithPath:urlString];
        } else {
            NSString *mainBundle = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], path];
            BOOL isDir = NO;
            NSFileManager *fm = [NSFileManager defaultManager];
            if ([fm fileExistsAtPath:mainBundle isDirectory:&isDir]) {
                url = [NSURL fileURLWithPath:mainBundle];
            } else {
                url = [NSURL URLWithString:path];
            }

        }
    } else {
        url = [NSURL fileURLWithPathComponents:pathComponents];
    }

    return url;
}

#pragma mark React exposed methods

RCT_EXPORT_MODULE();

// This method initializes and prepares the player
RCT_EXPORT_METHOD(prepare:(nonnull NSNumber *)playerId
                  withPath:(NSString * _Nullable)path
                  withOptions:(NSDictionary *)options
                  withCallback:(RCTResponseSenderBlock)callback) {
    if ([path length] == 0) {
        NSDictionary *dict = [Helpers errObjWithCode:@"invalidpath" withMessage:@"Provided path was empty"];
        callback(@[dict]);
        return;
    }

    // Try to find the correct file
    NSURL *url = [self findUrlForPath:path];
    if (!url) {
        NSDictionary *dict = [Helpers errObjWithCode:@"invalidpath" withMessage:@"No file found at path"];
        callback(@[dict]);
        return;
    }

    // Load asset from the url
    AVURLAsset *asset = [AVURLAsset assetWithURL: url];
    ReactPlayerItem *item = (ReactPlayerItem *)[ReactPlayerItem playerItemWithAsset: asset];
    item.reactPlayerId = playerId;

    // Add notification to know when file has stopped playing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];

    // Set audio session
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: &error];
    if (error) {
        NSDictionary *dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:@"Failed to set audio session category."];
        callback(@[dict]);
        return;
    }

    // Initialize player
    ReactPlayer *player = [[ReactPlayer alloc]
                        initWithPlayerItem:item];

    // If we don't set this property the player appears to play
    //(so we update currentTime etc) but the system has actually paused playback to buffer
    if ([player respondsToSelector:@selector(setAutomaticallyWaitsToMinimizeStalling:)]) {
        player.automaticallyWaitsToMinimizeStalling = NO;
    }

    // If successful, check options and add to player pool
    if (player) {
        NSNumber *autoDestroy = options[@"autoDestroy"];
        if (autoDestroy) {
            player.autoDestroy = [autoDestroy boolValue];
        }

        self.playerPool[playerId] = player;
        [self setLastPlayerId:playerId];

        [player addObserver:self
                 forKeyPath:@"currentItem.loadedTimeRanges"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
    } else {
        NSString *errMsg = [NSString stringWithFormat:@"Could not initialize player, error: %@", error];
        NSDictionary *dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:errMsg];
        callback(@[dict]);
        return;
    }

    // Save callback, we'll invoke it when the player is ready, which we get notified
    // of in observeValueForKeyPath: below
    self.callbackPool[playerId] = [callback copy];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem.loadedTimeRanges"]) {
        ReactPlayer *player = (ReactPlayer *)object;
        [self invokeCallbackForPlayerOnBuffering:player];
    }
}

- (void)invokeCallbackForPlayerOnBuffering:(ReactPlayer *)player {
    NSNumber *playerId = [self keyForPlayer:player];
    RCTResponseSenderBlock callback = self.callbackPool[playerId];

    CMTimeRange timeRange = player.currentItem.loadedTimeRanges.firstObject.CMTimeRangeValue;
    Float64 loadedSeconds = CMTimeGetSeconds(timeRange.duration);

    NSString *eventName = [NSString stringWithFormat:@"RCTAudioPlayerEvent:%@", playerId];
    [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                 body:@{@"event": @"buffering",
                                                        @"data" : @{@"loadedSeconds": @(loadedSeconds)}
                                                        }];


    // If theres no callback that means we've already called the callback
    // for this player, and have since disposed of it.
    if (!callback) {
        return;
    }

    if (loadedSeconds > 10) {
        callback(@[[NSNull null]]);
        self.callbackPool[playerId] = nil;
    } else if (player.status == AVPlayerStatusFailed) {
        NSDictionary *dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:[NSString stringWithFormat:@"Preparing player failed"]];

        if (player.autoDestroy) {
            [self destroyPlayerWithId:playerId];
        }

        callback(@[dict]);
        self.callbackPool[playerId] = nil;
    }
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    [self destroyPlayerWithId:playerId];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(seek:(nonnull NSNumber*)playerId withPos:(nonnull NSNumber*)position withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer *player = [self playerForKey:playerId];

    if (!player) {
        NSDictionary *dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player cancelPendingPrerolls];

    if (position >= 0) {
        if (position == 0) {
            [player.currentItem
             seekToTime:kCMTimeZero
             toleranceBefore:kCMTimeZero // for precise positioning
             toleranceAfter:kCMTimeZero
             completionHandler:^(BOOL finished) {
                 callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                             @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
             }];
        } else {
            [player.currentItem
             seekToTime:CMTimeMakeWithSeconds([position doubleValue] / 1000, 60000)
             completionHandler:^(BOOL finished) {
                 callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                             @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
             }];
        }
    }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer *player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary *dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player play];
    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);


}

RCT_EXPORT_METHOD(set:(nonnull NSNumber*)playerId withOpts:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer *player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary *dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    NSNumber *volume = options[@"volume"];
    if (volume) {
        [player setVolume:[volume floatValue]];
    }

    NSNumber *looping = options[@"looping"];
    if (looping) {
        player.looping = [looping boolValue];
    }

    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer *player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary *dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player pause];
    if (player.autoDestroy) {
        [self destroyPlayerWithId:playerId];
    } else {
        [player.currentItem seekToTime:CMTimeMakeWithSeconds(0.0, 60000)];
    }

    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer *player = [self playerForKey:playerId];

    if (!player) {
        NSDictionary *dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player pause];

    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);


    NSString *eventName = [NSString stringWithFormat:@"RCTAudioPlayerEvent:%@", playerId];
        [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                     body:@{@"event": @"pause",
                                                            @"data" : @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                                                        @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}
                                                            }];
}

RCT_EXPORT_METHOD(resume:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer *player = [self playerForKey:playerId];

    if (!player) {
        NSDictionary *dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player play];

    callback(@[[NSNull null]]);
}

- (void)itemDidFinishPlaying:(NSNotification *) notification {
    NSNumber *playerId = ((ReactPlayerItem *)notification.object).reactPlayerId;
    ReactPlayer *player = (ReactPlayer *)[self playerForKey:playerId];
    if (player.autoDestroy) {
        [self destroyPlayerWithId:playerId];
        player = nil;
    } else {
        [self seek:playerId withPos:@0 withCallback:^(NSArray *response) {
            return;
        }];
    }
    if (player.looping && player) {
        // Send looping event and start playing again
        NSString *eventName = [NSString stringWithFormat:@"RCTAudioPlayerEvent:%@", playerId];
        [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                     body:@{@"event": @"looped",
                                                            @"data" : [NSNull null]
                                                            }];
        [player play];

    } else {
        NSString *eventName = [NSString stringWithFormat:@"RCTAudioPlayerEvent:%@", playerId];
        [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                     body:@{@"event": @"ended",
                                                            @"data" : [NSNull null]
                                                            }];
    }
}

- (void)destroyPlayerWithId:(NSNumber *)playerId {
    ReactPlayer *player = (ReactPlayer *)[self playerForKey:playerId];
    if (player) {
        [player pause];
        [[self playerPool] removeObjectForKey:playerId];

    }
}

- (void)audioSessionInterruptionNotification:(NSNotification *)notification {
    // Check the type of notification, especially if you are sending multiple AVAudioSession events here
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {

        NSNumber *lastPlayerId = [self getLastPlayerId];
        ReactPlayer *player = (ReactPlayer *)[self playerForKey:lastPlayerId];

        //Check to see if it was a Begin interruption
        if ([[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] isEqualToNumber:[NSNumber numberWithInt:AVAudioSessionInterruptionTypeBegan]]) {
            // Stop audio

            NSString *eventName = [NSString stringWithFormat:@"RCTAudioPlayerEvent:%@", lastPlayerId];
            [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                         body:@{@"event": @"forcePause",
                                                                @"data" : @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                                                            @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}
                                                                }];

        } else if([[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] isEqualToNumber:[NSNumber numberWithInt:AVAudioSessionInterruptionTypeEnded]]){
            //Resume your audio


        }
    }
}

@end
