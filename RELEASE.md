# CDL iOS

## Version 1.0.21

## History

### 1.0.21
    * Updated build for Swift 5.1.2

### 1.0.20
    * Updated build for Swift 5.1

### 1.0.19
    * Minor bug fixes when getting the firmware versions

### 1.0.18
    * Updated the objc sample app to use the latest public API

### 1.0.17
    * Updated build for Swift 5.0.0

### 1.0.16
    * Fixed an issue with the 'set' operations flow. Set the smart pad device back to .idle mode after performing a 'set' operation

### 1.0.15
    * Added 'ConnectionInterval' as a supported property (getPropertyAsync, setPropertyAsync)

### 1.0.14
    * Fixed an issue in the samples that could cause strokes to be rendered incorrectly
    * Added support for Swift 4.2 and XCode 10
    * Improved error handling reponses from the API when device was in a busy state 

### 1.0.13
    * Fixed an issue that caused invalid binary upload errors from AppStore connect when embedding the framework

### 1.0.12
    * Updated build for Swift 4.1.2
   
### 1.0.11
    * Fixed an issue that caused auto-reconnection to fail on certain PHU-111 devices (CRBCDL-131)
    * Removed references to unsupported arm versions from  sample code
    * Removed evaluation licenses from sample code (evaluation licenses can be generated at http://developer.wacom.com/)

### 1.0.10
    * Updated build for Swift 4.1

### 1.0.9
    * Fixed an issue that prevented some builds being submitted to the AppStore (CRBCDL-120)
    * Added instructions in the sample app for pairing a Wacom Smart Pad device (CRBCDL-122)

### 1.0.8
    * Added missing API documentation 
    * Added BITCODE support (CRBCDL-118)
    * Fixed an issue that caused the 'deviceDisconnected' block being called in certain circumtances (CRBCDL-117)
    * Fixed an error in the Swift sample that caused UI code to be executed outside of the main thread (CRBCDL-119)

### 1.0.7
    * Added Objective-C sample project
    * Exposed RawStroke object to the Objective-C interface
    * Added all InkStroke properties to the Objective-C interface
    * Updated 'DeviceType' property to be returned as an NSNumber object for Objective-C interface

### 1.0.6
    * Fixed an issue causing raw data x & y values to match  

### 1.0.5
    * Added method to auto-reconnect to last known device
    * Added method to retrieve last connected device details
    * Added method to append InkDocument objects together
    * Added method to split InkDocuments on stroke index
    * Added Codable and Serialisation support to InkDocument
    * Fixed bug with license validation from  Objective C
    * Exported 'connectToDevice' method via Objective C bridge

### 1.0.4
    * Add support for Swift 4.0.2 / Xcode 9.1  

### 1.0.3
    * Add support for Swift 4 /Xcode 9
    * Add functionality to list available devices
