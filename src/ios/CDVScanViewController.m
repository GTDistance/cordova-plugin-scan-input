//
//  CDVScanViewController.m
//  cordova-plugin-scan
//
//  Created by ZhangJian on 16/8/3.
//  Copyright © 2016年 zhangjian. All rights reserved.
//

#import "CDVScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

#define QRCodeWidth  260.0   //正方形二维码的边长
#define SCREENHeight  [UIScreen mainScreen].bounds.size.height
#define SCREENWidth  [UIScreen mainScreen].bounds.size.width

//尺寸设置
#define aiScreenWidth [UIScreen mainScreen].bounds.size.width
#define aiScreenHeight [UIScreen mainScreen].bounds.size.height
#define STATUS_BAR_HEIGHT [[UIApplication sharedApplication] statusBarFrame].size.height
#define NAVIGATION_BAR_HEIGHT self.navigationController.navigationBar.frame.size.height
#define TAB_BAR_HEIGHT self.tabBarController.tabBar.frame.size.height

static const CGFloat kBorderW = 100;
static const CGFloat kMargin = 30;
@interface CDVScanViewController () <AVCaptureMetadataOutputObjectsDelegate> //用于处理采集信息的代理
// MARK: - Properties
@property (strong, nonatomic) AVCaptureSession* scanSession; //输入输出的中间桥梁
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* scanLayer; //输入输出的中间桥梁
@end
@implementation CDVScanViewController

// MARK: - Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"扫码充电";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(handleClose:)];
    //设置右侧
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"客服中心" style:UIBarButtonItemStylePlain target:self action:@selector(rightClick:)];
    [self setupMaskView];
    
    [self setupScanWindowView];
    
    [self beginScanning];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (!self.scanSession.isRunning) {
        [self.scanSession startRunning];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (self.scanSession.isRunning) {
        [self.scanSession stopRunning];
    }
}

// MARK: - Private Methods
- (void)setupMaskView{
    
    //操作提示
    UILabel * tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, SCREENHeight*0.9-kBorderW*2, SCREENWidth, kBorderW)];
    tipLabel.text = @"请扫描充电桩上的二维码";
    tipLabel.textColor = [UIColor whiteColor];
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.lineBreakMode = NSLineBreakByWordWrapping;
    tipLabel.numberOfLines = 0;
    tipLabel.font = [UIFont systemFontOfSize:15];
    tipLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:tipLabel];
    
    //设置统一的视图颜色和视图的透明度
    UIColor *color = [UIColor blackColor];
    float alpha = 0.3;
    
    //设置扫描区域外部上部的视图
    UIView *topView = [[UIView alloc]init];
    topView.frame = CGRectMake(0, 0, SCREENWidth, (SCREENHeight-QRCodeWidth)/2.0-64);
    topView.backgroundColor = color;
    topView.alpha = alpha;
    
    //设置扫描区域外部左边的视图
    UIView *leftView = [[UIView alloc]init];
    leftView.frame = CGRectMake(0, topView.frame.size.height, (SCREENWidth-QRCodeWidth)/2.0,QRCodeWidth);
    leftView.backgroundColor = color;
    leftView.alpha = alpha;
    
    //设置扫描区域外部右边的视图
    UIView *rightView = [[UIView alloc]init];
    rightView.frame = CGRectMake((SCREENWidth-QRCodeWidth)/2.0+QRCodeWidth,topView.frame.size.height, (SCREENWidth-QRCodeWidth)/2.0,QRCodeWidth);
    rightView.backgroundColor = color;
    rightView.alpha = alpha;
    
    //设置扫描区域外部底部的视图
    UIView *botView = [[UIView alloc]init];
    botView.frame = CGRectMake(0, QRCodeWidth+topView.frame.size.height,SCREENWidth,SCREENHeight-QRCodeWidth-topView.frame.size.height);
    botView.backgroundColor = color;
    botView.alpha = alpha;
    
    //将设置好的扫描二维码区域之外的视图添加到视图图层上
    [self.view addSubview:topView];
    [self.view addSubview:leftView];
    [self.view addSubview:rightView];
    [self.view addSubview:botView];
    
    //键盘输入
    UIButton * keyBoardBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    keyBoardBtn.frame = CGRectMake((SCREENWidth/2-60)/2,SCREENHeight*0.9-kBorderW*2+80, 60, 60);
    [keyBoardBtn setBackgroundImage:[UIImage imageNamed:@"keyboard1"] forState:UIControlStateNormal];
    keyBoardBtn.contentMode=UIViewContentModeScaleAspectFit;
    [keyBoardBtn addTarget:self action:@selector(showAlert:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:keyBoardBtn];
    
    //闪光灯
    UIButton * flashBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    flashBtn.frame = CGRectMake(SCREENWidth/2+(SCREENWidth/2-60)/2,SCREENHeight*0.9-kBorderW*2+80, 60, 60);
    [flashBtn setBackgroundImage:[UIImage imageNamed:@"sgd"] forState:UIControlStateNormal];
    flashBtn.contentMode=UIViewContentModeScaleAspectFit;
    [flashBtn addTarget:self action:@selector(openFlash:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:flashBtn];
}

- (BOOL) validateContent:(NSString *)content
{
    NSString *emailRegex = @"^\\d{19}$";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:content];
}
-(void)showAlert:(id)sender {
    //提示框添加文本输入框
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"请输入编码" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                         //响应事件
                                                         //得到文本信息
        UITextField *text = alert.textFields[0];
        NSLog(@"text = %@", text.text);
        if([self validateContent:text.text]){
            NSDictionary *dict = @{@"type":@"3", @"content":text.text};
            NSString * content = [self convertToJsonData:dict];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"scan" object:self userInfo:@{@"content":content}];
                [self handleClose:NULL];
            });
        }else{
           [self addToastWithString:@"请输入正确的19位编码" inView:self.view];
        }
        
