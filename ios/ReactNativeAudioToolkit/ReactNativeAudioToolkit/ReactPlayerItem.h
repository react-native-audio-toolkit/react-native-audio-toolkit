//
//  ReactPlayerItem.h
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 21/07/16.
//  Copyright © 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import <AVFoundation/AVFoundation.h>
@class ReactPlayer;
@interface ReactPlayerItem : AVPlayerItem

@property (nonatomic, strong) NSNumber *reactPlayerId;

@end
