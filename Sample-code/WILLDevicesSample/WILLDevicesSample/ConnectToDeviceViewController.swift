//
//  ConnectToDeviceViewController.swift
//  WILLDevicesSample
//
//  Created by Joss Giffard-Burley on 17/07/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

import UIKit
import WILLDevices

/// Start a new ink watcher and scan for new devices. If the user selects a device in the table view and taps connect, attempt to connect to the selected device.
/// To discover a Smart Pad device during the scan, you will need to hold the button on the device for 6 seconds to allow the device to enter discovery mode
class ConnectToDeviceViewController: UIViewController {
    //========================================================================================================
    // MARK: Properties
    //========================================================================================================

    /// The main VC for the app. This is where we we return the connected ink device
    weak var rootVC: ViewController?
    
    /// The InkDeviceWatcher scans for all ink capture devices and returns device information for connection
    let inkWatcher = InkDeviceWatcher()
    
    /// The table view that is used to
    @IBOutlet var deviceTable: UITableView!
    
    /// The connect to device button
    @IBOutlet var connectButton: UIButton!
    
    /// The collection of currently discoverable devices
    var discoveredDevices = [InkDeviceInfo]()
    
    var connectingInkDevice: InkDevice?
    
    //========================================================================================================
    // MARK: UIView Methods
    //========================================================================================================

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the inkwatcher delegate
        inkWatcher.delegate = self
        deviceTable.layer.cornerRadius = 2.5
        deviceTable.tableFooterView = UIView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        //Stop the scanner
        inkWatcher.stop()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //Start scanning for devices
        connectingInkDevice = nil
      
        //Reset any existing
        inkWatcher.reset()
        
        //Start scan
        inkWatcher.start()
    }

    //========================================================================================================
    // MARK: Button actions
    //========================================================================================================

    @IBAction func connectButtonTapped() {
        //Get the selected device info
        guard let idx = deviceTable.indexPathForSelectedRow?.row, idx < discoveredDevices.count else {
            return
        }
        
        let deviceInfo = discoveredDevices[idx]
    
        //Attempt to create a new ink device using the inkdevice factory. The device status change block will
        //be automatically assigned to the underlying InkDevice in the case of successful connection. Possible
        //errors that can be thrown by this call are connection errors and license errors.
        
        do {
            inkWatcher.stop()
            discoveredDevices.removeAll()
            deviceTable.reloadData()
            
            connectingInkDevice = try InkDeviceManager.connectToDevice(deviceInfo, appID: "CDLTestApp", deviceStatusChangedHandler: { [weak self] (oldStatus, newStatus) -> (Void) in
                let title = "Device Status Changed"
                let message :String
                var id :String?
                switch newStatus {
                case .notConnected, .busy:
                    return
                case .idle:
                    message = "Device connected"
                    id = "connected"
                    self?.connectingInkDevice?.deviceStatusChanged = nil
                    self?.updateInkDevice()
                    
                case .syncing:
                    message = "Device syncing"
                case .connecting:
                    message = "Device connecting"
                case .expectingButtonTapToConfirmConnection:
                    message = "Tap device button to confirm connection"
                case .expectingButtonTapToReconnect:
                    message = "Tap device button to reconnect"
                case .holdButtonToEnterUserConfirmationMode:
                    message = "Hold button to enter user confirmation mode"
                case .acknowledgeConnectionCofirmationTimeout:
                    message = "Tap device button to acknowledge user timeout"
                case .failedToConnect:
                    message = "Failed to connect to device. Restarting scan."
                    self?.inkWatcher.start()
                case .failedToPair:
                    message = "Failed to pair to device. Restarting scan."
                    self?.inkWatcher.start()
                case .failedToAuthorize:
                    message = "Failed to authorize device. Restarting scan."
                    self?.inkWatcher.start()
                }
                if id != nil {
                    AppDelegate.postNotification(title, bodyText: message, id:id!)
                } else {
                    AppDelegate.postNotification(title, bodyText: message)
                }
            })
        } catch let e {
            AppDelegate.postNotification("Error connecting device", bodyText: e.localizedDescription)
            navigationController?.popToRootViewController(animated: true)
        }
        
    }
    
    
    /// Updates the ink device on the rootVC
    func updateInkDevice() {
        if connectingInkDevice != nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.rootVC?.currentInkDevice = self?.connectingInkDevice
            self?.navigationController?.popToRootViewController(animated: true)
        }
        }
    }

}

//========================================================================================================
// MARK: InkDeviceWatcher delegate methods
//========================================================================================================

extension ConnectToDeviceViewController: InkDeviceWatcherDelegate {
    /// A new `InkDevice` was detected by the ink watcher
    ///
    /// - Parameters:
    ///   - watcher: The watcher that detected the device
    ///   - device: The device info that discovered
    func deviceAdded(_ watcher: InkDeviceWatcher, device: InkDeviceInfo) {
        discoveredDevices.append(device)
        deviceTable.reloadData()
    }

    /// A previously discovered device has been disconnected.
    ///
    /// - Parameters:
    ///   - watcher: The watcher that dected the device
    ///   - device: The device that was discovered
    func deviceRemoved(_ watcher: InkDeviceWatcher, device: InkDeviceInfo) {
        discoveredDevices = discoveredDevices.filter { $0 != device }
        deviceTable.reloadData()
    }
}

//========================================================================================================
// MARK: UITableView delegate methods
//========================================================================================================

extension ConnectToDeviceViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if tableView.indexPathForSelectedRow == indexPath {
           tableView.deselectRow(at: indexPath, animated: true)
            connectButton.isEnabled = false
            return nil
        } else {
            connectButton.isEnabled = true
            return indexPath
        }
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if discoveredDevices.count == 0 { //Create the empty table view
            return 1
        } else {
            return discoveredDevices.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if discoveredDevices.count > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "deviceCell", for:indexPath)
            cell.textLabel?.text = discoveredDevices[indexPath.row].name
            return cell
        } else {
           return tableView.dequeueReusableCell(withIdentifier: "blankCell", for:indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if discoveredDevices.count > 0 {
            return 44.0
        } else {
            return tableView.frame.size.height
        }
    }
}