//                                                         for(UITextField *text in alert.textFields){
//                                                             NSLog(@"text = %@", text.text);
//                                                         }
                                                     }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             //响应事件
                                                             NSLog(@"action = %@", alert.textFields);
                                                         }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"请输入编码";
        textField.keyboardType=UIKeyboardTypeNumberPad;
    }];

    [alert addAction:okAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
    
}

/**
 
 计算单行文字的size
 
 @parms  文本
 
 @parms  字体
 
 @return  字体的CGSize
 
 */

- (CGSize)sizeWithText:(NSString *)text withFont:(UIFont *)font{
    
    CGSize size = [text sizeWithAttributes:@{NSFontAttributeName:font}];
    
    return size;
    
}
- (void) addToastWithString:(NSString *)string inView:(UIView *)view {
    
//    CGRect initRect = CGRectMake(0, STATUS_BAR_HEIGHT + 44, aiScreenWidth, 0);
    UIFont *font = [UIFont systemFontOfSize:20];
    CGSize size  = [self sizeWithText :string withFont: font];
    CGRect initRect = CGRectMake(aiScreenWidth/2, STATUS_BAR_HEIGHT + 44+15, 0, 0);
    CGRect rect = CGRectMake((aiScreenWidth-(size.width+30))/2, STATUS_BAR_HEIGHT + 44, size.width+30, 30);
//    CGRect rect = CGRectMake(0, STATUS_BAR_HEIGHT + 44, aiScreenWidth, 30);
    UILabel* label = [[UILabel alloc] initWithFrame:initRect];
    label.text = string;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor blackColor];
    label.font = [UIFont systemFontOfSize:20];
    label.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
    [view addSubview:label];
    
    //弹出label
    [UIView animateWithDuration:0.2 animations:^{
        
        label.frame = rect;
        
    } completion:^ (BOOL finished){
        //弹出后持续1s
        [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(removeToastWithView:) userInfo:label repeats:NO];
    }];
}

- (void) removeToastWithView:(NSTimer *)timer {
    
    UILabel* label = [timer userInfo];
    
//    CGRect initRect = CGRectMake(0, STATUS_BAR_HEIGHT + 44, aiScreenWidth, 0);
     CGRect initRect = CGRectMake(aiScreenWidth/2, STATUS_BAR_HEIGHT + 44+15, 0, 0);
    //    label消失
    [UIView animateWithDuration:0.2 animations:^{
        
        label.frame = initRect;
    } completion:^(BOOL finished){
        
        [label removeFromSuperview];
    }];
}

