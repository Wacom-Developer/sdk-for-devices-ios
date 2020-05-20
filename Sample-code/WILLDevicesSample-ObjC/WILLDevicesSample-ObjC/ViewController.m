//
//  ViewController.m
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "ConnectToDeviceViewController.h"
#import "RealtimeInkViewController.h"
#import "FileTransferViewController.h"

/// Enum for ording the table rows
///
/// - name: The device name
/// - esn: The Serial of the device (if supported)
/// - width: The width of the device sensor (i.e. the max X value)
/// - height: The height of the  device sensor
/// - point: The point caputre rate
/// - battery: The current battery level
/// - device: The device class (e.g. smart pad)
typedef enum : NSUInteger {
    DeviceDetailName,
    DeviceDetailESN,
    DeviceDetailWidth,
    DeviceDetailHeight,
    DeviceDetailPoint,
    DeviceDetailBattery,
    DeviceDetailDevice
} DetailTableRow;

/// This is a basic sample application that demonstrates how to use the Wacom Device SDK for iOS. The basic process for interacting with a device is:
///
///   1. Set the SDK license using the LicenseValidator class
///   2. Register as a delegate for InkDeviceWatcher. This scans for ink capture devices that are visible to the device and reports them to the delegate
///   3. Connect to a specific InkDevice using the InkDeviceFactory to create a new `InkDevice` using the information supplied from the the device watcher
///   4. Request a 'service' from the device (e.g. Real time inking or file transfer) and use the service to gather the required input from the device
///
/// Additional information about the connected device can be read and set via the InkDevice object
@interface ViewController ()

/// Start realtime inking button
@property (nonatomic, strong) IBOutlet UIButton *realTimeInkButton;

/// Start file transfer button
@property (nonatomic, strong) IBOutlet UIButton *fileTransferButton;

/// Table that contains the current deivce details
@property (nonatomic, strong) IBOutlet UITableView *deviceDetailsTable;

/// Status label
@property (nonatomic, strong) IBOutlet UILabel *deviceDetailLabel;

/// Flag to determine if we already have an update queued
@property (nonatomic, assign) BOOL deviceDetailsUpdateQueued;

/// Command queue for processing events
@property (nonatomic, strong) dispatch_queue_t commandQueue;

@property (nonatomic, assign) DeviceType currentDeviceType;

@property (nonatomic, strong) NSString *currentDeviceName;
@property (nonatomic, strong) NSString *currentDeviceESN;
@property (nonatomic, strong) NSString *currentDeviceWidth;
@property (nonatomic, strong) NSString *currentDeviceHeight;
@property (nonatomic, strong) NSString *currentDevicePoint;
@property (nonatomic, strong) NSString *currentDeviceBattery;
@property (nonatomic, strong) NSString *currentDeviceTypeName;

@end


@implementation ViewController

