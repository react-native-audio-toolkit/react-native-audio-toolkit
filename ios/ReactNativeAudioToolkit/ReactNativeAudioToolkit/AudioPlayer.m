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

#pragma mark React exposed methods

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(nonnull NSNumber*)playerId withPath:(NSString* _Nullable)path withCallback:(RCTResponseSenderBlock)callback) {
    if ([path length] == 0) {
        NSDictionary* dict = [Helpers errObjWithCode:@"nopath" withMessage:@"Provided path was empty"];
        callback(@[dict]);
        return;
    }
    
    //path = @"drumsticks.mp3";
    NSString *fileWithoutExtension = [path stringByDeletingPathExtension];
    NSString *extension = [path pathExtension];
    NSURL *url;
    NSString *urlString = [[NSBundle mainBundle] pathForResource:fileWithoutExtension ofType:extension];
    if (urlString) {
        url = [NSURL fileURLWithPath:urlString];
    } else {
        url = [NSURL fileURLWithPath:path];
    }
    
    /*
    NSString* mainBundle = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], path];
    BOOL isDir = NO;
    NSFileManager* fm = [[NSFileManager alloc] init];
    if ([fm fileExistsAtPath:mainBundle isDirectory:isDir]) {
        url = [NSURL fileURLWithPath:mainBundle];
    } else {
        url = [NSURL URLWithString:path];
        if (!url) {
            NSDictionary* dict = [Helpers errObjWithCode:@"notfound" withMessage:@"No file found or invalid path"];
            callback(@[dict]);
        }
    }
     */
    
    AVURLAsset *asset = [AVURLAsset assetWithURL: url];
    ReactPlayerItem *item = [ReactPlayerItem playerItemWithAsset: asset];
    item.reactPlayerId = playerId;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: &error];
    if (error) {
        NSDictionary* dict = [Helpers errObjWithCode:@"initfail"
                                         withMessage:
                              [NSString stringWithFormat:@"Failed to set audio session category.", playerId]];
        callback(@[dict]);
        return;
    }
    
    ReactPlayer* player = [[ReactPlayer alloc]
                        initWithPlayerItem:item];
    

    //initWithURL:[NSURL fileURLWithPath:[path stringByRemovingPercentEncoding]]];
    //error:&error];
    
    //initWithContentsOfURL:
    if (player && !error) {
        [[self playerPool] setObject:player forKey:playerId];
        
        callback(@[[NSNull null]]);
    } else {
        callback(@[RCTJSErrorFromNSError(error)]);
    }
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber*)playerId) {
    [self destroyPlayerWithId:playerId];
}

RCT_EXPORT_METHOD(prepare:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    while (player.status == AVPlayerStatusUnknown) {
        [NSThread sleepForTimeInterval:0.01f];
    }
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

RCT_EXPORT_METHOD(seek:(nonnull NSNumber*)playerId withPos:(nonnull NSNumber*)position withCallback:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null]]);
    return;
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player cancelPendingPrerolls];
    
    if (position >= 0) {
        NSLog(@"%d", position);
        if (position == 0) {
            [player.currentItem
             seekToTime:kCMTimeZero
             toleranceBefore:kCMTimeZero // for precise positioning
             toleranceAfter:kCMTimeZero
             completionHandler:^(BOOL finished) {
                 callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                             @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
             }];
        } else {
            [player.currentItem
             seekToTime:CMTimeMakeWithSeconds([position doubleValue] / 1000, 60000)
             completionHandler:^(BOOL finished) {
                 callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                             @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
             }];
        }
    }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player play];
    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
}

RCT_EXPORT_METHOD(set:(nonnull NSNumber*)playerId withOpts:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer *player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    float volume = [[options objectForKey:@"volume"] floatValue];
    if (volume) {
        [player setVolume:volume];
    }
    
    NSNumber *autoDestroy = [options objectForKey:@"autoDestroy"];
    if (!autoDestroy) {
        // Default to destroy automatically
        autoDestroy = @1;
    }
    player.autoDestroy = [autoDestroy boolValue];
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    ReactPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player pause];
    if (player.autoDestroy) {
        [self destroyPlayerWithId:playerId];
    } else {
        [player.currentItem seekToTime:CMTimeMakeWithSeconds(0.0, 60000)];
    }
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player pause];
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(resume:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player play];
    
    callback(@[[NSNull null]]);
}


-(void)itemDidFinishPlaying:(NSNotification *) notification {
    NSNumber *playerId = ((ReactPlayerItem *)notification.object).reactPlayerId;
    ReactPlayer *player = [self playerForKey:playerId];
    if (player.autoDestroy) {
        [self destroyPlayerWithId:playerId];
        player = nil;
    }
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:ended"
                                                    body:@{@"status": @"Finished playback",
                                                           @"id" : playerId}];
}

- (void)destroyPlayerWithId:(NSNumber *)playerId {
    ReactPlayer *player = [self playerForKey:playerId];
    if (player) {
        [player pause];
        [[self playerPool] removeObjectForKey:playerId];

    }
}
/*
 
 - (void)audioPlayerDecodeErrorDidOccur:(AVPlayer *)player
 error:(NSError *)error {
 
 NSString *errorDescription = [NSString stringWithFormat:@"Decoding error during playback: %@", [error description]];
 [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
 body:@{@"error": errorDescription}];
 }
 
 */
