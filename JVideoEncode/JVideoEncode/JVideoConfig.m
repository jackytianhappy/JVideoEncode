//
//  JVideoConfig.m
//  JVideoEncode
//
//  Created by Jacky on 2017/4/8.
//  Copyright © 2017年 jacky. All rights reserved.
//

#import "JVideoConfig.h"

@implementation JVideoConfig

+ (instancetype)defaultConfig{
    JVideoConfig *config = [[self alloc] init];
    config.videoSize = CGSizeMake(480, 640);
    config.bitRate = 512 * 1024;
    config.fps = 30;
    config.level = JProfileLevel_H264_Baseline_AutoLevel;
    config.keyFrameInterval = config.fps/3;
    
    return config;
}

@end

