//
//  AudioPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
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


@interface AudioPlayer ()

@property (nonatomic, strong) NSMutableDictionary *playerPool;

@end

@implementation AudioPlayer

@synthesize bridge = _bridge;


-(NSMutableDictionary*) playerPool {
    if (!_playerPool) {
        _playerPool = [NSMutableDictionary new];
    }
    return _playerPool;
}

-(AVPlayer*) playerForKey:(nonnull NSNumber*)key {
    return [_playerPool objectForKey:key];
}

-(NSNumber*) keyForPlayer:(nonnull AVPlayer*)player {
    return [[_playerPool allKeysForObject:player] firstObject];
}

- (void)dealloc {
    for (ReactPlayer *player in [self playerPool]) {
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
            NSString* mainBundle = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], path];
            BOOL isDir = NO;
            NSFileManager* fm = [NSFileManager defaultManager];
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
RCT_EXPORT_METHOD(prepare:(nonnull NSNumber*)playerId
                  withPath:(NSString* _Nullable)path
                  withOptions:(NSDictionary *)options
                  withCallback:(RCTResponseSenderBlock)callback)
{
    if ([path length] == 0) {
        NSDictionary* dict = [Helpers errObjWithCode:@"invalidpath" withMessage:@"Provided path was empty"];
        callback(@[dict]);
        return;
    }

    ReactPlayerItem *item;
    if ([path hasPrefix:@"data:audio/"]) {
        // Inline data
        NSData *data = [Helpers decodeBase64DataUrl:path];
        if (!data) {
            NSDictionary* dict = [Helpers errObjWithCode:@"invalidpath" withMessage:@"Invalid data:audio URL"];
            callback(@[dict]);
            return;
        }
        item = (ReactPlayerItem *)[ReactPlayerItem playerItemWithData: data];
     } else {
        // Try to find the correct file
        NSURL *url = [self findUrlForPath:path];
        if (!url) {
            NSDictionary* dict = [Helpers errObjWithCode:@"invalidpath" withMessage:@"No file found at path"];
            callback(@[dict]);
            return;
        }
        item = (ReactPlayerItem *)[ReactPlayerItem playerItemWithURL: url];
    }
    if (!item) {
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail" withMessage:@"Error initializing player item"];
        callback(@[dict]);
        return;
    }
    item.reactPlayerId = playerId;
    
    // Add notification to know when file has stopped playing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
    
    // Set audio session
    NSNumber *category = [options objectForKey:@"category"];
    NSString *avAudioSessionCategory;
    switch ([category intValue]) {
        case 1:
        default:
            avAudioSessionCategory = AVAudioSessionCategoryPlayback;
            break;
        case 2:
            avAudioSessionCategory = AVAudioSessionCategoryAmbient;
            break;
        case 3:
            avAudioSessionCategory = AVAudioSessionCategorySoloAmbient;
            break;
    }
    NSNumber *mixWithOthers = [options objectForKey:@"mixWithOthers"];
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory: avAudioSessionCategory withOptions: mixWithOthers.intValue > 0 ? AVAudioSessionCategoryOptionMixWithOthers : 0 error: &error];
    if (error) {
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:@"Failed to set audio session category."];
        callback(@[dict]);
        return;
    }
    
    // Initialize player
    ReactPlayer* player = [[ReactPlayer alloc]
                        initWithPlayerItem:item];
    
    // If successful, check options and add to player pool
    if (player) {
        NSNumber *autoDestroy = [options objectForKey:@"autoDestroy"];
        if (autoDestroy) {
            player.autoDestroy = [autoDestroy boolValue];
        }

        [[self playerPool] setObject:player forKey:playerId];
    } else {
        NSString *errMsg = [NSString stringWithFormat:@"Could not initialize player, error: %@", error];
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:errMsg];
        callback(@[dict]);
        return;
    }
    
    // Prepare the player
    // Wait until player is ready or has failed
    while (player.status == AVPlayerStatusUnknown) {
        [NSThread sleepForTimeInterval:0.01f];
    }

    if (player.status == AVPlayerStatusFailed) {
        NSString *errMsg = [NSString stringWithFormat:@"Could not initialize player, error: %@", player.error];
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:errMsg];
        callback(@[dict]);
        return;
    }

    // Wait until player's current item is ready or has failed
    while (player.currentItem.status == AVPlayerItemStatusUnknown) {
        [NSThread sleepForTimeInterval:0.01f];
    }

    if (player.currentItem.status == AVPlayerItemStatusFailed) {
        NSString *errMsg = [NSString stringWithFormat:@"Could not initialize player, error: %@", player.currentItem.error];
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:errMsg];
        callback(@[dict]);
        return;
    }

    //make sure loadedTimeRanges is not null
    while (player.currentItem.loadedTimeRanges.firstObject == nil){
        [NSThread sleepForTimeInterval:0.01f];
    }
    
    //wait until 10 seconds are buffered then play
    float version = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (version >= 10.0) {
        player.currentItem.preferredForwardBufferDuration = 500;
    }
    if (version >= 10.0) {
        player.automaticallyWaitsToMinimizeStalling = false;
    }
    Float64 loadedDurationSeconds = 0;
    Float64 totalDurationSeconds = CMTimeGetSeconds(player.currentItem.duration);
    while (loadedDurationSeconds < 10 && loadedDurationSeconds < totalDurationSeconds){
        NSValue *val = player.currentItem.loadedTimeRanges.firstObject;
        CMTimeRange timeRange;
        [val getValue:&timeRange];
        loadedDurationSeconds = CMTimeGetSeconds(timeRange.duration);
        [NSThread sleepForTimeInterval:0.01f];
    }
    
    // Callback when ready / failed
    if (player.currentItem.status == AVPlayerStatusReadyToPlay) {
        player.automaticallyWaitsToMinimizeStalling = false;
        callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000)}]);
    } else {
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:[NSString stringWithFormat:@"Preparing player failed"]];
        
        if (player.autoDestroy) {
            [self destroyPlayerWithId:playerId];
        }
        
        callback(@[dict]);
    }
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    [self destroyPlayerWithId:playerId];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(seek:(nonnull NSNumber*)playerId withPos:(nonnull NSNumber*)position withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = (ReactPlayer *)[self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player cancelPendingPrerolls];
    
    if (position >= 0) {
        NSLog(@"%@", position);
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
    ReactPlayer* player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player play];
    player.rate = player.speed;

    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
}

