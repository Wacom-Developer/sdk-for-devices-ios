//
//  ViewController.swift
//  WILLDevicesSample
//
//  Created by Joss Giffard-Burley on 13/06/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

import UIKit
import WILLDevices
import WacomLicensing
import UserNotifications


/// This is a basic sample application that demonstrates how to use the Wacom Device SDK for iOS. The basic process for interacting with a device is:
///
///   1. Set the SDK license using the LicenseValidator class
///   2. Register as a delegate for InkDeviceWatcher. This scans for ink capture devices that are visible to the device and reports them to the delegate
///   3. Connect to a specific InkDevice using the InkDeviceFactory to create a new `InkDevice` using the information supplied from the the device watcher
///   4. Request a 'service' from the device (e.g. Real time inking or file transfer) and use the service to gather the required input from the device
///
/// Additional information about the connected device can be read and set via the InkDevice object
class ViewController: UIViewController {
    //========================================================================================================
    // MARK: Properties
    //========================================================================================================
    
    /// The currently connected InkDevice
    var currentInkDevice: InkDevice? {
        didSet {
            if currentInkDevice == nil {
                deviceDetailLabel.text = "No device currently connected"
            } else {
                deviceDetailLabel.text = ""
                //Wire up the event async event handlers. We already set the device status change event in the connnect view so no need to reassign here
                currentInkDevice?.barcodeScanned = { (barcode) -> Void in
                    AppDelegate.postNotification("Barcode data received", bodyText: barcode)
                }
                
                currentInkDevice?.buttonPressed = {
                    AppDelegate.postNotification("Device button pressed", bodyText: "Button Pressed")
                }
                
                currentInkDevice?.deviceBatteryStateChanged = { [weak self] (level, charging) in
                    AppDelegate.postNotification("Battery Event Recevied", bodyText: "Battery level:\(level) charging:\(charging)")
                    self?.currentDeviceDetails.battery = "\(level)%"
                    DispatchQueue.main.async {
                        self?.deviceDetailsTable.reloadRows(at: [IndexPath.init(row: DetailTableRow.battery.rawValue, section: 0)], with: .automatic)
                    }
                }
                
                currentInkDevice?.deviceDisconnected = { [weak self] in
                    AppDelegate.postNotification("Device Disconnected", bodyText: "Disconnected ")
                    self?.currentInkDevice = nil //remove device
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateDeviceDetails()
            }
        }
    }
    
    
    /// Cached list of current device details
    var currentDeviceDetails = DeviceDetails(name: "N/A", ESN: "N/A", width: "N/A", height: "N/A", point: "N/A", battery: "N/A", type: "N/A")
    
    /// Cache of the device type
    var currentDeviceType = DeviceType.unknown
    
    /// The table view that displays the current connected device information
    @IBOutlet var deviceDetailsTable: UITableView!
    
    /// The label used to display the connected device name
    @IBOutlet var deviceDetailLabel: UILabel!
    
    var deivceDetailUpdateQueued = false
    
    let commandQueue = DispatchQueue(label: "CDLTest")
    
    /// A demo license string. You will need to go to http://developer.wacom.com to generate a valid evaluation license
    let licenseString = "*** YOU WILL NEED TO GO TO http://developer.wacom.com TO GENERATE A VALID LICENSE STRING"
    
    /// Enum for ording the table rows
    ///
    /// - name: The device name
    /// - esn: The Serial of the device (if supported)
    /// - width: The width of the device sensor (i.e. the max X value)
    /// - height: The height of the  device sensor
    /// - point: The point caputre rate
    /// - battery: The current battery level
    /// - device: The device class (e.g. smart pad)
    enum DetailTableRow: Int {
        case name = 0
        case esn = 1
        case width = 2
        case height = 3
        case point = 4
        case battery = 5
        case device = 6
    }
    
    
    /// Holds the current device details
    struct DeviceDetails {
        var name: String
        var ESN: String
        var width: String
        var height: String
        var point: String
        var battery: String
        var type: String
    }
    
    @IBOutlet var realTimeInkButton: UIButton!
    
    @IBOutlet var fileTransferButton: UIButton!
    //========================================================================================================
    // MARK: UIView Methods
    //========================================================================================================
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Remove the border from the nav bar
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage  = UIImage()
        
        //Set the license
        do {
            try LicenseValidator.sharedInstance.initLicense(licenseString)
        } catch let e as LicenseValidationException {
            Log("License validation error: " + e.description)
        } catch let e as LicenseRuntimeError {
            Log("License runtime error: " + e.localizedDescription)
        } catch {
            Log("Unkown license error")
        }
        
        deviceDetailsTable.layer.cornerRadius = 2.5
        currentInkDevice = nil
        
        updateDeviceDetails()
    }
    
