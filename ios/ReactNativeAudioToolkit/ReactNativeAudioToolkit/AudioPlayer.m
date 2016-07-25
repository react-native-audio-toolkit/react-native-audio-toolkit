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
        
    // Try to find the correct file
    NSURL *url = [self findUrlForPath:path];
    if (!url) {
        NSDictionary* dict = [Helpers errObjWithCode:@"invalidpath" withMessage:@"No file found at path"];
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
    // Wait until player is ready
    while (player.status == AVPlayerStatusUnknown) {
        [NSThread sleepForTimeInterval:0.01f];
    }
    
    // Callback when ready / failed
    if (player.status == AVPlayerStatusReadyToPlay) {
        callback(@[[NSNull null]]);
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
    AVPlayer* player = [self playerForKey:playerId];
    
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
    AVPlayer* player = [self playerForKey:playerId];
    
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
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %@ not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player play];
    
    callback(@[[NSNull null]]);
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


@end
