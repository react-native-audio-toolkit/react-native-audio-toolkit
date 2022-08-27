//
//  ReactPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 20/07/16.
//  Copyright © 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "ReactPlayer.h"

@implementation ReactPlayer

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super initWithURL:URL];
    
    self.looping = NO;
    self.autoDestroy = YES;
    self.speed = 1.0f;
    
    return self;
}

- (NSNumber *)duration {
    NSNumber *duration = @0;
    
    if (self.currentItem != nil && self.currentItem.asset != nil) {
        if (CMTIME_IS_INDEFINITE(self.currentItem.asset.duration) || CMTIME_IS_INVALID(self.currentItem.asset.duration)) {
            duration = @(-1);
        } else {
            duration = @(CMTimeGetSeconds(self.currentItem.asset.duration) * 1000);
        }
    }
    
    return duration;
}

- (NSNumber *)position {
    if (CMTIME_IS_INDEFINITE(self.currentTime) || CMTIME_IS_INVALID(self.currentTime)) {
        return @(-1);
    } else {
        return @(CMTimeGetSeconds(self.currentTime) * 1000);
    }
}



@end
