//
//  AudioPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AudioPlayer.h"
#import "RCTEventDispatcher.h"

@interface AudioPlayer () <AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSURL *playbackPath;

@end

@implementation AudioPlayer

@synthesize bridge = _bridge;

#pragma mark React exposed methods

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(playLocal:(NSString *)filename) {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  
  NSString *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, filename];
  [self playAudioWithURL:[NSURL URLWithString:filePath]];
}

RCT_EXPORT_METHOD(play:(NSString *)path) {
  [self playAudioWithURL:[NSURL URLWithString:path]];
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
                                                    body:@{}];

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

- (void)playAudioWithURL:(NSURL *)url {
  if (url == nil) {
    NSString *errorDescription = [NSString stringWithFormat:@"Path to file was malformed."];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];
    return;
  }
  _playbackPath = url;
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
  
  _player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
  
  if (error) {
    NSString *errorDescription = [NSString stringWithFormat:@"Player initialization failed: %@", [error description]];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                    body:@{@"error": errorDescription}];

    return;
  }
  _player.delegate = self;
  [_player play];
  
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:playing"
                                                  body:@{@"path": [_playbackPath absoluteString]}];

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
                                                  body:@{@"path": [_playbackPath absoluteString]}];
  
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
