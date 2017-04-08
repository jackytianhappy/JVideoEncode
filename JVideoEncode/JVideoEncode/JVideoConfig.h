//
//  JVideoConfig.h
//  JVideoEncode
//
//  Created by Jacky on 2017/4/8.
//  Copyright © 2017年 jacky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 H264压缩等级
 */
typedef NS_ENUM(NSUInteger, JProfileLevel){
    //默认level
    JProfileLevel_H264_Baseline_AutoLevel,
    //main
    JProfileLevel_H264_Main_AutoLevel,
    //high 建议6s以上使用
    JProfileLevel_H264_High_AutoLevel,
};

@interface JVideoConfig : NSObject

/**
 视频尺寸 默认640*480
 */
@property (nonatomic,assign) CGSize videoSize;

/**
 码率 默认512*1024
 */
@property (nonatomic,assign) int bitRate;

/**
 帧率 默认30
 */
@property (nonatomic,assign) int fps;

/**
 关键帧间隔， 一般为fps的倍数 默认10
 */
@property (nonatomic,assign) int keyFrameInterval;

/**
 H264的压缩等级 等级越高 压缩率越高 越节约流量 越耗费CPU 手机越烫
 */
@property (nonatomic,assign) JProfileLevel level;

+ (instancetype)defaultConfig;

@end
