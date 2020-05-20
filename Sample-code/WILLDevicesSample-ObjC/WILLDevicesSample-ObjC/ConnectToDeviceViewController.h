//
//  ConnectToDeviceViewController.h
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewController.h"
@import WILLDevicesCore;
@import WILLDevices;


@interface ConnectToDeviceViewController : UIViewController<InkDeviceWatcherDelegate, UITableViewDataSource, UITableViewDelegate>

/// The main VC for the app. This is where we we return the connected ink device
@property (nonatomic, weak) ViewController *rootVC;

@end