RCT_EXPORT_METHOD(set:(nonnull NSNumber*)playerId withOpts:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer *player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    NSNumber *volume = [options objectForKey:@"volume"];
    if (volume) {
        [player setVolume:[volume floatValue]];
    }

    NSNumber *looping = [options objectForKey:@"looping"];
    if (looping) {
        player.looping = [looping boolValue];
    }

    NSNumber *speed = [options objectForKey:@"speed"];
    if (speed) {
        // Internal variable for usage later
        player.speed = [speed floatValue];

        // If the player wasn't already playing, then setting the speed value to a non-zero value
        // will start it playing and we don't want that
        if (player.rate != 0.0f) {
            player.rate = player.speed;
        }
    }

    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = (ReactPlayer *)[self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
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
    ReactPlayer* player = (ReactPlayer *)[self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player pause];

    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
}

RCT_EXPORT_METHOD(resume:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    [player play];
    player.rate = player.speed;

    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = (ReactPlayer *)[self playerForKey:playerId];

    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }

    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration) * 1000),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
}

-(void)itemDidFinishPlaying:(NSNotification *) notification {
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
    if (player && player.looping) {
        // Send looping event and start playing again
        NSString *eventName = [NSString stringWithFormat:@"RCTAudioPlayerEvent:%@", playerId];
        [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                     body:@{@"event": @"looped",
                                                            @"data" : [NSNull null]
                                                            }];
        [player play];
        player.rate = player.speed;
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

@end
