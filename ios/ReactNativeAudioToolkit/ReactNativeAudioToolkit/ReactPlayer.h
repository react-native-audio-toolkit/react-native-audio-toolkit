//
//  ReactPlayer.h
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 20/07/16.
//  Copyright © 2016 Futurice. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "RCTEventDispatcher.h"

@interface ReactPlayer : AVPlayer

@property (readwrite) BOOL autoDestroy;
@property (readwrite) BOOL looping;
@property (readwrite) float speed;

@end
