//
//  ViewController.m
//  JVideoEncode
//
//  Created by Jacky on 2017/4/7.
//  Copyright © 2017年 jacky. All rights reserved.
//

#import "ViewController.h"
#import "H264JEncoder.h"
#import "JVideoConfig.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,H264JEncoderDelegate>{
    H264JEncoder *h264Encoder;
    
    NSString *h264FileSavePath;
    NSFileHandle *fileHandle;
    
    AVCaptureSession *captureSession;
    AVCaptureConnection *connection;
    AVSampleBufferDisplayLayer *sbDisplayLayer;
}

@property (nonatomic,strong) UIButton *beginRecordBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    h264Encoder = [[H264JEncoder alloc]init];
    
    [self.beginRecordBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    
    // 设置文件保存位置在document文件夹
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    h264FileSavePath = [documentsDirectory stringByAppendingPathComponent:@"test.h264"];
    [fileManager removeItemAtPath:h264FileSavePath error:nil];
    [fileManager createFileAtPath:h264FileSavePath contents:nil attributes:nil];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -begin to record
- (void)beginToEncode:(id)sender{
    UIButton *btn = (UIButton *)sender;
    if ([[NSString stringWithFormat:@"%@",btn.titleLabel.text] isEqualToString:@"开始编码"]) {
        [btn setTitle:@"结束编码" forState:UIControlStateNormal];
        
        // make input device
        NSError *deviceError;
        
        AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
        
        // make output device
        AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
        NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
        NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
        NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
        outputDevice.videoSettings = videoSettings;
        
        [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        
        // initialize capture session
        
        captureSession = [[AVCaptureSession alloc] init];
        
        [captureSession addInput:inputDevice];
        [captureSession addOutput:outputDevice];
        
        // begin configuration for the AVCaptureSession
        [captureSession beginConfiguration];
        
        // picture resolution
        [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
        [captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset1280x720]];
        
        connection = [outputDevice connectionWithMediaType:AVMediaTypeVideo];
        [self setRelativeVideoOrientation];
        
        [captureSession commitConfiguration];
        
        // 添加另一个播放Layer，这个layer接收CMSampleBuffer来播放
        AVSampleBufferDisplayLayer *sb = [[AVSampleBufferDisplayLayer alloc]init];
        sb.backgroundColor = [UIColor blackColor].CGColor;
        sbDisplayLayer = sb;
        sb.videoGravity = AVLayerVideoGravityResizeAspect;
        sbDisplayLayer.frame = self.view.frame;
        [self.view.layer insertSublayer:sbDisplayLayer atIndex:0];
        //    [self.view.layer addSublayer:sbDisplayLayer];
        
        // 开始编码
        [captureSession startRunning];
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264FileSavePath];
        
        JVideoConfig *config = [JVideoConfig defaultConfig];
        
        h264Encoder.videoConfig = config;
        h264Encoder.delegate = self;
    }else{
        [btn setTitle:@"开始编码" forState:UIControlStateNormal];
        [captureSession stopRunning];
        [sbDisplayLayer removeFromSuperlayer];
        
        [fileHandle closeFile];
        fileHandle = NULL;
        
        [h264Encoder stopVideoEncode];
    }
    
    
    
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate 摄像头画面代理
-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    CGSize imageSize = CVImageBufferGetEncodedSize( imageBuffer );
    NSLog(@"ImageBufferSize------width:%.1f,heigh:%.1f",imageSize.width,imageSize.height);
    
    //直接把samplebuffer传给AVSampleBufferDisplayLayer进行预览播放
    [sbDisplayLayer enqueueSampleBuffer:sampleBuffer];
    
    //进行编码
     CVPixelBufferRef pixelBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    [h264Encoder encodeVideo:pixelBufferRef time:(CACurrentMediaTime()*1000)];
    
}

#pragma mark - h264 encode delegate
- (void)videoEncode:(H264JEncoder *)encoder sps:(NSData *)sps pps:(NSData *)pps time:(uint64_t)time{
    NSLog(@"成功了呢");
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:pps];
}

- (void)videoEncode:(H264JEncoder *)encoder frame:(NSData *)frame time:(uint64_t)time isKeyFrame:(BOOL)isKeyFrame{
    NSLog(@"you成功了呢");
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:frame];

}




#pragma mark -lazy load
-(UIButton *)beginRecordBtn{
    if (_beginRecordBtn == nil) {
        _beginRecordBtn = [[UIButton alloc]initWithFrame:CGRectMake(10, 50, 100, 40)];
        [_beginRecordBtn setTitle:@"开始编码" forState:UIControlStateNormal];
        [_beginRecordBtn addTarget:self action:@selector(beginToEncode:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_beginRecordBtn];
    }
    return _beginRecordBtn;
}


@end
