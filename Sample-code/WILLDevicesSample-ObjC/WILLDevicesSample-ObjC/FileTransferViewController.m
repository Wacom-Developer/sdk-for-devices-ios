//
//  FileTransferViewController.m
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import "FileTransferViewController.h"
#import "AppDelegate.h"

@import WILLDevicesCore;

@interface FileTransferViewController ()

/// The list of downloaded documents from the device
@property (nonatomic, strong) NSMutableArray<InkDocument *> *downloadedDocuments;

/// Background download queue
@property (nonatomic, strong) dispatch_queue_t downloadQueue;

/// The collection view used to render samples of the files recevied
@property (nonatomic, strong) IBOutlet UICollectionView *collectionView;

/// Flag to stop spamming when we are polling for files
@property (nonatomic, assign) BOOL showFinishedPrompt;

/// Flag to see if we should be polling for new files
@property (nonatomic, assign) BOOL pollForNewFiles;

/// Inkdevice service for file download
@property (nonatomic, strong) id<FileTranserService> fileService;

@end

@implementation FileTransferViewController

//========================================================================================================
// MARK: UIView Methods
//========================================================================================================

- (void)viewDidLoad {
    [super viewDidLoad];
    self.downloadedDocuments = [NSMutableArray new];
    self.downloadQueue = dispatch_queue_create("download", NULL);
    self.showFinishedPrompt = YES;
    self.pollForNewFiles = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(self.inkDevice == NULL || self.inkDevice.deviceStatus == DeviceStatusNotConnected) {
        [AppDelegate postNotification:@"Error" withBody:@"InkDevice not connected"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.fileService = NULL;
            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }
    //Attempt to start the ink service
    @try {
        self.fileService = (id<FileTranserService>)[self.inkDevice getService:InkDeviceServiceTypeFileTransfer error:NULL];
    } @catch (NSException *e) {
        NSString *errString = [NSString stringWithFormat:@"Failed to start file transferservice:%@", e.reason];
        [AppDelegate postNotification:@"Error" withBody:errString];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.fileService = NULL;
            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    CGFloat tileSize = 288.0f;
    self.pollForNewFiles = YES;
    
    @try {
    dispatch_async(self.downloadQueue, ^{
        self.fileService.dataReceiver = self;
        
        CGFloat xScale = tileSize / self.deviceHeight;
        CGFloat yScale = tileSize / self.deviceWidth;
        CGFloat scale = fmin(xScale, yScale);
        self.fileService.transform = CGAffineTransformIdentity;
        CGAffineTransform t = CGAffineTransformIdentity;

        if(self.shouldRotateImages) {
            CGFloat rotationAngle = (-M_PI/2.0) + M_PI;
            t = CGAffineTransformScale(t, scale, scale);
            t = CGAffineTransformRotate(t, rotationAngle);
            t = CGAffineTransformConcat(t, CGAffineTransformMake(1, 0, 0, 1, tileSize, 0));
        } else {
            t = CGAffineTransformScale(t, scale, scale);
            [self.fileService setTransform:CGAffineTransformScale(CGAffineTransformIdentity, scale, scale)];
        }
        [self.fileService setTransform:t];

        [self.fileService startWithProvideRawData:YES error:NULL completionHandler:NULL];
    });
    } @catch (NSException *e){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [AppDelegate postNotification:@"Error" withBody:[NSString stringWithFormat:@"%@:%@", @"Failed to start file transder", e.reason]];
            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    self.pollForNewFiles = NO;
    NSError *e;
    [self.fileService endAndReturnError:&e completionHandler:NULL];
    
    if(e != NULL) {
        [AppDelegate postNotification:@"Error" withBody:[NSString stringWithFormat:@"%@: %@", @"Error stopping file transfer service", e.localizedDescription]];
    }
    
}
//========================================================================================================
// MARK: File data delegate
//========================================================================================================

- (void)errorWhileDownloadingFile:(NSError * _Nonnull)error {
    NSLog(@"%@", [NSString stringWithFormat:@"Error during download: %@", error.localizedDescription]);
}

- (void)noMoreFiles {
    if(self.showFinishedPrompt) {
        [AppDelegate postNotification:@"Complete" withBody:@"No more files to download from smartpad"];
    }
    
    self.showFinishedPrompt = NO;
    [self.fileService endAndReturnError:NULL completionHandler:NULL];
    
    //Poll for new files
    __weak FileTransferViewController *w = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if([w pollForNewFiles]) {
            [w.fileService startWithProvideRawData:YES error:NULL completionHandler:NULL];
        }
    });
}



- (enum FileDataReceiverStatus)receiveFileWithFileData:(InkDocument *)fileData remainingFilesCount:(NSInteger)remainingFilesCount {
    [self.downloadedDocuments addObject:fileData];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.showFinishedPrompt = YES;
        NSLog(@"New file recevied from device");
        [self.collectionView reloadData];
    });
    
    //We saved the file that was returned by the device. Sending 'FILESAVED' back to the device will cause the file to be removed from the device memory
    return FileDataReceiverStatusFileSaved;
}

//========================================================================================================
// MARK: UICollection view delegates / datasource
//========================================================================================================

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"previewCell" forIndexPath:indexPath];

    InkDocument *document = self.downloadedDocuments[indexPath.row];
    
    //Get a bezier curve for the document. As we set a scale when the document was downloaded, we can just use the
    //property from the InkDocument directly
    InkGroup *root = [document getRoot];

    void (^nodeProcessor)(InkNode *node);
    
    //Block to iterate the nodes
    nodeProcessor = ^(InkNode *node){
        if([node isKindOfClass:[InkGroup class]]) {
            InkGroup *groupNode = (InkGroup *)node;
            NSInteger currentIdx = 0;
            InkNode *child = [groupNode getChildWithIndex:currentIdx++];
            while (child != NULL) { //Iterate thrould child nodes
                if([child isKindOfClass:[InkStroke class]]) {
                    InkStroke *stroke = (InkStroke *)child;
                    UIBezierPath *bezPath = [stroke bezierPath];
                    if(bezPath != NULL) {
                        CAShapeLayer *shapeLayer = [[CAShapeLayer alloc] init];
                        shapeLayer.path = bezPath.CGPath;
                        shapeLayer.position = CGPointZero;
                        shapeLayer.fillColor = [UIColor blackColor].CGColor;
                        shapeLayer.strokeColor = [UIColor clearColor].CGColor;
                        [cell.layer addSublayer:shapeLayer];
                    }
                }
                
                if([child isKindOfClass:[InkGroup class]]) {
                    nodeProcessor(child);
                }
                child = [groupNode getChildWithIndex:currentIdx++];
            }
        }
    };
    
    nodeProcessor(root);
    return(cell);
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return([self.downloadedDocuments count]);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return(1);
}


@end