//========================================================================================================
// MARK: UIView Methods
//========================================================================================================

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.deviceDetailsUpdateQueued = NO;
    self.currentDeviceType = DeviceTypeUnknown;
    
    [[self.navigationController navigationBar] setBackgroundImage:NULL forBarMetrics:UIBarMetricsDefault];
    [[self.navigationController navigationBar] setShadowImage:NULL];
    [[self. navigationController navigationBar] setBackgroundColor:[UIColor clearColor]];
    
    self.commandQueue = dispatch_queue_create("CDLTest", NULL);
    
    //Set the license. You will need to go to http://developer.wacom.com to generate a valid evaluation license.
    NSString *licenseString = @"*** YOU WILL NEED TO GO TO http://developer.wacom.com TO GENERATE A VALID LICENSE STRING";

    NSError *err = NULL;
    [[LicenseValidator sharedInstance] initLicense:licenseString error:&err];
    
    if(err != NULL) {
        [self log:[NSString stringWithFormat:@"License error:%@", [err localizedDescription]]];
    }
    
    [self.deviceDetailsTable.layer setCornerRadius:2.5];
    self.currentInkDevice = NULL;
    
    [self updateDeviceDetails];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //Attempt to reconnect to last device
    InkDeviceInfo* lastDevice = [InkDeviceManager lastConnectedDeviceInfo];
    
    if(lastDevice != NULL) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                NSError *err;
                
                self.currentInkDevice = (NSObject<InkDevice> * _Nullable)[InkDeviceManager connectToDevice:lastDevice appID:@"CDLTest" error:&err deviceStatusChangedHandler:^(DeviceStatus oldStatus,  DeviceStatus newStatus) {
                    NSString *title = @"Device Status Changed";
                    NSString *message;
                    NSString *messageID;
                    
                    switch(newStatus) {
                        case DeviceStatusBusy:
                        case DeviceStatusNotConnected:
                            return;
                            break;
                        case DeviceStatusIdle:
                            message = @"Device connected";
                            messageID = @"connected";
                            self.currentInkDevice.deviceStatusChanged = nil;
                            [self updateDeviceDetails];
                            break;
                        case DeviceStatusSyncing:
                            message = @"Device syncing";
                            break;
                        case DeviceStatusConnecting:
                            message = @"Device connecting";
                            break;
                        case DeviceStatusExpectingButtonTapToConfirmConnection:
                            message = @"Tap device button to confirm connection";
                            break;
                        case DeviceStatusExpectingButtonTapToReconnect:
                            message = @"Tap device button to reconnect";
                            break;
                        case DeviceStatusHoldButtonToEnterUserConfirmationMode:
                            message = @"Hold button to enter user confirmation mode";
                            break;
                        case DeviceStatusAcknowledgeConnectionCofirmationTimeout:
                            message = @"Tap device button to acknowledge user timeout";
                            break;
                        default:
                            break;
                    }
                    if(messageID != NULL) {
                        [AppDelegate postNotification:title withBody:message messageID:messageID];
                    } else {
                        [AppDelegate postNotification:title withBody:message];
                        
                    }
                }];
            } @catch (NSException *exception) {
                [AppDelegate postNotification:@"Error connecet device" withBody:exception.description];
            }
        });
        [InkDeviceManager registerForEvents:self];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [InkDeviceManager unregisterForEvents:self];
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.destinationViewController isKindOfClass:[ConnectToDeviceViewController class]]) {
        ((ConnectToDeviceViewController *)segue.destinationViewController).rootVC = self;
    }
    
    if([segue.destinationViewController isKindOfClass:[RealtimeInkViewController class]]) {
        ((RealtimeInkViewController *)segue.destinationViewController).inkDevice = self.currentInkDevice;
        ((RealtimeInkViewController *)segue.destinationViewController).deviceWidth = [self.currentDeviceWidth doubleValue];
        ((RealtimeInkViewController *)segue.destinationViewController).deviceHeight = [self.currentDeviceHeight doubleValue];
        ((RealtimeInkViewController *)segue.destinationViewController).deviceType = self.currentDeviceType;
    }
    
    if([segue.destinationViewController isKindOfClass:[FileTransferViewController class]]) {
        ((FileTransferViewController *)segue.destinationViewController).inkDevice = self.currentInkDevice;
        ((FileTransferViewController *)segue.destinationViewController).deviceWidth = [self.currentDeviceWidth doubleValue];
        ((FileTransferViewController *)segue.destinationViewController).deviceHeight = [self.currentDeviceHeight doubleValue];
        ((FileTransferViewController *)segue.destinationViewController).deviceType = self.currentDeviceType;
        
        if(self.currentDeviceType == DeviceTypeBambooPro || self.currentDeviceType == DeviceTypeIntousPaper) {
            ((FileTransferViewController *)segue.destinationViewController).shouldRotateImages = NO;
        } else {
            ((FileTransferViewController *)segue.destinationViewController).shouldRotateImages = YES;
        }
    }
    
}

//=====================================================================================================
// MARK: Button  Methods
//========================================================================================================

- (IBAction)scanButtonTapped {
    InkDeviceWatcher *d = [InkDeviceWatcher new];
    [d reset];
    self.currentInkDevice = NULL;
    [self performSegueWithIdentifier:@"connect" sender:self];
}

