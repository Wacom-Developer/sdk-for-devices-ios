//
//  RealtimeInkViewController.swift
//  WILLDevicesSample
//
//  Created by Joss Giffard-Burley on 17/07/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

import UIKit
import WILLDevices
import WILLDevicesCore
import WILLInk

class RealtimeInkViewController: UIViewController {
    //========================================================================================================
    // MARK: Properties
    //========================================================================================================
    
    /// The connected ink device
    weak var inkDevice: InkDevice?
    
    @IBOutlet var drawingView: UIView!
    var renderView: RenderingView!
    
    /// The realtime inking service provided by the device
    var realtimeService: RealTimeInkService?
    
    public var deviceWidth: CGFloat = 100.0
    public var deviceHeight: CGFloat = 100.0
    
    //used to work out if we need to rotate the device
    public var deviceType: DeviceType = .unknown
    
    /// is our input device a smart pad type?
    public var smartpadDevice = true
    
    /// The list of devices that have the sensor 90 to portrait
    private let rotatedDevices: [DeviceType] = [
        .bambooPro,
        .bambooSlateOrFolio
    ]
    
    //========================================================================================================
    // MARK: UIView Methods
    //========================================================================================================
    
    override func viewWillAppear(_ animated: Bool) {
        drawingView.backgroundColor = UIColor.white
        if inkDevice == nil || (inkDevice?.deviceStatus ?? .notConnected) == .notConnected {
            AppDelegate.postNotification("Error", bodyText: "InkDevice not connected")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.realtimeService = nil
                self?.navigationController?.popViewController(animated: true)
            }
        }
        //Attempt to start the ink service
            do {
                try self.realtimeService = self.inkDevice?.getService(.realtimeInk) as? RealTimeInkService
            } catch (let e) {
                AppDelegate.postNotification("Error", bodyText: "Failed to start realtime ink service:\(e.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.realtimeService = nil
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    
    
    override func viewDidAppear(_ animated: Bool) {
        //Start the realtime service
        renderView = RenderingView(frame: drawingView.bounds)
        drawingView.addSubview(renderView)
        
        print("Render view bounds: \(NSCoder.string(for: renderView.bounds))")
        
        do {
            realtimeService?.dataReceiver = self //Receive the point data
            let screenWidth = drawingView.bounds.size.width
            let screenHeight = drawingView.bounds.size.height
            if smartpadDevice {
                //For bamboo device, the data should be rotated
                if rotatedDevices.contains(deviceType) {
                    let xScale = screenWidth / deviceHeight
                    let yScale = screenHeight / deviceWidth
                    let scale = fmin(xScale, yScale) //So we have 1:1 scale
                    let rotationAngle = (-CGFloat.pi/2.0) + .pi
                    realtimeService?.transform = CGAffineTransform(scaleX: scale, y: scale).rotated(by: rotationAngle).concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: fmin(screenWidth, screenHeight), ty: 0))
                } else {
                    let xScale = screenWidth / deviceWidth
                    let yScale = screenHeight / deviceHeight
                    let scale = fmin(xScale, yScale) //So we have 1:1 scale

                    realtimeService?.transform = CGAffineTransform(scaleX: scale, y: scale)
                }
                
            } else { //Set the UIView for input to be the rendering view
                realtimeService?.transform = CGAffineTransform.identity
                realtimeService?.inputView = drawingView
            }
            try realtimeService?.start(provideRawData: true) {success, error in
                print("realtime service start")
                print("success -> \(success)")
                print("error -> \(String(describing: error))")
            }
        } catch (let e) {
            AppDelegate.postNotification("Error", bodyText: "Failed to start realtime ink service:\(e.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        //Stop service and dispose
        guard let s = realtimeService else {
            return
        }
        
        do {
            try s.end(completionHandler: { (success, error) in
                print("realtime service end")
                print("success -> \(success)")
                print("error -> \(String(describing: error))")
            })
        } catch (let e) {
            AppDelegate.postNotification("Error", bodyText: "Error closing ink serivce:\(e.localizedDescription)")
        }
    }
    
}

//========================================================================================================
// MARK: CDL Stroke Receiver
//========================================================================================================

extension RealtimeInkViewController: StrokeDataReceiver {
    func strokeBegan(penID: Data, inputDeviceType: ToolType, inkColor: UIColor, pathChunk: WCMFloatVector) {
        renderView.addStrokePart(pathChunk, isEnd: false)
    }
    
    func strokeMoved(pathChunk: WCMFloatVector) {
        renderView.addStrokePart(pathChunk, isEnd: false)
    }
    
    func strokeEnded(pathChunk: WCMFloatVector?, inkStroke: InkStroke, cancelled: Bool) {
        renderView?.addStrokePart(pathChunk, isEnd: true)
        if let bez = inkStroke.bezierPath {
            renderView.addStrokeBezier(bez)
        }
    }
    
    func hoverStrokeReceived(path: [RawPoint]) {
        //    print("(\(path.count) hover points received")
    }
    
    func pointsLost(count: Int) {
        //   print("** LOST \(count) points")
    }
    
    func newLayerAdded() {
        //   print("New layer")
    }
}
