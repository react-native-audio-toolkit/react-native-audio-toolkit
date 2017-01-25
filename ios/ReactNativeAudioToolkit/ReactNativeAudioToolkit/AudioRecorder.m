//
//  AudioManager.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016 Futurice.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "AudioRecorder.h"
#import "React/RCTEventDispatcher.h"
//#import "RCTEventEmitter"
#import "Helpers.h"

@import AVFoundation;

@interface AudioRecorder () <AVAudioRecorderDelegate>

@property (nonatomic, strong) NSMutableDictionary *recorderPool;

@end

@implementation AudioRecorder{
    NSNumber *_audioRecorderId;
    id _progressUpdateTimer;
    int _progressUpdateInterval;
    NSDate *_prevProgressUpdateTime;
}

@synthesize bridge = _bridge;

- (void)dealloc {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setActive:NO error:&error];
    
    if (error) {
        NSLog (@"RCTAudioRecorder: Could not deactivate current audio session. Error: %@", error);
        return;
    }
}

- (NSMutableDictionary *) recorderPool {
    if (!_recorderPool) {
        _recorderPool = [NSMutableDictionary new];
    }
    return _recorderPool;
}

-(NSNumber *) keyForRecorder:(nonnull AVAudioRecorder*)recorder {
    return [[_recorderPool allKeysForObject:recorder] firstObject];
}

#pragma mark - React exposed functions

RCT_EXPORT_MODULE();


RCT_EXPORT_METHOD(prepare:(nonnull NSNumber *)recorderId
                  withPath:(NSString * _Nullable)filename
                  withOptions:(NSDictionary *)options
                  withCallback:(RCTResponseSenderBlock)callback)
{
    if ([filename length] == 0) {
        NSDictionary* dict = [Helpers errObjWithCode:@"invalidpath"
                                         withMessage:@"Provided path was empty"];
        callback(@[dict]);
        return;
    } else if ([[self recorderPool] objectForKey:recorderId]) {
        NSDictionary* dict = [Helpers errObjWithCode:@"invalidpath"
                                         withMessage:@"Recorder with that id already exists"];
        callback(@[dict]);
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:filename];
    
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    // Initialize audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    if (error) {
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail" withMessage:@"Failed to set audio session category"];
        callback(@[dict]);
        
        return;
    }
    
    // Set audio session active
    [audioSession setActive:YES error:&error];
    if (error) {
        NSString *errMsg = [NSString stringWithFormat:@"Could not set audio session active, error: %@", error];
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:errMsg];
        callback(@[dict]);
        
        return;
    }
    
    // Settings for the recorder
    NSDictionary *recordSetting = [Helpers recorderSettingsFromOptions:options];
    
    // Initialize a new recorder
    AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSetting error:&error];
    if (error) {
        NSString *errMsg = [NSString stringWithFormat:@"Failed to initialize recorder, error: %@", error];
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail"
                                         withMessage:errMsg];
        callback(@[dict]);
        return;
        
    } else if (!recorder) {
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail" withMessage:@"Failed to initialize recorder"];
        callback(@[dict]);
        
        return;
    }
    recorder.delegate = self;
    [[self recorderPool] setObject:recorder forKey:recorderId];
    
    BOOL success = [recorder prepareToRecord];
    if (!success) {
        [self destroyRecorderWithId:recorderId];
        NSDictionary* dict = [Helpers errObjWithCode:@"preparefail" withMessage:@"Failed to prepare recorder. Settings\
                              are probably wrong."];
        callback(@[dict]);
        return;
    }
    [self stopProgressTimer];
    callback(@[[NSNull null],@{@"filepath": filePath}]);
}

RCT_EXPORT_METHOD(record:(nonnull NSNumber *)recorderId withCallback:(RCTResponseSenderBlock)callback) {
    AVAudioRecorder *recorder = [[self recorderPool] objectForKey:recorderId];
    _audioRecorderId = recorderId;

    if (recorder) {
        if (![recorder record]) {
            NSDictionary* dict = [Helpers errObjWithCode:@"startfail" withMessage:@"Failed to start recorder"];
            callback(@[dict]);
            return;
        }

        [self startProgressTimer];
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
    [self stopProgressTimer];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber *)recorderId withCallback:(RCTResponseSenderBlock)callback) {
    [self destroyRecorderWithId:recorderId];
    [self stopProgressTimer];
    callback(@[[NSNull null]]);
}

#pragma mark - Delegate methods
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag {
    if ([[_recorderPool allValues] containsObject:aRecorder]) {
        NSNumber *recordId = [self keyForRecorder:aRecorder];
        [self destroyRecorderWithId:recordId];
    }
}

- (void)destroyRecorderWithId:(NSNumber *)recorderId {
    if ([[[self recorderPool] allKeys] containsObject:recorderId]) {
        AVAudioRecorder *recorder = [[self recorderPool] objectForKey:recorderId];
        if (recorder) {
            [recorder stop];
            [[self recorderPool] removeObjectForKey:recorderId];
            NSString *eventName = [NSString stringWithFormat:@"RCTAudioRecorderEvent:%@", recorderId];
            [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                                         body:@{@"event" : @"ended",
                                                                @"data" : [NSNull null]
                                                                }];
        }
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error {
    NSNumber *recordId = [self keyForRecorder:recorder];
    
    [self destroyRecorderWithId:recordId];
    NSString *eventName = [NSString stringWithFormat:@"RCTAudioRecorderEvent:%@", recordId];
    [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                               body:@{@"event": @"error",
                                                      @"data" : [error description]
                                                      }];
}

- (void)sendProgressUpdate {
    AVAudioRecorder *recorder = [[self recorderPool] objectForKey:_audioRecorderId];
    if (recorder && recorder.recording)
    {
        if (_prevProgressUpdateTime == nil ||
            (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) {
            NSString *eventName = [NSString stringWithFormat:@"RCTAudioRecorderEvent:%@", _audioRecorderId];
            NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
            [data setObject:[NSNumber numberWithFloat: recorder.currentTime * 1000] forKey:@"currentTime"];
            [self.bridge.eventDispatcher sendAppEventWithName:eventName
                                               body:@{@"event": @"progress",
                                                      @"data" : data
                                                      }]; 
            _prevProgressUpdateTime = [NSDate date];
        } 
    }
}

- (void)stopProgressTimer {
    [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer {
    _progressUpdateInterval = 100;
    _prevProgressUpdateTime = nil;
    [self stopProgressTimer];

    _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
    [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

@end
