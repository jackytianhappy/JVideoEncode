//
//  H264JEncoder.m
//  JVideoEncode
//
//  Created by Jacky on 2017/4/7.
//  Copyright © 2017年 jacky. All rights reserved.
//

#import "H264JEncoder.h"
#import "JVideoConfig.h"

@import VideoToolbox;
@import AVFoundation;

@interface H264JEncoder(){
    VTCompressionSessionRef compressionSession;
    NSInteger frameCount;
    
    NSData *sps;
    NSData *pps;
}

@end

@implementation H264JEncoder
- (void)initWithConfiguration{
    compressionSession = nil;
    frameCount = 0;
    sps = NULL;
    pps = NULL;
}

- (void)setVideoConfig:(JVideoConfig *)videoConfig{
    _videoConfig = videoConfig;
    
    [self initCompressionSession];
}

- (void)initCompressionSession{
    OSStatus status = VTCompressionSessionCreate(NULL, _videoConfig.videoSize.width, _videoConfig.videoSize.height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressBuffer, (__bridge void *)self, &compressionSession);
    
    if (status != noErr) {
        NSLog(@"Create CompressSession failed");
        return;
    }
    
    //关键帧间隔 一般为帧率的两倍 建隔越大 压缩比越高
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(self.videoConfig.keyFrameInterval));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(self.videoConfig.keyFrameInterval));
    
    
    //码率 单位是bit
     VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(self.videoConfig.bitRate * 8));
    
    //码率上限 单位为 byte/s
    NSArray *limit = @[@(self.videoConfig.bitRate),@(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(_videoConfig.fps));
    
    // 设置实时编码输出（避免延迟）
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel,  kVTProfileLevel_H264_Baseline_AutoLevel);
    
    //控制是否产生B帧
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    
    //16:9
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AspectRatio16x9, kCFBooleanTrue);
    
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);

}


/**
 开始编码

 @param pixelBuffer pixelBuffer description
 @param time time description
 */
- (void)encodeVideo:(CVPixelBufferRef)pixelBuffer time:(uint64_t)time{
    frameCount++;
    
    //CMTimeMake(a,b) a当前第几帧 b每秒钟多少帧 当前播放时间a/b
    CMTime presentationTimeStamp = CMTimeMake(frameCount, 1000);
    
    //每一帧需要播放的时间
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, self.videoConfig.fps);
    
    NSDictionary *properties = nil;
    if (frameCount % (int32_t)(self.videoConfig.keyFrameInterval) == 0) { //判断是不是关键帧
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    
    NSNumber *timeNumber = @(time);
    OSStatus statusCode = VTCompressionSessionEncodeFrame(compressionSession, pixelBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, (__bridge void *)timeNumber, &flags);
    
    if (statusCode != noErr) {
        NSLog(@"H264 encode failed with %d",(int)statusCode);
        
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
        return;
    }
    
    NSLog(@"H264 encode success!!!!!");
    
}


//编码完成的回调
static void didCompressBuffer(void *VTref, void *VTFrameRef, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer){
    
    H264JEncoder *videoEncode = (__bridge H264JEncoder *)VTref;
    uint64_t timeStamp = [((__bridge_transfer NSNumber*)VTFrameRef) longLongValue];
    
    //编码后的原始数据
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    
    //判断关键帧
    BOOL isKeyFrame = NO;
    if (attachments != NULL) {
        CFDictionaryRef attachment;
        CFBooleanRef dependsOnOthers;
        attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyFrame = (dependsOnOthers == kCFBooleanFalse);
    }
    
    //关键帧需要把sps pps信息取出
    if (isKeyFrame) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        
        //sps
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, NULL );
        if (statusCode == noErr) {
            
            //pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, NULL );
            if (statusCode == noErr) {
                
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
                if ([videoEncode.delegate respondsToSelector:@selector(videoEncode:sps:pps:time:)]  ) {
                    [videoEncode.delegate videoEncode:videoEncode sps:sps pps:pps time:timeStamp];
                }
            }
        }
        
        
    }
    
    //视频数据 不管是不是关键帧都需要取出
    //前4个字节表示长度后面的数据的长度
    //除了关键帧,其它帧只有一个数据
    
    size_t length, totalLength;
    char *dataPointer;
    size_t offset = 0;
    int const headLen = 4;// 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
    
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        // 循环获取nalu数据
        while (offset < totalLength - headLen) {
            
            int NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + offset, headLen);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData *naluData = [NSData dataWithBytes:dataPointer + headLen + offset length:NALUnitLength];
            offset += headLen + NALUnitLength;
            
            if ([videoEncode.delegate respondsToSelector:@selector(videoEncode:frame:time:isKeyFrame:)]) {
                [videoEncode.delegate videoEncode:videoEncode frame:naluData time:timeStamp isKeyFrame:isKeyFrame];
            }
        }
    }
}



/**
 结束编码
 */
- (void)stopVideoEncode{
    if (compressionSession) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
}

@end