/// User tapped on the 'Real Time Ink' button
- (IBAction) realTimeInkButtonTapped {
    [self performSegueWithIdentifier:@"realtimeInk" sender:self];
}

/// User tapped on the 'File Transfer' button
- (IBAction) fileTransferButtonTapped {
    [self performSegueWithIdentifier:@"fileTransfer" sender:self];
}

//=====================================================================================================
// MARK: Utility  Methods
//========================================================================================================

/**
 Logs a simple value to the conosle
 
 @param value The text to dump
 */
- (void)log:(NSString *)value {
    NSLog(@"[Log] %@", value);
}


//=====================================================================================================
// MARK: Custom accessors
//======================================================================================================

- (void)setCurrentInkDevice:(NSObject<InkDevice> *)currentInkDevice {
    __weak ViewController *weakSelf = self;
    _currentInkDevice = currentInkDevice;
    
    if(self.currentInkDevice == NULL) {
        [self.deviceDetailLabel setText:@"No device currently connected"];
    } else {
        [self.deviceDetailLabel setText:@""];
        
        //Wire up the event async event handlers. We already set the device status change event in the connnect view so no need to reassign here
        [self.currentInkDevice setBarcodeScanned:^(NSString * _Nonnull barcode) {
            [AppDelegate postNotification:@"Barcode data received" withBody:barcode];
        }];
        
        [self.currentInkDevice setButtonPressed:^{
            [AppDelegate postNotification:@"Device button pressed" withBody:@"Button Pressed"];
            
        }];
        
        
        [self.currentInkDevice setDeviceBatteryStateChanged:^(NSInteger value, BOOL charging) {
            NSString *body = [NSString stringWithFormat:@"Battery level: %ld Charing: %@", (long)value, charging ? @"Yes" : @"No "];
            [AppDelegate postNotification:@"Battery event" withBody:body];
            
            weakSelf.currentDeviceBattery = [NSString stringWithFormat:@"%ld%@", value, @"%"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[weakSelf deviceDetailsTable] reloadData];
            });
        }];
        
        [self.currentInkDevice setDeviceDisconnected:^{
            [AppDelegate postNotification:@"Device Disconnected" withBody:@"Button Pressed"];
            [weakSelf setCurrentInkDevice:NULL];
        }];
        
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf updateDeviceDetails];
    });
}



