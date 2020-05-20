//
//  ViewController.h
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import <UIKit/UIKit.h>
@import WacomLicensing;
@import WILLDevices;
@import WILLDevicesCore;
@import WILLInk;

/// This is a basic sample application that demonstrates how to use the Wacom Device SDK for iOS. The basic process for interacting with a device is:
///
///   1. Set the SDK license using the LicenseValidator class
///   2. Register as a delegate for InkDeviceWatcher. This scans for ink capture devices that are visible to the device and reports them to the delegate
///   3. Connect to a specific InkDevice using the InkDeviceFactory to create a new `InkDevice` using the information supplied from the the device watcher
///   4. Request a 'service' from the device (e.g. Real time inking or file transfer) and use the service to gather the required input from the device
///
/// Additional information about the connected device can be read and set via the InkDevice object
@interface ViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>

/**
 The currently connected ink device
 */
@property (nullable, nonatomic) NSObject<InkDevice> *currentInkDevice;

@end

