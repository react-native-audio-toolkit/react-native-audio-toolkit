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

@end