/**
 获取指定宽度width的字符串在UITextView上的高度
 
 @param textView 待计算的UITextView
 @param width 限制字符串显示区域的宽度
 @return 返回的高度
 */
- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}
- (float)widthForString:(UITextView *)textView andHeight:(float)height {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(height, MAXFLOAT)];
    return sizeToFit.width;
}
#pragma mark - 显示提示信息
- (void)toastTip:(NSString *)toastInfo {
    CGRect frameRC = [[UIScreen mainScreen] bounds];
    frameRC.origin.y = frameRC.size.height - 110;
    frameRC.size.height -= 110;
    __block UITextView *toastView = [[UITextView alloc] init];
    
    toastView.editable = NO;
    toastView.selectable = NO;
    
    frameRC.size.height = [self heightForString:toastView andWidth:frameRC.size.width];
    frameRC.size.width = [self widthForString:toastView andHeight:frameRC.size.height];
    toastView.frame = frameRC;
    
    toastView.text = toastInfo;
    toastView.backgroundColor = [UIColor whiteColor];
    toastView.alpha = 0.8;
    
    [self.view addSubview:toastView];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^() {
        [toastView removeFromSuperview];
        toastView = nil;
    });
}

- (BOOL)isBlankString:(NSString *)aStr {
    if (!aStr) {
        return YES;
    }
    if ([aStr isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if (!aStr.length) {
        return YES;
    }
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmedStr = [aStr stringByTrimmingCharactersInSet:set];
    if (!trimmedStr.length) {
        return YES;
    }
    return NO;
}
- (void)setupScanWindowView{
    //设置扫描区域的位置
    UIView *scanWindow = [[UIView alloc] initWithFrame:CGRectMake((SCREENWidth-QRCodeWidth)/2.0,(SCREENHeight-QRCodeWidth)/2.0-64,QRCodeWidth,QRCodeWidth)];
    scanWindow.clipsToBounds = YES;
    [self.view addSubview:scanWindow];
    
    //设置扫描区域的动画效果
    CGFloat scanNetImageViewH = 2;
    CGFloat scanNetImageViewW = scanWindow.frame.size.width;
    UIImageView *scanNetImageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"scanLine"]];
    scanNetImageView.frame = CGRectMake(0, -scanNetImageViewH, scanNetImageViewW, scanNetImageViewH);
    CABasicAnimation *scanNetAnimation = [CABasicAnimation animation];
    scanNetAnimation.keyPath =@"transform.translation.y";
    scanNetAnimation.byValue = @(QRCodeWidth);
    scanNetAnimation.duration = 2.0;
    scanNetAnimation.repeatCount = MAXFLOAT;
    [scanNetImageView.layer addAnimation:scanNetAnimation forKey:nil];
    [scanWindow addSubview:scanNetImageView];
    
    //设置扫描区域的四个角的边框
    CGFloat buttonWH = 18;
    UIButton *topLeft = [[UIButton alloc]initWithFrame:CGRectMake(0,0, buttonWH, buttonWH)];
    [topLeft setImage:[UIImage imageNamed:@"left-up"]forState:UIControlStateNormal];
    [scanWindow addSubview:topLeft];
    
    UIButton *topRight = [[UIButton alloc]initWithFrame:CGRectMake(QRCodeWidth - buttonWH,0, buttonWH, buttonWH)];
    [topRight setImage:[UIImage imageNamed:@"right-up"]forState:UIControlStateNormal];
    [scanWindow addSubview:topRight];
    
    UIButton *bottomLeft = [[UIButton alloc]initWithFrame:CGRectMake(0,QRCodeWidth - buttonWH, buttonWH, buttonWH)];
    [bottomLeft setImage:[UIImage imageNamed:@"left-down"]forState:UIControlStateNormal];
    [scanWindow addSubview:bottomLeft];
    
    UIButton *bottomRight = [[UIButton alloc]initWithFrame:CGRectMake(QRCodeWidth-buttonWH,QRCodeWidth-buttonWH, buttonWH, buttonWH)];
    [bottomRight setImage:[UIImage imageNamed:@"right-down"]forState:UIControlStateNormal];
    [scanWindow addSubview:bottomRight];
}

