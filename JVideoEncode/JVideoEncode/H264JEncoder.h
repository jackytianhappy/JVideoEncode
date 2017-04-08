//
//  H264JEncoder.h
//  JVideoEncode
//
//  Created by Jacky on 2017/4/7.
//  Copyright © 2017年 jacky. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@class JVideoConfig;
@class H264JEncoder;

@protocol H264JEncoderDelegate <NSObject>

- (void)videoEncode:(H264JEncoder *)encoder sps:(NSData *)sps pps:(NSData *)pps time:(uint64_t)time;
- (void)videoEncode:(H264JEncoder *)encoder frame:(NSData *)frame time:(uint64_t)time isKeyFrame:(BOOL)isKeyFrame;

@end


@interface H264JEncoder : NSObject

@property (nonatomic,weak) id<H264JEncoderDelegate> delegate;

@property (nonatomic,strong) JVideoConfig *videoConfig;

- (void)stopVideoEncode;
- (void)encodeVideo:(CVPixelBufferRef)pixelBuffer time:(uint64_t)time;

@end
