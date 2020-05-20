//
//  RealtimeInkViewController.m
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import "RealtimeInkViewController.h"
#import "RenderingView.h"
#import "AppDelegate.h"
@import WILLDevices;
@import WILLDevicesCore;
@import WILLInk;


@interface RealtimeInkViewController ()

@property (nonatomic, strong) IBOutlet UIView *drawingView;
@property (nonatomic, strong) RenderingView *renderView;
@property (nonatomic, assign) id<RealTimeInkService> realtimeService;
@property (nonatomic, assign) BOOL smartpadDevice;


@end

@implementation RealtimeInkViewController

//========================================================================================================
// MARK: UIView Methods
//========================================================================================================

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    self.deviceWidth = 100.0f;
//    self.deviceHeight = 100.0f;
//    self.deviceType = DeviceTypeUnknown;
//    self.smartpadDevice = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.drawingView.backgroundColor = [UIColor whiteColor];
    if(self.inkDevice == nil || (self.inkDevice.deviceStatus == DeviceStatusNotConnected)) {
        [AppDelegate postNotification:@"Error" withBody:@"InkDevice not connected"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.realtimeService = NULL;
            [self.navigationController popViewControllerAnimated:YES];
        });
    }
    //Attempt to start the ink service
    @try {
        NSError *err;
        self.realtimeService = (NSObject<RealTimeInkService> *)[self.inkDevice getService:InkDeviceServiceTypeRealtimeInk error:&err];
    } @catch (NSException *e) {
        NSString *errorText = [NSString stringWithFormat:@"Failed to start realtime ink service:%@", e.reason];
        [AppDelegate postNotification:@"Error" withBody:errorText];
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.realtimeService = NULL;
            [self.navigationController popViewControllerAnimated:YES];
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //Start the realtime service
    self.renderView = [[RenderingView alloc] initWithFrame:self.drawingView.bounds];//RenderingView(frame: drawingView.bounds)
    [self.drawingView addSubview:self.renderView];
    self.renderView.backgroundColor = [UIColor whiteColor];
    @try {
        self.realtimeService.dataReceiver = self; //Receive point data
        CGFloat screenWidth = self.drawingView.bounds.size.width;
        CGFloat screenHeight = self.drawingView.bounds.size.height;
        
        if(self.smartpadDevice){
            //For bamboo device, the data should be rotated
            if (self.deviceType == DeviceTypeBambooSlateOrFolio || self.deviceType == DeviceTypeIntousPaper) {
                CGFloat xScale = screenWidth / self.deviceHeight;
                CGFloat yScale = screenHeight / self.deviceWidth;
                CGFloat scale = fmin(xScale, yScale); //So we have 1:1 scale
                CGFloat rotationAngle = (-M_PI/2.0) + M_PI;
                
                self.realtimeService.transform = CGAffineTransformIdentity;
                CGAffineTransform t = CGAffineTransformIdentity;
            
                t = CGAffineTransformScale(t, scale, scale);
                t = CGAffineTransformRotate(t, rotationAngle);
                t = CGAffineTransformConcat(t, CGAffineTransformMake(1, 0, 0, 1, fmin(screenWidth, screenHeight), 0));
                self.realtimeService.transform = t;

            } else {
                CGFloat xScale = screenWidth / self.deviceWidth;
                CGFloat yScale = screenHeight / self.deviceHeight;
                CGFloat scale = fmin(xScale, yScale); //So we have 1:1 scale
                CGAffineTransform t = CGAffineTransformIdentity;
                t = CGAffineTransformScale(t, scale, scale);
                [self.realtimeService setTransform:t];
            }
            
        } else { //Set the UIView for input to be the rendering view
            self.realtimeService.transform = CGAffineTransformIdentity;
            self.realtimeService.inputView = self.drawingView;
        }
        [self.realtimeService startWithProvideRawData:YES error:NULL completionHandler:NULL];
    } @catch (NSException *e) {
        NSString *errorText = [NSString stringWithFormat:@"Failed to start realtime ink service:%@", e.reason];
        [AppDelegate postNotification:@"Error" withBody:errorText];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.realtimeService = NULL;
            [self.navigationController popViewControllerAnimated:YES];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    //Stop service and displose
    if(self.realtimeService != NULL) {
        @try {
            [self.realtimeService endAndReturnError:NULL completionHandler:NULL];
        } @catch(NSException *e) {
            NSString *errorText = [NSString stringWithFormat:@"Error closing ink service:%@", e.reason];
            [AppDelegate postNotification:@"Error" withBody:errorText];

        }
    }
}

- (void)setDeviceType:(DeviceType)deviceType {
    _deviceType = deviceType;
    
    switch (_deviceType) {
        
        case DeviceTypeBambooSpark:
            self.smartpadDevice = YES;
            break;
        case DeviceTypeBambooSlateOrFolio:
            self.smartpadDevice = YES;

            break;
        case DeviceTypeIntousPaper:
            self.smartpadDevice = YES;

            break;
        case DeviceTypeBambooPro:
            self.smartpadDevice = YES;

            break;
        case DeviceTypeClipboardPHU111:
            self.smartpadDevice = YES;

            break;
        case DeviceTypeApplePencil:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeCreativeStylus:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeCreativeStylus2:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeBambooFineline:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeBambooFineline2:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeBambooFineline3:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeBambooSketch:
            self.smartpadDevice = NO;

            break;
        case DeviceTypeUnknown:
            self.smartpadDevice = NO;

            break;
    }
}

- (void)hoverStrokeReceivedWithPath:(NSArray<RawPoint *> * _Nonnull)path {
    
}

- (void)newLayerAdded {
    
}

- (void)pointsLostWithCount:(NSInteger)count {
    
}

- (void)strokeBeganWithPenID:(NSData * _Nonnull)penID inputDeviceType:(enum ToolType)inputDeviceType inkColor:(UIColor * _Nonnull)inkColor pathChunk:(WCMFloatVector * _Nonnull)pathChunk {
    [self.renderView addStrokePart:pathChunk isEnd:NO];
}

- (void)strokeEndedWithPathChunk:(WCMFloatVector * _Nullable)pathChunk inkStroke:(InkStroke * _Nonnull)inkStroke cancelled:(BOOL)cancelled {
    [self.renderView addStrokePart:pathChunk isEnd:YES];
    
    UIBezierPath *path = inkStroke.bezierPath;
    
    if(path != NULL) {
        [self.renderView addStrokeBezier:path];
    }
    
//    if(inkStroke.rawPoints != NULL) {
//        for (RawPoint *p in inkStroke.rawPoints) {
//            NSLog(@"%@", [NSString stringWithFormat:@"(%ld, %ld, %ld)\n", (long)p.x, (long)p.y, (long)p.p]);
//        }
//    }
    

}

- (void)strokeMovedWithPathChunk:(WCMFloatVector * _Nonnull)pathChunk {
    [self.renderView addStrokePart:pathChunk isEnd:NO];
}


@end
