//
//  ViewController.m
//  JVideoEncode
//
//  Created by Jacky on 2017/4/7.
//  Copyright © 2017年 jacky. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic,strong) UIButton *beginRecordBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.beginRecordBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -begin to record
- (void)beginToEncode{
    
    NSLog(@"开始进行编码了");
    
}

#pragma mark -lazy load
-(UIButton *)beginRecordBtn{
    if (_beginRecordBtn == nil) {
        _beginRecordBtn = [[UIButton alloc]initWithFrame:CGRectMake(10, 50, 100, 40)];
        [_beginRecordBtn setTitle:@"开始编码" forState:UIControlStateNormal];
        [_beginRecordBtn addTarget:self action:@selector(beginToEncode) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_beginRecordBtn];
    }
    return _beginRecordBtn;
}


@end
