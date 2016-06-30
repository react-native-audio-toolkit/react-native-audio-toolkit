//
//  AudioPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AudioPlayer.h"

@interface AudioPlayer ()

@property (nonatomic, strong) AVAudioPlayer *player;

@end

@implementation AudioPlayer

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(playAudioWithFilename:(NSString *)filename) {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  
  NSString *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, filename];
  [self playAudioWithURL:[NSURL URLWithString:filePath]];
}

RCT_EXPORT_METHOD(playAudioWithPath:(NSString *)path) {
  [self playAudioWithURL:[NSURL URLWithString:path]];
}

RCT_EXPORT_METHOD(stopPlayback) {
  [self stopPlaying];
}

- (void)playAudioWithURL:(NSURL *)url {
  // Set session active
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *error = nil;
  [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
  if (error) {
    NSLog (@"Failed to set session category");
    return;
  }
  
  [audioSession setActive:YES error:&error];
  if (error) {
    NSLog (@"Could not set session active.");
    return;
  }
  
  _player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
  
  if (error) {
    NSLog(@"Initializing player failed");
    return;
  }
  
  [_player play];
}

- (void)stopPlaying {
  [_player stop];
  _player = nil;
}

@end
