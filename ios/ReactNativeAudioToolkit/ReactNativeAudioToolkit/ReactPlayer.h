//
//  ReactPlayer.h
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 20/07/16.
//  Copyright © 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import <AVFoundation/AVFoundation.h>

@interface ReactPlayer : AVPlayer

@property (readwrite) BOOL autoDestroy;
@property (readwrite) BOOL looping;
@property (readwrite) float speed;

@end
