//
//  Helpers.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 19/07/16.
//  Copyright © 2016 Futurice. All rights reserved.
//

#import "Helpers.h"

@implementation Helpers

+ (NSDictionary*) errObjWithCode:(NSString*)code
                    withMessage:(NSString*)message {
    
    NSDictionary *err = @{
                          @"err": code,
                          @"message": message,
                          @"stackTrace": [NSThread callStackSymbols]
                          };
    return err;

}

@end