- (void)updateDeviceDetails {
    self.deviceDetailsUpdateQueued = NO;
    [self.realTimeInkButton setEnabled:NO];
    [self.fileTransferButton setEnabled:NO];
    __weak ViewController *weakself = self;
    
    if(self.currentInkDevice == NULL) {
        self.currentDeviceName = @"N/A";
        self.currentDeviceESN = @"N/A";
        self.currentDeviceWidth = @"N/A";
        self.currentDeviceHeight = @"N/A";
        self.currentDevicePoint = @"N/A";
        self.currentDeviceBattery = @"N/A";
        self.currentDeviceTypeName = @"N/A";
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakself.deviceDetailsTable reloadData];
        });
    } else {
        //Device Name
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterDeviceName error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        weakself.currentDeviceName = (NSString *)value;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailName inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
            } @catch(NSException *exception) {
                weakself.currentDeviceName = exception.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailName inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
            }
        });        //Battery Level
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterBatteryLevel error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        int currentBatteryLevel = (int)value;
                        weakself.currentDeviceBattery = [NSString stringWithFormat:@"%d", currentBatteryLevel];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailBattery inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
            } @catch (NSException *e) {
                weakself.currentDeviceBattery = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailBattery inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        //Point size
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterPointSize error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        NSNumber *currentPointRate = (NSNumber *)value;
                        weakself.currentDevicePoint = [NSString stringWithFormat:@"%d", [currentPointRate intValue]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailPoint inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
            } @catch (NSException *e) {
                weakself.currentDeviceBattery = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailPoint inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        //Battery Level
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterBatteryLevel error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        int currentBatteryLevel = (int)value;
                        weakself.currentDeviceBattery = [NSString stringWithFormat:@"%d", currentBatteryLevel];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailBattery inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
                
            } @catch (NSException *e) {
                weakself.currentDeviceBattery = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailBattery inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        //device type
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterDeviceType error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        //Value is NSNUmber
                        NSNumber *tt = (NSNumber *)value;
                        DeviceType t = [tt integerValue];
                        NSString *stringDeviceValue;
                        self.currentDeviceType = t;
                        
                        switch (t) {
                            case DeviceTypeBambooSpark:
                                stringDeviceValue = @"Bamboo Spark";
                                break;
                            case DeviceTypeBambooSlateOrFolio:
                                stringDeviceValue = @"Bamboo Slate or Folio";
                                break;
                            case DeviceTypeIntousPaper:
                                stringDeviceValue = @"Intous Pro Paper";
                                break;
                            case DeviceTypeBambooPro:
                                stringDeviceValue = @"Bamboo Pro";
                                break;
                            case DeviceTypeClipboardPHU111:
                                stringDeviceValue = @"Wacom Clipboard PHU-111";
                                break;
                            case DeviceTypeApplePencil:
                                stringDeviceValue = @"Apple Pencil";
                                break;
                            case DeviceTypeCreativeStylus:
                                stringDeviceValue = @"Creative Stylus";
                                break;
                            case DeviceTypeCreativeStylus2:
                                stringDeviceValue = @"Creative Stylus 2";
                                break;
                            case DeviceTypeBambooFineline:
                                stringDeviceValue = @"Bamboo Fineline";
                                break;
                            case DeviceTypeBambooFineline2:
                                stringDeviceValue = @"Bamboo Fineline 2";
                                break;
                            case DeviceTypeBambooFineline3:
                                stringDeviceValue = @"Bamboo Fineline 3";
                                break;
                            case DeviceTypeBambooSketch:
                                stringDeviceValue = @"Bamboo Sketch";
                                break;
                            default:
                                stringDeviceValue = @"Unknown";
                                self.currentDeviceType = DeviceTypeUnknown;
                                break;
                        }
                        
                        weakself.currentDeviceTypeName = stringDeviceValue;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailDevice inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
                
            } @catch (NSException *e) {
                weakself.currentDeviceTypeName = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailDevice inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        //Width
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterWidth error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        NSNumber *currentWidth = (NSNumber *)value;
                        
                        if(currentWidth == 0 && !weakself.deviceDetailsUpdateQueued) {
                            weakself.deviceDetailsUpdateQueued = YES;
                            [weakself updateDeviceDetails];
                        }
                        
                        weakself.currentDeviceWidth = [NSString stringWithFormat:@"%d", [currentWidth intValue]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailWidth inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
                
            } @catch (NSException *e) {
                weakself.currentDeviceBattery = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailWidth inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        //Height
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterHeight error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        NSNumber *currentHeight = (NSNumber *)value;
                        
                        if(currentHeight == 0 && !weakself.deviceDetailsUpdateQueued) {
                            weakself.deviceDetailsUpdateQueued = YES;
                            [weakself updateDeviceDetails];
                        }
                        
                        weakself.currentDeviceHeight = [NSString stringWithFormat:@"%d", [currentHeight intValue]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailHeight inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
                
            } @catch (NSException *e) {
                weakself.currentDeviceBattery = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailHeight inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        //Serial
        dispatch_async(self.commandQueue, ^{
            NSError *err;
            
            if(weakself.currentInkDevice == NULL) {
                return;
            }
            
            while (weakself.currentInkDevice.deviceStatus != DeviceStatusIdle) {
                usleep(50000);
            }
            
            @try {
                [weakself.currentInkDevice getPropertyAsync:DeviceParameterDeviceSerial error:&err completionHandler:^(id _Nullable value, NSError * _Nullable err) {
                    if(err == NULL && value != NULL) {
                        weakself.currentDeviceESN = (NSString *)value;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailESN inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        });
                    }
                }];
                
            } @catch (NSException *e) {
                weakself.currentDeviceBattery = e.reason;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakself.deviceDetailsTable reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:DeviceDetailESN inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
                
            }
        });
        
        dispatch_async(self.commandQueue, ^{
            usleep(20000);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.deviceDetailsTable reloadData];
                [self.realTimeInkButton setEnabled:YES];
                [self.fileTransferButton setEnabled:YES];
            });
        });
    }
    
}

