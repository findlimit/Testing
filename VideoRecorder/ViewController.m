//
//  ViewController.m
//  VideoRecorder
//
//  Created by 許 富傑 on 2018/2/22.
//  Copyright © 2018年 許 富傑. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopBtn;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieOutput;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong, nonatomic) AVAssetWriter *videoWriter;
@property (strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property (strong, nonatomic) NSURL *videoPath;
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (nonatomic) CMTime lastSampleTime;
@property (nonatomic) BOOL isRecording;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.playBtn setHidden:YES];
    [self.stopBtn setHidden:YES];
    self.videoPath = nil;
    self.lastSampleTime = kCMTimeZero;
    self.isRecording = NO;
    self.videoPath = [[self documentsDirectoryURL] URLByAppendingPathComponent:@"video.mp4"];

    // 1. Init AVCaptureSession
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    self.captureSession = captureSession;
    captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    // 2. Add available camera device
    AVCaptureDeviceDiscoverySession *devicesDiscovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    NSArray *devices = [devicesDiscovery devices];

    NSError *error;
    AVCaptureDeviceInput *cameraInput;
    if ([devices count] > 0) {
        cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:devices[0] error:&error];
        if (!cameraInput) {
            // Handle the error appropriately.
            NSLog(@"Device input error");
        }
    }
    
    if ([captureSession canAddInput:cameraInput]) {
        [captureSession addInput:cameraInput];
    }
    else {
        // Handle the failure.
        NSLog(@"Capture session add input error");
    }
    
    // 3. Add available microphone device
    devicesDiscovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    devices = [devicesDiscovery devices];
    
    AVCaptureDeviceInput *microphoneInput;
    if ([devices count] > 0) {
        microphoneInput = [AVCaptureDeviceInput deviceInputWithDevice:devices[0] error:&error];
        if (!cameraInput) {
            // Handle the error appropriately.
            NSLog(@"Device input error");
        }
    }
    
    if ([captureSession canAddInput:microphoneInput]) {
        [captureSession addInput:microphoneInput];
    }
    else {
        // Handle the failure.
        NSLog(@"Capture session add input error");
    }
    
    // 4. Add Video Data output
    self.videoDataOutput = [AVCaptureVideoDataOutput new];
    NSDictionary *newSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    self.videoDataOutput.videoSettings = newSettings;
    
    // discard if the data output queue is blocked (as we process the still image
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    } else {
        NSLog(@"Add output error");
        return;
    }

    //6. Add preview layer
    UIView *view = [self view];
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    captureVideoPreviewLayer.frame = view.bounds;
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [view.layer insertSublayer:captureVideoPreviewLayer atIndex:0];
    
    //7. Start capture session
    [captureSession startRunning];
    
    //8. Set the orientation
    [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationPortrait];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSURL *)documentsDirectoryURL
{
    NSError *error = nil;
    NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                        inDomain:NSUserDomainMask
                                               appropriateForURL:nil
                                                          create:NO
                                                           error:&error];
    if (error) {
        // Figure out what went wrong and handle the error.
    }
    
    return url;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
//    CGRect sourceExtent = sourceImage.extent;
//    
//    CIFilter *filter = [CIFilter filterWithName:@"CIFalseColor"];
//    [filter setValue:sourceImage forKey:kCIInputImageKey];
//    CIImage *filteredImage = [filter outputImage];
//    
//    CFDictionaryRef empty; // empty value for attr value.
//    CFMutableDictionaryRef attrs;
//    empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
//                               NULL,
//                               NULL,
//                               0,
//                               &kCFTypeDictionaryKeyCallBacks,
//                               &kCFTypeDictionaryValueCallBacks);
//    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
//                                      1,
//                                      &kCFTypeDictionaryKeyCallBacks,
//                                      &kCFTypeDictionaryValueCallBacks);
//    
//    CFDictionarySetValue(attrs,
//                         kCVPixelBufferIOSurfacePropertiesKey,
//                         empty);
//    CVPixelBufferRef pixelBuffer;
//    CVPixelBufferCreate(kCFAllocatorSystemDefault, sourceExtent.size.width, sourceExtent.size.height, kCVPixelFormatType_32BGRA, empty, &pixelBuffer);
//    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
//    CIContext * ciContext = [CIContext contextWithOptions: nil];
//    [ciContext render:filteredImage toCVPixelBuffer: pixelBuffer];
//    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
//    
//    CMSampleTimingInfo sampleTime = {
//        .duration = CMSampleBufferGetDuration(sampleBuffer),
//        .presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
//        .decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
//    };
//    
//    CMVideoFormatDescriptionRef videoInfo = NULL;
//    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoInfo);
//    
//    CMSampleBufferRef oBuf;
//    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &sampleTime, &oBuf);

    if ( self.isRecording &&
         [self.videoWriterInput isReadyForMoreMediaData] &&
         self.videoWriter.status == AVAssetWriterStatusWriting ) {
        if ([self.videoWriterInput appendSampleBuffer:sampleBuffer]) {
//            NSLog(@"append buffer successfully");
        } else {
            NSLog(@"append buffer failed");
        }
    }
}

- (IBAction)record:(id)sender {
    NSLog(@"Record");
    
    [sender setHidden:YES];
    [self.playBtn setHidden:YES];
    [self.stopBtn setHidden:NO];
    
    // Remove previous video
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self.videoPath path]]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:self.videoPath error:&error];
        if (error) {
            NSLog(@"Delete file error");
        }
    }

    // Config videoWriterInput and videoWriter
    NSDictionary *newSettings = @{
                    (NSString *)AVVideoCodecKey:(NSString *)AVVideoCodecH264,
                    (NSString *)AVVideoWidthKey:@([self view].bounds.size.width),
                    (NSString *)AVVideoHeightKey:@([self view].bounds.size.height) };
    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:newSettings];
    self.videoWriterInput.expectsMediaDataInRealTime = YES;
    
    self.videoWriter = [AVAssetWriter assetWriterWithURL:self.videoPath fileType:AVFileTypeMPEG4 error:nil];
    if ([self.videoWriter canAddInput:self.videoWriterInput]) {
        [self.videoWriter addInput:self.videoWriterInput];
    } else {
        NSLog(@"Video writer add input error");
    }

    if ([self.videoWriter startWriting]) {
        NSLog(@"Start writer session");
        [self.videoWriter startSessionAtSourceTime:self.lastSampleTime];
        self.isRecording = YES;
    } else {
        NSLog(@"start writing error");
    }
}

- (IBAction)stopRecord:(id)sender {
    NSLog(@"Stop");
    self.isRecording = NO;
    [self.videoWriterInput markAsFinished];
    [self.videoWriter finishWritingWithCompletionHandler:^{
        if (self.videoWriter.status == AVAssetWriterStatusCompleted) {
            NSLog(@"Saved video successfully");
        } else {
            NSLog(@"Covert file error:%@", self.videoWriter.error);
        }
    }];
    
    [self.playBtn setHidden:NO];
    [self.recordBtn setHidden:NO];
    [self.stopBtn setHidden:YES];
}

- (IBAction)play:(id)sender {
    NSLog(@"Play");
    [self.playBtn setHidden:YES];
    [self.recordBtn setHidden:YES];
    
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:self.videoPath options:nil];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:avAsset];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.view.layer.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self.view.layer insertSublayer:self.playerLayer atIndex:1];
    [self.player play];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.playBtn setHidden:NO];
    [self.recordBtn setHidden:NO];
    [self.playerLayer removeFromSuperlayer];
}

@end
