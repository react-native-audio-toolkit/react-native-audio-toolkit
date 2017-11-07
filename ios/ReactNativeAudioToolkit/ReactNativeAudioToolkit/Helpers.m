//
//  Helpers.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 19/07/16.
//  Copyright © 2016 Futurice. All rights reserved.
//

#import "Helpers.h"
#import <AVFoundation/AVFoundation.h>

@implementation Helpers

+ (NSDictionary*) errObjWithCode:(NSString*)code
                    withMessage:(NSString*)message {
    
    NSDictionary *err = @{
                          @"err": code,
                          @"message": message,
                          @"stackTrace": [NSThread callStackSymbols]
                          };
    return err;

}

+ (NSDictionary *)recorderSettingsFromOptions:(NSDictionary *)options {
    
    NSString *formatString = options[@"format"];
    NSString *qualityString = options[@"quality"];
    NSNumber *sampleRate = options[@"sampleRate"];
    NSNumber *channels = options[@"channels"];
    NSNumber *bitRate = options[@"bitrate"];
    
    // Assign default values if nil and map otherwise
    sampleRate = sampleRate ? sampleRate : @44100;
    channels = channels ? channels : @2;
    bitRate = bitRate ? bitRate : @128000;
    
    
    // "aac" or "mp4"
    NSNumber *format = @(kAudioFormatMPEG4AAC);
    if (formatString) {
        if ([formatString isEqualToString:@"ac3"]) {
            format = @(kAudioFormatMPEG4AAC);
        }
    }
    
    
    NSNumber *quality = @(AVAudioQualityMedium);
    if (qualityString) {
        if ([qualityString isEqualToString:@"min"]) {
            quality = @(AVAudioQualityMin);
        } else if ([qualityString isEqualToString:@"low"]) {
            quality = @(AVAudioQualityLow);
        } else if ([qualityString isEqualToString:@"medium"]) {
            quality = @(AVAudioQualityMedium);
        } else if ([qualityString isEqualToString:@"high"]) {
            quality = @(AVAudioQualityHigh);
        } else if ([qualityString isEqualToString:@"max"]) {
            quality = @(AVAudioQualityMax);
        }
    }
    
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    [recordSettings setValue:format forKey:AVFormatIDKey];
    [recordSettings setValue:sampleRate forKey:AVSampleRateKey];
    [recordSettings setValue:channels forKey:AVNumberOfChannelsKey];
    [recordSettings setValue:bitRate forKey:AVEncoderBitRateKey];
    //[recordSettings setValue:quality forKey:AVEncoderAudioQualityKey];
    
    [recordSettings setValue :@(16) forKey:AVLinearPCMBitDepthKey];
    [recordSettings setValue :@(NO) forKey:AVLinearPCMIsBigEndianKey];
    [recordSettings setValue :@(NO) forKey:AVLinearPCMIsFloatKey];
    
    return recordSettings;
}

@end
