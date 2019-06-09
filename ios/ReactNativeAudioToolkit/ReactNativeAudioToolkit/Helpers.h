//
//  Helpers.h
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 19/07/16.
//  Copyright © 2016-2019 Futurice.
//  Copyright (c) 2019+ React Native Community.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import <Foundation/Foundation.h>

@interface Helpers : NSObject

+(NSDictionary *) errObjWithCode:(NSString*)code
                    withMessage:(NSString*)message;

+(NSDictionary *)recorderSettingsFromOptions:(NSDictionary *)options;

@end