    var remainingParameters = 0
    
    override func viewDidAppear(_ animated: Bool) {
        //Attempt to reconnect to last paired device. Connection events are reported via delegate
        // Check to see if we have a last connected device
        if let lastDevice = InkDeviceManager.lastConnectedDeviceInfo() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                do {
                    self.currentInkDevice = try InkDeviceManager.connectToDevice(lastDevice, appID: "CDLTestApp", deviceStatusChangedHandler: { [weak self] (oldStatus, newStatus) -> (Void) in
                        let title = "Device Status Changed"
                        let message :String
                        var id :String?
                        switch newStatus {
                        case .notConnected, .busy:
                            return
                        case .idle:
                            message = "Device connected"
                            id = "connected"
                            self?.currentInkDevice?.deviceStatusChanged = nil
                            DispatchQueue.main.async {
                                self?.updateDeviceDetails()
                            }
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
                            message = "Failed to connect to device."
                        case .failedToPair:
                            message = "Failed to pair to device."
                        case .failedToAuthorize:
                            message = "failed to authorize"
                        }
                        if id != nil {
                            AppDelegate.postNotification(title, bodyText: message, id:id!)
                        } else {
                            AppDelegate.postNotification(title, bodyText: message)
                        }
                    })
                } catch let e {
                    AppDelegate.postNotification("Error connecting device", bodyText: e.localizedDescription)
                }
            }
        }
        InkDeviceManager.registerForEvents(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        InkDeviceManager.unregisterForEvents(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is ConnectToDeviceViewController {
            (segue.destination as! ConnectToDeviceViewController).rootVC = self
        }
        
        if segue.destination is RealtimeInkViewController {
            (segue.destination as! RealtimeInkViewController).inkDevice = currentInkDevice
            (segue.destination as! RealtimeInkViewController).deviceWidth = CGFloat((currentDeviceDetails.width as NSString).doubleValue)
            (segue.destination as! RealtimeInkViewController).deviceHeight = CGFloat((currentDeviceDetails.height as NSString).doubleValue)
            (segue.destination as! RealtimeInkViewController).deviceType = currentDeviceType
            //Set the flag to determine if the device is a smartpad or touch input device
            switch currentDeviceType {
            case .applePencil, .bambooFineline, .bambooFineline2, .bambooFineline3, .creativeStylus2, .creativeStylus, .bambooSketch:
                (segue.destination as! RealtimeInkViewController).smartpadDevice = false
            default:
                (segue.destination as! RealtimeInkViewController).smartpadDevice = true
            }
        }
        
        if segue.destination is FileTransferViewController {
            (segue.destination as! FileTransferViewController).inkDevice = currentInkDevice
            (segue.destination as! FileTransferViewController).deviceWidth = CGFloat((currentDeviceDetails.width as NSString).doubleValue)
            (segue.destination as! FileTransferViewController).deviceHeight = CGFloat((currentDeviceDetails.height as NSString).doubleValue)
            (segue.destination as! FileTransferViewController).inkDevice = currentInkDevice
            
            switch currentDeviceType {
            case .bambooPro, .intousPaper: //For these devices, files are already rotated before download
                (segue.destination as! FileTransferViewController).shouldRotateImages = false
            default:
                (segue.destination as! FileTransferViewController).shouldRotateImages = true
            }
            
        }
    }
    
    //========================================================================================================
    // MARK: Instance Methods
    //========================================================================================================
    
    /// Basic log function that dumps data to the console
    ///
    /// - Parameter value: The string to log
    func Log(_ value: String) {
        print("[Log] " + value)
    }
    
    
    /// User tapped on the scan for devices button
    @IBAction func scanButtonTapped() {
        let d = InkDeviceWatcher()
        d.reset()
        currentInkDevice = nil
        performSegue(withIdentifier: "connect", sender: self)
    }
    
    /// User tapped on the 'Real Time Ink' button
    @IBAction func realTimeInkButtonTapped() {
        performSegue(withIdentifier: "realtimeInk", sender: self)
    }
    
    /// User tapped on the 'File Transfer' button
    @IBAction func fileTransferButtonTapped() {
        performSegue(withIdentifier: "fileTransfer", sender: self)
    }
    
    func parseDeviceType(deviceType: Any?) -> (enumValue: DeviceType, stringValue: String) {
        guard let deviceTypeRawValue = deviceType as? NSNumber else {
            return (DeviceType.unknown, "")
        }
        
        guard let deviceType = DeviceType(rawValue: deviceTypeRawValue.intValue) else {
            return (DeviceType.unknown, "")
        }
        
        let deviceTypeString: String
        
        switch deviceType {
        case .applePencil:
            deviceTypeString = "Apple Pencil"
        case .bambooFineline:
            deviceTypeString = "Bamboo Fineline"
        case .bambooFineline2:
            deviceTypeString = "Bamboo Fineline 2"
        case .bambooFineline3:
            deviceTypeString = "Bamboo Fineline 3"
        case .bambooPro:
            deviceTypeString = "Bamboo Pro"
        case .bambooSlateOrFolio:
            deviceTypeString = "Bamboo Slate or Folio"
        case .bambooSpark:
            deviceTypeString = "Bamboo Spark"
        case .clipboardPHU111:
            deviceTypeString = "Wacom Clipboard PHU-111"
        case .creativeStylus:
            deviceTypeString = "Creative Stylus"
        case .creativeStylus2:
            deviceTypeString = "Creative Stylus 2"
        case .intousPaper:
            deviceTypeString = "Intous Pro Paper"
        case .bambooSketch:
            deviceTypeString = "Bamboo Sketch"
        case .unknown:
            deviceTypeString = "Unknown"
        case .montblancAugmentedPaper:
            deviceTypeString = "Montblanc Augmented Paper"
        case .montblancAugmentedPaperPlus:
            deviceTypeString = "Montblanc Augmented Paper Plus"
        }
        
        return (deviceType, deviceTypeString)
    }
    
    /// Update the cached device details
    func updateDeviceDetails() {
        realTimeInkButton.isEnabled = false
        fileTransferButton.isEnabled = false
        
        if currentInkDevice == nil {
            currentDeviceDetails.name = "N/A"
            currentDeviceDetails.ESN = "N/A"
            currentDeviceDetails.width = "N/A"
            currentDeviceDetails.height = "N/A"
            currentDeviceDetails.point = "N/A"
            currentDeviceDetails.battery = "N/A"
            currentDeviceDetails.type = "N/A"
            DispatchQueue.main.async {
                self.deviceDetailsTable.reloadData()
            }
        } else {
            if self.remainingParameters == 0 {
                do {
                    let parametersToGet: [DeviceParameter] = [.deviceName, .pointSize, .batteryLevel, .deviceType, .width, .height, .deviceSerial]
                    remainingParameters = parametersToGet.count
                    try self.currentInkDevice?.getPropertiesAsync(parametersToGet, completionHandler: { (parameter, value, error) -> (Void) in
                        self.remainingParameters -= 1
                        
                        switch parameter {
                        case .deviceName:
                            guard let deviceName = value as? String else {
                                return
                            }
                            
                            self.currentDeviceDetails.name = deviceName
                        case .pointSize:
                            guard let pointSize = value as? Int else {
                                return
                            }
                            
                            self.currentDeviceDetails.point = "\(pointSize)"
                        case .batteryLevel:
                            guard let batteryLevel = value as? Int else {
                                return
                            }
                            
                            self.currentDeviceDetails.battery = "\(batteryLevel)"
                        case .deviceType:
                            let deviceType = self.parseDeviceType(deviceType: value)
                            
                            self.currentDeviceType = deviceType.enumValue
                            self.currentDeviceDetails.type = deviceType.stringValue
                        case .width:
                            guard let width = value as? Int else {
                                return
                            }
                            
                            self.currentDeviceDetails.width = "\(width)"
                        case .height:
                            guard let height = value as? Int else {
                                return
                            }
                            
                            self.currentDeviceDetails.height = "\(height)"
                        case .deviceSerial:
                            guard let serial = value as? String else {
                                return
                            }
                            self.currentDeviceDetails.ESN = "\(serial)"
                        default:
                            break
                        }
                        
                        DispatchQueue.main.async {
                            self.deviceDetailsTable.reloadData()
                        }
                    })
                } catch {
                    print("error -> \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.deviceDetailsTable.reloadData()
                self.realTimeInkButton.isEnabled = true
                self.fileTransferButton.isEnabled = true
            }
        }
    }
}

//========================================================================================================
// MARK: InkDeviceManagerDelegate methods. These report device appear and disapear events
//========================================================================================================

extension ViewController: InkDeviceManagerDelegate {
    func deviceConnected(_ deviceInfo: InkDeviceInfo) {
        //Attempt to reconnect to known devices. Connection events are reported via the delegate methods
        do {
            self.currentInkDevice = try InkDeviceManager.connectToDevice(deviceInfo, appID: "CDLTestApp", deviceStatusChangedHandler: { [weak self] (oldStatus, newStatus) -> (Void) in
                let title = "Device Status Changed"
                let message :String
                var id :String?
                switch newStatus {
                case .notConnected, .busy:
                    return
                case .idle:
                    message = "Device connected"
                    id = "connected"
                    self?.currentInkDevice?.deviceStatusChanged = nil
                    self?.updateDeviceDetails()
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
                    message = "Failed to connect to device."
                case .failedToPair:
                    message = "Failed to pair to device."
                case .failedToAuthorize:
                    message = "failed to authorize"
                }
                if id != nil {
                    AppDelegate.postNotification(title, bodyText: message, id:id!)
                } else {
                    AppDelegate.postNotification(title, bodyText: message)
                }
            })
        } catch let e {
            AppDelegate.postNotification("Error connecting device", bodyText: e.localizedDescription)
        }
    }
    
    func deviceDisconnected(_ deviceInfo: InkDeviceInfo) {
        AppDelegate.postNotification("Device Disconnected", bodyText: "Disconnected ")
        currentInkDevice = nil //remove device
        updateDeviceDetails()
    }
}

//========================================================================================================
// MARK: UITable delegate methods
//========================================================================================================

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for:indexPath)
        
        guard let rowID = DetailTableRow(rawValue: indexPath.row) else {
            return cell
        }
        
        switch rowID {
        case .battery:
            cell.textLabel?.text = "Battery"
            cell.detailTextLabel?.text = currentDeviceDetails.battery
        case .device:
            cell.textLabel?.text = "Device Type"
            cell.detailTextLabel?.text = currentDeviceDetails.type
        case .esn:
            cell.textLabel?.text = "ESN"
            cell.detailTextLabel?.text = currentDeviceDetails.ESN
        case .height:
            cell.textLabel?.text = "Height"
            cell.detailTextLabel?.text = currentDeviceDetails.height
        case .name:
            cell.textLabel?.text = "Name"
            cell.detailTextLabel?.text = currentDeviceDetails.name
        case .point:
            cell.textLabel?.text = "Point"
            cell.detailTextLabel?.text = currentDeviceDetails.point
        case .width:
            cell.textLabel?.text = "Width"
            cell.detailTextLabel?.text = currentDeviceDetails.width
        }
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 7
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let rowID = DetailTableRow(rawValue: indexPath.row) else {
            return
        }
        
        switch rowID {
        case .name:
            print("RENAME")
        default:
            return
        }
    }
}
