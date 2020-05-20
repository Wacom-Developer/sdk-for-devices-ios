//
//  FileTransferViewController.h
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import <UIKit/UIKit.h>
@import WILLDevices;

@interface FileTransferViewController : UIViewController<FileDataReceiver, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) NSObject<InkDevice> *inkDevice;
@property (nonatomic, assign) CGFloat deviceWidth;
@property (nonatomic, assign) CGFloat deviceHeight;
@property (nonatomic, assign) DeviceType deviceType;
@property (nonatomic, assign) BOOL shouldRotateImages;

@end
