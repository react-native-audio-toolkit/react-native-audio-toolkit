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

@implementation ReactPlayerItem {
    NSData *_data;
}

- (void)dealloc {
    self.reactPlayerId = nil;
    _data = nil;
}

+ (instancetype)playerItemWithURL:(NSURL *)url {
    AVURLAsset *asset = [AVURLAsset assetWithURL: url];
    return [[self alloc] initWithAsset:asset];
}

+ (instancetype)playerItemWithData:(NSData *)data {
    AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL URLWithString:@"data:"]];
    ReactPlayerItem *rpi = [[self alloc] initWithAsset:asset];
    dispatch_queue_t queue = dispatch_queue_create("assetQueue", nil);
    [asset.resourceLoader setDelegate:rpi queue:queue];
    rpi->_data = data;
    return rpi;
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForRenewalOfRequestedResource:(AVAssetResourceRenewalRequest *)renewalRequest {
  return [self loadingRequestHandling:renewalRequest];
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    return [self loadingRequestHandling:loadingRequest];;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader
    didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
  NSLog(@"didCancelLoadingRequest");
}

- (BOOL)loadingRequestHandling:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"loadingRequestHandling");
    
    if (loadingRequest.contentInformationRequest != nil) {
        // Fill up contentInformationRequest end return
        loadingRequest.contentInformationRequest.contentType = @"public.mp3";
        loadingRequest.contentInformationRequest.contentLength = _data.length;
        [loadingRequest.contentInformationRequest setByteRangeAccessSupported:YES];
        [loadingRequest finishLoading];
        return YES;
    }
    
    // Slice data as requested
    AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
    
    long long startOffset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }
    NSUInteger unreadBytes = _data.length - startOffset;
    NSUInteger numberOfBytesToRespondWith = dataRequest.requestedLength >= unreadBytes ? unreadBytes : dataRequest.requestedLength;
    NSRange r = {startOffset, numberOfBytesToRespondWith};
    NSData *data = [_data subdataWithRange:r];
    
    // Provide sliced data
    if(data){
        [dataRequest respondWithData:data];
        [loadingRequest finishLoading];
        return YES;
    }

    NSError *error = [NSError errorWithDomain: @"ReactPlayerItem"
                                         code: -1
                                     userInfo: @{NSLocalizedDescriptionKey: @"loadingRequestHandling - error providing data"}
                      ];

    [loadingRequest finishLoadingWithError:error];

    return NO;
}

#pragma mark - utilities

+ (NSData *)base64DataFromBase64String: (NSString *)base64String {
    if (base64String != nil) {
        // NSData from the Base64 encoded str
        NSData *base64Data = [[NSData alloc] initWithBase64EncodedString:base64String options:NSASCIIStringEncoding];
        return base64Data;
    }
    return nil;
}

@end
