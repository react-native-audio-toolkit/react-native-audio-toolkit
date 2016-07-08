//
//  AudioManager.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016 Futurice.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "AudioRecorder.h"
#import "RCTEventDispatcher.h"

@import AVFoundation;

@interface AudioRecorder () <AVAudioRecorderDelegate>

@property (nonatomic, strong) NSURL *recordPath;
@property (nonatomic, strong) AVAudioRecorder *recorder;

@end

@implementation AudioRecorder

@synthesize bridge = _bridge;

#pragma mark - React exposed functions

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(recordLocal:(NSString *)filename) {
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  
  NSString *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, filename];
  [self prepareAndStartRecordingToPath:[NSURL URLWithString:filePath]];

}

RCT_EXPORT_METHOD(record:(NSString *)path) {
  if (path == nil) return;
  [self prepareAndStartRecordingToPath:[NSURL URLWithString:path]];
}

RCT_EXPORT_METHOD(stop) {
  [self stopCurrentRecording];
}

RCT_EXPORT_METHOD(pause) {
  if (_recorder.recording) {
    [_recorder pause];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:pause"
                                                 body:@{}];
  } else {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                 body:@{@"error": @"RCTAudioRecorder: Cannot pause when not recording"}];
  }
}

RCT_EXPORT_METHOD(resume) {
  if (_recorder && !_recorder.recording) {
    [_recorder record];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:resume"
                                                 body:@{}];
  } else {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                 body:@{@"error": @"RCTAudioRecorder: Cannot resume when not recording or paused"}];
  }
}

#pragma mark - Main functions

- (void)prepareAndStartRecordingToPath:(NSURL *)path {
  _recordPath = path;
  
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *error = nil;
  [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
  if (error) {
    NSLog (@"RCTAudioRecorder: Failed to set session category");
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                 body:@{@"error": [error description]}];

    return;
  }
  
  [audioSession setActive:YES error:&error];
  if (error) {
    NSLog (@"RCTAudioRecorder: Could not set session active.");
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                 body:@{@"error": [error description]}];

    return;
  }
  
  NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
  
  [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
  [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
  [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
  
  [recordSetting setValue :[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
  [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
  [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];

  _recorder = [[AVAudioRecorder alloc] initWithURL:_recordPath settings:recordSetting error:&error];
  if (error) {
    NSLog (@"RCTAudioRecorder: Allocating recorder failed. Settings are probably wrong. Error: %@", error);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                 body:@{@"error": [error description]}];

    return;
  } else if (!_recorder) {
    NSLog (@"RCTAudioRecorder: Recorder failed to initialize. Error: %@", error);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                 body:@{@"error": [error description]}];

    return;
  }
  
  _recorder.delegate = self;
  [_recorder prepareToRecord];
  
  // start recording
  [_recorder record];
  
  // Send event
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:start"
                                               body:@{@"path": [_recordPath absoluteString]}];
  
}

- (void)stopCurrentRecording {
  [_recorder stop];
}

#pragma mark - Delegate methods
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag {
  NSLog (@"RCTAudioRecorder: Recording finished, successful: %d", flag);
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:ended"
                                                 body:@{@"path": [_recordPath absoluteString]}];
  
  _recorder = nil;
  
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *error = nil;
  [audioSession setActive:NO error:&error];
  
  if (error) {
    NSLog (@"RCTAudioRecorder: Could not deactivate current audio session. Error: %@", error);
    // Send event
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                                    body:@{@"error": [error description]}];
    return;
  }

}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                               body:@{@"error": [error description]}];
}

@end
