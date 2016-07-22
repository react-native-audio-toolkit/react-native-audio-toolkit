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
    
    NSString *formatString = [options objectForKey:@"format"];
    NSString *qualityString = [options objectForKey:@"quality"];
    NSNumber *sampleRate = [options objectForKey:@"sampleRate"];
    NSNumber *channels = [options objectForKey:@"channels"];
    NSNumber *bitRate = [options objectForKey:@"bitrate"];
    
    // Assign default values if nil and map otherwise
    sampleRate = sampleRate ? sampleRate : @44100;
    channels = channels ? channels : @2;
    bitRate = (bitRate ? bitRate : @128000);
    
    NSNumber *format = [NSNumber numberWithInt:kAudioFormatMPEG4AAC];
    if (formatString) {
        if ([formatString isEqualToString:@"PCM"]) {
            format = [NSNumber numberWithInt:kAudioFormatLinearPCM];
        } else if ([formatString isEqualToString:@"AC3"]) {
            format = [NSNumber numberWithInt:kAudioFormatAC3];
        }
    }
    
    NSNumber *quality = [NSNumber numberWithInt:AVAudioQualityMedium];
    if (qualityString) {
        if ([qualityString isEqualToString:@"min"]) {
            format = [NSNumber numberWithInt:AVAudioQualityMin];
        } else if ([qualityString isEqualToString:@"low"]) {
            format = [NSNumber numberWithInt:AVAudioQualityLow];
        } else if ([qualityString isEqualToString:@"medium"]) {
            format = [NSNumber numberWithInt:AVAudioQualityMedium];
        } else if ([qualityString isEqualToString:@"high"]) {
            format = [NSNumber numberWithInt:AVAudioQualityHigh];
        } else if ([qualityString isEqualToString:@"max"]) {
            format = [NSNumber numberWithInt:AVAudioQualityMax];
        }
    }
    
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    
    [recordSettings setValue:format forKey:AVFormatIDKey];
    [recordSettings setValue:sampleRate forKey:AVSampleRateKey];
    [recordSettings setValue:channels forKey:AVNumberOfChannelsKey];
    [recordSettings setValue:bitRate forKey:AVEncoderBitRateKey];
    //[recordSettings setValue:quality forKey:AVEncoderAudioQualityKey];
    
    [recordSettings setValue :[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [recordSettings setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
    [recordSettings setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    
    return recordSettings;
}

@end
