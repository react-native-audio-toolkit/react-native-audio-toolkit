//
//  AudioManager.h
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import <Foundation/Foundation.h>

#if __has_include(<React/RCTBridgeModule.h>)
  #import <React/RCTBridgeModule.h>
#elif __has_include("React/RCTBridgeModule.h")
  #import "React/RCTBridgeModule.h"
#else
  #import "RCTBridgeModule.h"
#endif

@interface AudioRecorder : NSObject <RCTBridgeModule>

@end
