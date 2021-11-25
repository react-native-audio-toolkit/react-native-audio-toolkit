//
//  Helpers.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 19/07/16.
//  Copyright © 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

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
    bitRate = bitRate ? bitRate : @128000;
    
    
    // "aac" or "mp4"
    NSNumber *format = [NSNumber numberWithInt:kAudioFormatMPEG4AAC];
    if (formatString) {
        if ([formatString isEqualToString:@"ac3"]) {
            format = [NSNumber numberWithInt:kAudioFormatMPEG4AAC];
        }
    }
    
    
    NSNumber *quality = [NSNumber numberWithInt:AVAudioQualityMedium];
    if (qualityString) {
        if ([qualityString isEqualToString:@"min"]) {
            quality = [NSNumber numberWithInt:AVAudioQualityMin];
        } else if ([qualityString isEqualToString:@"low"]) {
            quality = [NSNumber numberWithInt:AVAudioQualityLow];
        } else if ([qualityString isEqualToString:@"medium"]) {
            quality = [NSNumber numberWithInt:AVAudioQualityMedium];
        } else if ([qualityString isEqualToString:@"high"]) {
            quality = [NSNumber numberWithInt:AVAudioQualityHigh];
        } else if ([qualityString isEqualToString:@"max"]) {
            quality = [NSNumber numberWithInt:AVAudioQualityMax];
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

+(NSData *)decodeBase64DataUrl:(NSString*)url {
    NSRange b64r = [url rangeOfString:@";base64,"];
    if (b64r.location == NSNotFound) {
        NSLog(@"decodeBase64DataUrl - base64 not found in data: url");
        return nil;
    }
    NSInteger idx = b64r.location + @";base64,".length;
    NSString *b64string = [url substringFromIndex:idx];
    NSData *b64decoded = [[NSData alloc] initWithBase64EncodedString:b64string options:NSASCIIStringEncoding];
    if (b64decoded == nil) {
        NSLog(@"decodeBase64DataUrl - error decoding base64 data");
        return nil;
    }
    
    return b64decoded;
}

@end
