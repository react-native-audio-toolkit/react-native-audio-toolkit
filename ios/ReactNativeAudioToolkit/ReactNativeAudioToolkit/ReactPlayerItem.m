//
//  ReactPlayerItem.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 21/07/16.
//  Copyright © 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "ReactPlayerItem.h"

@implementation ReactPlayerItem

- (void)dealloc {
    self.reactPlayerId = nil;
}

+ (instancetype)playerItemWithAsset:(AVAsset *)asset {
    return [[self alloc] initWithAsset:asset];
}

@end
