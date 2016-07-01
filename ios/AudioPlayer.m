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
  [self stopPlaying];
}

RCT_EXPORT_METHOD(pause) {
  [_player pause];
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
  _player = nil;
  
}

#pragma mark Audio Delegates

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {
  
  NSLog (@"RCTAudioPlayer: Playing finished, successful: %d", flag);
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:ended"
                                                  body:@{@"path": [_playbackPath absoluteString]}];

}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error {
  
  NSString *errorDescription = [NSString stringWithFormat:@"Decoding error during playback: %@", [error description]];
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                  body:@{@"error": errorDescription}];
}


@end