- (void)beginScanning{
    // Do any additional setup after loading the view, typically from a nib.
    //获取摄像设备
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //创建输入流
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if (!input) return;
    //创建输出流
    AVCaptureMetadataOutput* output = [[AVCaptureMetadataOutput alloc] init];
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //初始化链接对象
    self.scanSession = [[AVCaptureSession alloc] init];
    //高质量采集率
    [self.scanSession setSessionPreset:AVCaptureSessionPresetHigh];
    
    [self.scanSession addInput:input];
    [self.scanSession addOutput:output];
    //设置扫码支持的编码格式(如下设置条形码和二维码兼容)
    output.metadataObjectTypes = @[ AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeCode93Code ];
    //设置扫描有效范围
    //特别注意的地方：有效的扫描区域，定位是以设置的右顶点为原点。屏幕宽所在的那条线为y轴，屏幕高所在的线为x轴
    CGFloat x = ((SCREENHeight-QRCodeWidth)/2.0)/SCREENHeight;
    CGFloat y = ((SCREENWidth-QRCodeWidth)/2.0)/SCREENWidth;
    CGFloat width = QRCodeWidth/SCREENHeight;
    CGFloat height = QRCodeWidth/SCREENWidth;
    output.rectOfInterest = CGRectMake(x, y, width, height);
    //    [output setRectOfInterest:CGRectMake(124/SCREENHeight, ((SCREENWidth-220)/2)/SCREENWidth, 220/SCREENHeight, 220/SCREENWidth)];
    
    self.scanLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.scanSession];
    self.scanLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:self.scanLayer atIndex:0];
    //开始捕获
    [self.scanSession startRunning];
}

-(void)handleClose:(id)sender{
    [self.navigationController dismissViewControllerAnimated:YES completion:NULL];
}
-(void)rightClick:(id)sender{
    NSDictionary *dict = @{@"type":@"2", @"content":@"service"};
    NSString * content = [self convertToJsonData:dict];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"scan" object:self userInfo:@{@"content":content}];
        [self handleClose:NULL];
    });
}
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.scanLayer.frame = self.view.layer.bounds;
}


- (void)captureOutput:(AVCaptureOutput*)captureOutput didOutputMetadataObjects:(NSArray*)metadataObjects fromConnection:(AVCaptureConnection*)connection
{
    [self.scanSession stopRunning];
    if (metadataObjects.count > 0) {
        //[session stopRunning];
        AVMetadataMachineReadableCodeObject* metadataObject = [metadataObjects objectAtIndex:0];
        //输出扫描字符串
        NSString *str = metadataObject.stringValue;
        NSLog(@"%@",str);
        NSDictionary *dict = @{@"type":@"1", @"content":str};
        NSString * content = [self convertToJsonData:dict];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"scan" object:self userInfo:@{@"content":content}];
            [self handleClose:NULL];
        });
        
        
    }
}

//MARK:-  闪光灯
-(void)openFlash:(UIButton*)button{
    NSLog(@"闪光灯");
    button.selected = !button.selected;
    if (button.selected) {
        [self turnTorchOn:YES];
    }
    else{
        [self turnTorchOn:NO];
    }
}

//MARK:- 开关闪光灯
- (void)turnTorchOn:(BOOL)on{
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasTorch] && [device hasFlash]){
            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}
// 字典转json字符串方法

-(NSString *)convertToJsonData:(NSDictionary *)dict

{
    
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    
    NSString *jsonString;
    
    if (!jsonData) {
        
        NSLog(@"%@",error);
        
    }else{
        
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        
    }
    
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    
    NSRange range = {0,jsonString.length};
    
    //去掉字符串中的空格
    
    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    
    NSRange range2 = {0,mutStr.length};
    
    //去掉字符串中的换行符
    
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    
    return mutStr;
    
}

@end
