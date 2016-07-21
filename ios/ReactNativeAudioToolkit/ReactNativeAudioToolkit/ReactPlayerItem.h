//
//  ReactPlayerItem.h
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 21/07/16.
//  Copyright © 2016 Futurice. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
@class ReactPlayer;
@interface ReactPlayerItem : AVPlayerItem

@property (nonatomic, strong) NSNumber *reactPlayerId;

@end
