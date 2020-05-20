//
//  ConnectToDeviceViewController.m
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import "ConnectToDeviceViewController.h"
#import "AppDelegate.h"
@import WILLDevicesCore;
@import WILLDevices;

@interface ConnectToDeviceViewController ()

/// The InkDeviceWatcher scans for all ink capture devices and returns device information for connection
@property (nonatomic, strong) InkDeviceWatcher *inkWatcher;

/// The table view that is used to
@property (nonatomic, strong) IBOutlet UITableView *deviceTable;

/// The connect to device button
@property (nonatomic, strong) IBOutlet UIButton *connectButton;

/// The collection of currently discoverable devices
@property (nonatomic, strong) NSMutableArray<InkDeviceInfo *> *discoveredDevices;

/// Info of the current connecting device 
@property (nonatomic, strong) NSObject<InkDevice> * _Nullable connectingInkDevice;


@end

@implementation ConnectToDeviceViewController

//========================================================================================================
// MARK: UIView Methods
//========================================================================================================

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.inkWatcher = [InkDeviceWatcher new];
    self.discoveredDevices = [NSMutableArray<InkDeviceInfo *> new];
    self.inkWatcher.delegate = self;
    self.deviceTable.layer.cornerRadius = 2.5;
    self.deviceTable.tableFooterView = [UIView new];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.inkWatcher stop];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.connectingInkDevice = NULL;
    //Reset any existing data
    [self.inkWatcher reset];
    //Start scanning for devices
    [self.inkWatcher start];
}

//========================================================================================================
// MARK: Button actions
//========================================================================================================

- (IBAction)connectButtonTapped {
    NSIndexPath *selectedPath = self.deviceTable.indexPathForSelectedRow;
    
    if(selectedPath == NULL) {
        return;
    }
    
    NSInteger idx = selectedPath.row;
    
    if(idx >= [self.discoveredDevices count]) {
        return;
    }
    
    @try {
        InkDeviceInfo *connectingDevice = self.discoveredDevices[idx];
        [self.inkWatcher stop];
        [self.discoveredDevices removeAllObjects];
        [self.deviceTable reloadData];
        NSError *err;
        
        self.connectingInkDevice = (NSObject<InkDevice> *)[InkDeviceManager connectToDevice:connectingDevice appID:@"CDLTest" error:&err deviceStatusChangedHandler:^(DeviceStatus oldStatus,  DeviceStatus newStatus) {
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
                    self.connectingInkDevice.deviceStatusChanged = nil;
                    [self updateInkDevice];
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
                case DeviceStatusFailedToConnect:
                    message = @"Failed to connect to device. Restarting scan.";
                    [self.inkWatcher start];
                    break;
                case DeviceStatusFailedToPair:
                    message = @"Failed to pair to device. Restarting scan.";
                    [self.inkWatcher start];
                    break;
                case DeviceStatusFailedToAuthorize:
                    message = @"Failed to authorize device. Restarting scan.";
                    [self.inkWatcher start];
                    break;
            }
            if(messageID != NULL) {
                [AppDelegate postNotification:title withBody:message messageID:messageID];
            } else {
                [AppDelegate postNotification:title withBody:message];

            }
        }];

    } @catch(NSException *e) {
        [AppDelegate postNotification:@"Error connecting to device" withBody:e.reason];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}
/// Updates the ink device on rootVC
- (void)updateInkDevice {
    if(self.connectingInkDevice != NULL) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.rootVC.currentInkDevice = self.connectingInkDevice;
            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }
}

//========================================================================================================
// MARK: InkDeviceWatcher delegate methods
//========================================================================================================


- (void)deviceAdded:(InkDeviceWatcher * _Nonnull)watcher device:(InkDeviceInfo * _Nonnull)device {
    [self.discoveredDevices addObject:device];
    [self.deviceTable reloadData];
}

- (void)deviceRemoved:(InkDeviceWatcher * _Nonnull)watcher device:(InkDeviceInfo * _Nonnull)device {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![device isEqual:evaluatedObject];
    }];
    [self.discoveredDevices filterUsingPredicate:predicate];
    [self.deviceTable reloadData];
}

//========================================================================================================
// MARK: UITableView delegate methods
//========================================================================================================

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if([self.discoveredDevices count] > 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"deviceCell"];
        if(cell == NULL) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"deviceCell"];
        }
        
        cell.textLabel.text = self.discoveredDevices[indexPath.row].name;
        return(cell);
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"blank"];
        if(cell == NULL) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"blank"];
        }
        return(cell);
    }
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if([self.discoveredDevices count] == 0) {
        return(1);
    } else {
        return([self.discoveredDevices count]);
    }
}

- (nullable NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if([tableView indexPathForSelectedRow] == indexPath) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self.connectButton setEnabled:NO];
        return NULL;
    } else {
        [self.connectButton setEnabled:YES];
        return(indexPath);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if([self.discoveredDevices count] > 0) {
        return(44);
    } else {
        return(tableView.frame.size.height);
    }
}

@end
