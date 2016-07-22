//
//  ReactPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 20/07/16.
//  Copyright © 2016 Futurice. All rights reserved.
//

#import "ReactPlayer.h"

@implementation ReactPlayer

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super initWithURL:URL];
    
    self.looping = NO;
    self.autoDestroy = YES;
    
    return self;
}

@end