//========================================================================================================
// MARK: InkDeviceManagerDelegate methods. These report device appear and disapear events
//========================================================================================================

- (void)deviceConnected:(InkDeviceInfo *)deviceInfo {
    NSError *err;
    
    @try {
        self.currentInkDevice = (NSObject<InkDevice> * _Nullable)[InkDeviceManager connectToDevice:deviceInfo appID:@"CDLTest" error:&err deviceStatusChangedHandler:^(DeviceStatus oldStatus,  DeviceStatus newStatus) {
            NSString *title = @"Device Status Changed";
            NSString *message;
            NSString *messageID;
            
            switch(newStatus) {
                case DeviceStatusBusy:
                case DeviceStatusNotConnected:
                    return;
                    break;
                case DeviceStatusIdle:
                    message = @"Device connected";
                    messageID = @"connected";
                    self.currentInkDevice.deviceStatusChanged = nil;
                    [self updateDeviceDetails];
                    break;
                case DeviceStatusSyncing:
                    message = @"Device syncing";
                    break;
                case DeviceStatusConnecting:
                    message = @"Device connecting";
                    break;
                case DeviceStatusExpectingButtonTapToConfirmConnection:
                    message = @"Tap device button to confirm connection";
                    break;
                case DeviceStatusExpectingButtonTapToReconnect:
                    message = @"Tap device button to reconnect";
                    break;
                case DeviceStatusHoldButtonToEnterUserConfirmationMode:
                    message = @"Hold button to enter user confirmation mode";
                    break;
                case DeviceStatusAcknowledgeConnectionCofirmationTimeout:
                    message = @"Tap device button to acknowledge user timeout";
                    break;
                default:
                    break;
            }
            if(messageID != NULL) {
                [AppDelegate postNotification:title withBody:message messageID:messageID];
            } else {
                [AppDelegate postNotification:title withBody:message];
            }
            
            
        }];
    } @catch (NSException *exception) {
         [AppDelegate postNotification:@"Error connecet device" withBody:exception.description];
    }
}

- (void)deviceDisconnected:(InkDeviceInfo *)deviceInfo {
    [AppDelegate postNotification:@"Device Disconnected" withBody:@"Disconnected"];
    self.currentInkDevice = NULL;
    [self updateDeviceDetails];
}

//UITable Methods
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    if(cell == NULL) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    
    DetailTableRow rowID = indexPath.row;

    switch (rowID) {
            
        case DeviceDetailName:
            cell.textLabel.text = @"Name";
            cell.detailTextLabel.text = self.currentDeviceName;
            break;
        case DeviceDetailESN:
            cell.textLabel.text = @"ESN";
            cell.detailTextLabel.text = self.currentDeviceESN;
            break;
        case DeviceDetailWidth:
            cell.textLabel.text = @"Width";
            cell.detailTextLabel.text = self.currentDeviceWidth;
            break;
        case DeviceDetailHeight:
            cell.textLabel.text = @"Height";
            cell.detailTextLabel.text = self.currentDeviceHeight;
            break;
        case DeviceDetailPoint:
            cell.textLabel.text = @"Point";
            cell.detailTextLabel.text = self.currentDevicePoint;
            break;
        case DeviceDetailBattery:
            cell.textLabel.text = @"Battery";
            cell.detailTextLabel.text = self.currentDeviceBattery;
            break;
        case DeviceDetailDevice:
            cell.textLabel.text = @"Device Type";
            cell.detailTextLabel.text = self.currentDeviceTypeName;
            break;
    }
    
    return(cell);
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 7;
}

@end



