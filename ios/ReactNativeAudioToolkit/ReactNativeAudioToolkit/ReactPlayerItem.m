//
//  ReactPlayerItem.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 21/07/16.
//  Copyright © 2016 Futurice. All rights reserved.
//

#import "ReactPlayerItem.h"

@implementation ReactPlayerItem

- (void)dealloc {
    self.reactPlayerId = nil;
}

+ (instancetype)playerItemWithAsset:(AVAsset *)asset {
    return [[self alloc] initWithAsset:asset];
}

@end
