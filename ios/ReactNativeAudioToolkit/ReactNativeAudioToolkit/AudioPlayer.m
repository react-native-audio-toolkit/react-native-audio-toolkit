//
//  AudioPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016 Futurice.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "AudioPlayer.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"

@interface AudioPlayer () <AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioPlayer *player;

@end

@implementation AudioPlayer {
    NSMutableDictionary* _playerPool;
}

-(NSMutableDictionary*) playerPool {
  if (!_playerPool) {
    _playerPool = [NSMutableDictionary new];
  }
  return _playerPool;
}

-(AVAudioPlayer*) playerForKey:(nonnull NSNumber*)key {
  return [[self playerPool] objectForKey:key];
}

-(NSNumber*) keyForPlayer:(nonnull AVAudioPlayer*)player {
  return [[[self playerPool] allKeysForObject:player] firstObject];
}

@synthesize bridge = _bridge;

#pragma mark React exposed methods

RCT_EXPORT_MODULE();
/*
RCT_EXPORT_METHOD(playLocal:(NSString *)filename) {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  
  NSString *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, filename];
  [self playAudioWithURL:[NSURL URLWithString:filePath]];
}*/

-(NSDictionary*) errObjWithCode:(NSInteger)code
             withMessage:(NSString*)message {
    NSDictionary *err = @{
      @"code": [NSNumber numberWithInt:code],
      @"message": message,
      @"stackTrace": [NSThread callStackSymbols]
    };

    return err;
 }

RCT_EXPORT_METHOD(init:(nonnull NSNumber*)playerId withPath:(NSString* _Nullable)path withCallback:(RCTResponseSenderBlock)callback) {
  if ([path length] == 0) {
    NSDictionary* dict = [self errObjWithCode:-1 withMessage:@"Provided path was empty"];
    callback(@[dict]);
  }

  path = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], path];

  NSError* error;
  AVAudioPlayer* player = [[AVAudioPlayer alloc]
                           initWithContentsOfURL:[NSURL fileURLWithPath:[path stringByRemovingPercentEncoding]]
                           error:&error];

  if (player) {
    player.delegate = self;
    [[self playerPool] setObject:player forKey:playerId];

    callback(@[[NSNull null]]);
  } else {
    callback(@[RCTJSErrorFromNSError(error)]);
  }
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber*)playerId) {
  AVAudioPlayer* player = [self playerForKey:playerId]; if (player) {
    [player stop];
    [[self playerPool] removeObjectForKey:playerId];
  }
}

RCT_EXPORT_METHOD(prepare:(nonnull NSNumber*)playerId withPos:(nonnull NSNumber*)position withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:playerId];

  if (!player) {
    NSDictionary* dict = [self errObjWithCode:-1 withMessage:@"playerId TODO not found."];
    callback(@[dict]);
    return;
  }

  if (position != -1) {
    [player pause];
    [player setCurrentTime:[position doubleValue]];
  }

  [player prepareToPlay];

  callback(@[[NSNull null], @{@"duration": @(player.duration),
                            @"position": @(player.currentTime * 1000)}]);
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:playerId];

  if (!player) {
    NSDictionary* dict = [self errObjWithCode:-1 withMessage:@"playerId TODO not found."];
    callback(@[dict]);
    return;
  }

  [player play];
  callback(@[[NSNull null], @{@"duration": @(player.duration),
                            @"position": @(player.currentTime * 1000)}]);
}

RCT_EXPORT_METHOD(set:(nonnull NSNumber*)playerId withOpts:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:playerId];

  if (!player) {
    NSDictionary* dict = [self errObjWithCode:-1 withMessage:@"playerId TODO not found."];
    callback(@[dict]);
    return;
  }

  float volume = [[options objectForKey:@"volume"] floatValue];
  if (volume) {
      [player setVolume:volume];
  }

  callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(stop) {
  if (_player.isPlaying) {
    [self stopPlaying];
  } else {
    NSString *errorDescription = [NSString stringWithFormat:@"Cannot stop when no audio playing."];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];

  }
}

RCT_EXPORT_METHOD(pause) {
  if (_player.isPlaying) {
    [_player pause];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:resume"
                                                    body:@{@"status": @"Playback paused"}];

  } else {
    NSString *errorDescription = [NSString stringWithFormat:@"Cannot pause when no audio playing."];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];
  }
}

RCT_EXPORT_METHOD(resume) {
  if (_player && !_player.playing) {
    [_player play];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:play"
                                                    body:@{}];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:playing"
                                                    body:@{}];
  } else {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                    body:@{@"error": @"RCTAudioPlayer: Cannot resume when not paused"}];
  }
}




#pragma mark Audio

- (void)prepareWithURL:(NSURL *)url {
    if (url == nil) {
        NSString *errorDescription = [NSString stringWithFormat:@"Path to file was malformed."];
        [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                        body:@{@"error": errorDescription}];
        return;
    }
    
    
}

- (void)playAudioWithURL:(NSString *)url {
  if (url == nil) {
    NSString *errorDescription = [NSString stringWithFormat:@"Path to file was malformed."];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];
    return;
  }
    
  // Set session active
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *error = nil;
  [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
  if (error) {
    NSString *errorDescription = [NSString stringWithFormat:@"Failed to set audio session category: %@", [error description]];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];

    return;
  }
  
  [audioSession setActive:YES error:&error];
  if (error) {
    NSString *errorDescription = [NSString stringWithFormat:@"Failed to set audio session active: %@", [error description]];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];

    return;
  }
    
    url = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], url];

  NSLog(url);
  _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:url] error:&error];

  if (error) {
    NSString *errorDescription = [NSString stringWithFormat:@"Player initialization failed: %@", [error description]];
      NSLog(errorDescription);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];

    return;
  }
  _player.delegate = self;
  [_player play];
  
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:playing"
                                                  body:@{@"status": @"Playback started"}];

}

- (void)stopPlaying {
  [_player stop];
  
}

#pragma mark Audio Delegates

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {
  
  _player = nil;

  NSLog (@"RCTAudioPlayer: Playing finished, successful: %d", flag);
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:ended"
                                                  body:@{@"status": @"Finished playback"}];
  
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *error = nil;
  [audioSession setActive:NO error:&error];
  
  if (error) {
    NSLog (@"RCTAudioPlayer: Could not deactivate current audio session. Error: %@", error);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": [error description]}];
    return;
  }


}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error {
  
  NSString *errorDescription = [NSString stringWithFormat:@"Decoding error during playback: %@", [error description]];
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                  body:@{@"error": errorDescription}];
}


@end
