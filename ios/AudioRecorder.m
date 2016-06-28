//
//  AudioManager.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AudioRecorder.h"

@interface AudioRecorder () <AVAudioRecorderDelegate>

@property (nonatomic, strong) NSURL *recordPath;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioSession *audioSession;

@end

@implementation AudioRecorder 

#pragma mark - React exposed functions

RCT_EXPORT_MODULE(@"AudioRecorder");

RCT_EXPORT_METHOD(startRecordingToFilename:(NSString *)filename) {
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  
  NSString *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, filename];
  [self prepareAndStartRecordingToPath:[NSURL URLWithString:filePath]];

}

RCT_EXPORT_METHOD(startRecording:(NSString *)path) {
  if (path == nil) return;
  [self prepareAndStartRecordingToPath:[NSURL URLWithString:path]];
}

RCT_EXPORT_METHOD(stopRecording) {
  [self stopCurrentRecording];
}

#pragma mark - Main functions

- (void)prepareAndStartRecordingToPath:(NSURL *)path {
  _recordPath = path;
  
  _audioSession = [AVAudioSession sharedInstance];
  NSError *error = nil;
  [_audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
  if (error) {
    NSLog (@"Failed to set session category");
    return;
  }
  
  [_audioSession setActive:YES error:&error];
  if (error) {
    NSLog (@"Could not set session active.");
    return;
  }
  
  NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
  
  [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
  [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
  [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
  
  [recordSetting setValue :[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
  [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
  [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];

  _recorder = [[AVAudioRecorder alloc] initWithURL:_recordPath settings:recordSetting error:&error];
  
  if (error) {
    NSLog (@"Allocating recorder failed. Settings are probably wrong.");
    return;
  } else if (!_recorder) {
    NSLog (@"Recorder failed to initialize.");
    return;
  }
  
  _recorder.delegate = self;
  [_recorder prepareToRecord];
  
  // start recording
  [_recorder record];
  
}

- (void)stopCurrentRecording {
  [_recorder stop];
  _recorder = nil;
  
  NSError *error = nil;
  [_audioSession setActive:NO error:&error];
  
  if (error) {
    NSLog (@"Could not deactivate current audio session.");
    return;
  }
  
}

#pragma mark - Delegate methods
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag {
  
  NSLog (@"Recording finished");
  // your actions here
  
}

@end
