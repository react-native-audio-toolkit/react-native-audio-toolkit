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
#import "Helpers.h"

@import AVFoundation;

@interface AudioRecorder () <AVAudioRecorderDelegate>

@property (nonatomic, strong) NSMutableDictionary *recorderPool;

@end

@implementation AudioRecorder

@synthesize bridge = _bridge;

- (void)dealloc {
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

-(NSMutableDictionary*) recorderPool {
    if (!_recorderPool) {
        _recorderPool = [NSMutableDictionary new];
    }
    return _recorderPool;
}

#pragma mark - React exposed functions

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(nonnull NSNumber *)recorderId withPath:(NSString * _Nullable)path withOptions:(NSDictionary *)options withCallback:(RCTResponseSenderBlock)callback) {
    if ([path length] == 0) {
        NSDictionary* dict = [Helpers errObjWithCode:@"nopath" withMessage:@"Provided path was empty"];
        callback(@[dict]);
        return;
    } else if ([[self recorderPool] objectForKey:recorderId]) {
        NSDictionary* dict = [Helpers errObjWithCode:@"invalidid" withMessage:@"Recorder with that id already exists"];
        callback(@[dict]);
        return;
    }
    
    NSURL *url;
    
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], path];
    
    url = [NSURL URLWithString:[bundlePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    // Initialize audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    if (error) {
        NSDictionary* dict = [Helpers errObjWithCode:@"initfail" withMessage:@"Failed to set audio session category"];
        callback(@[dict]);
        
        return;
    }
    
    // Set audio session active
    [audioSession setActive:YES error:&error];
    if (error) {
        NSDictionary* dict = [Helpers errObjWithCode:@"initfail" withMessage:@"Could not set audio session active"];
        callback(@[dict]);
        
        return;
    }
    
    // Settings for the recorder
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    
    [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    
    [recordSetting setValue :[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
    [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];

    // Initialize a new recorder
    AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSetting error:&error];
    if (error) {
        NSDictionary* dict = [Helpers errObjWithCode:@"initfail" withMessage:@"Failed to initialize recorder"];
        callback(@[dict]);
        return;
        
        return;
    } else if (!recorder) {
        NSDictionary* dict = [Helpers errObjWithCode:@"initfail" withMessage:@"Failed to initialize recorder"];
        callback(@[dict]);
        
        return;
    }
    recorder.delegate = self;
    [[self recorderPool] setObject:recorder forKey:recorderId];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(set:(nonnull NSNumber *)recorderId withOptions:(NSDictionary *)options withCallback:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(prepare:(nonnull NSNumber *)recorderId withCallback:(RCTResponseSenderBlock)callback) {
    AVAudioRecorder *recorder = [[self recorderPool] objectForKey:recorderId];
    if (recorder) {
        BOOL success = [recorder prepareToRecord];
        if (!success) {
            NSDictionary* dict = [Helpers errObjWithCode:@"preparefail" withMessage:@"Failed to prepare recorder"];
            callback(@[dict]);
            return;
        }
    } else {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound" withMessage:@"Recorder with that id was not found"];
        callback(@[dict]);
        return;
    }
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(record:(nonnull NSNumber *)recorderId withCallback:(RCTResponseSenderBlock)callback) {
    AVAudioRecorder *recorder = [[self recorderPool] objectForKey:recorderId];
    if (recorder) {
        if (![recorder record]) {
            NSDictionary* dict = [Helpers errObjWithCode:@"preparefail" withMessage:@"Failed to start recorder"];
            callback(@[dict]);
            return;
        }
    } else {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound" withMessage:@"Recorder with that id was not found"];
        callback(@[dict]);
        return;
    }
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber *)recorderId withCallback:(RCTResponseSenderBlock)callback) {
    AVAudioRecorder *recorder = [[self recorderPool] objectForKey:recorderId];
    if (recorder) {
        [recorder stop];
    } else {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound" withMessage:@"Recorder with that id was not found"];
        callback(@[dict]);
        return;
    }
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber *)recorderId) {
    AVAudioRecorder *recorder = [[self recorderPool] objectForKey:recorderId];
    if (recorder) {
        [[self recorderPool] removeObjectForKey:recorderId];
    }
}

#pragma mark - Delegate methods
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag {
  NSLog (@"RCTAudioRecorder: Recording finished, successful: %d", flag);
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:ended"
                                                 body:@{}];
  
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error {
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioRecorder:error"
                                               body:@{@"error": [error description]}];
}

@end
