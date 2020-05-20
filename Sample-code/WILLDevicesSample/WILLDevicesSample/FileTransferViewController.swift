//
//  FileTransferViewController.swift
//  WILLDevicesSample
//
//  Created by Joss Giffard-Burley on 17/07/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

import UIKit
import WILLDevices
import WILLDevicesCore
import WILLInk


/// This view visualises files downloaded from the device. Once a file has been downloaded from the device, it
/// will be removed. Files are displayed in a simple collection view that displays the UIBezierCurve of the strokes
/// for the file as the file thumbnail.
class FileTransferViewController: UIViewController {
    //========================================================================================================
    // MARK: Properties
    //========================================================================================================
    
    /// The connected ink device
    weak var inkDevice: InkDevice?
    
    /// The file transfer service provided by the device
    var fileService: FileTranserService?
    
    public var deviceWidth: CGFloat = 100.0
    public var deviceHeight: CGFloat = 100.0
    
    /// The list of downloaded documents from the device
    var downloadedDocuments = [InkDocument]()
    
    /// Background download queue
    let downloadQueue = DispatchQueue(label: "download")
    
    /// The collection view used to render samples of the files recevied
    @IBOutlet var collectionView: UICollectionView!
    
    /// Flag to stop spamming when we are polling for files
    internal var showFinishedPrompt = true
    
    /// Flag to see if we should be polling for new files
    internal var pollForNewFiles = true
    
    /// SHould we rotate the recevied files to match orientation
    internal var shouldRotateImages = true
    
    //========================================================================================================
    // MARK: UIView Methods
    //========================================================================================================
    
    override func viewWillAppear(_ animated: Bool) {
        if inkDevice == nil || (inkDevice?.deviceStatus ?? .notConnected) == .notConnected {
            AppDelegate.postNotification("Error", bodyText: "InkDevice not connected")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fileService = nil
                self.navigationController?.popViewController(animated: true)
            }
        }
        //Attempt to start the ink service
        do {
            try self.fileService = self.inkDevice?.getService(.fileTransfer) as? FileTranserService
        } catch (let e) {
            AppDelegate.postNotification("Error", bodyText: "Failed to start file transferservice:\(e.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { 
                self.fileService = nil
                self.navigationController?.popViewController(animated: true)
            }
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let tileSize = CGFloat(288.0)
        pollForNewFiles = true

        downloadQueue.async {
        do {
            self.fileService?.dataReceiver = self //Receive the point data
            //Set the scale to match the render tile size.
            let xScale = tileSize / self.deviceHeight
            let yScale = tileSize / self.deviceWidth
            let scale = fmin(xScale, yScale) //So we have 1:1 scale
            
            if self.shouldRotateImages {
                let rotationAngle = (-CGFloat.pi/2.0) + .pi
                self.fileService?.transform = CGAffineTransform(scaleX: scale, y: scale).rotated(by: rotationAngle).concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: tileSize, ty: 0))
            } else {
                self.fileService?.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
            
            try self.fileService?.start(provideRawData: true) {success, error in
                print("file service start")
                print("success -> \(success)")
                print("error -> \(String(describing: error))")
            }
        } catch (let e) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AppDelegate.postNotification("Error", bodyText: "Failed to start realtime ink service:\(e.localizedDescription)")
                self.navigationController?.popViewController(animated: true)
            }
            }
        }
        AppDelegate.postNotification("Starting file download", bodyText: "Getting files from device")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        //Stop service and dispose
        guard let s = fileService else {
            return
        }
        pollForNewFiles = false
        do {
            try s.end(completionHandler: { (success, error) in
                print("file service end")
                print("success -> \(success)")
                print("error -> \(String(describing: error))")
            })
        } catch (let e) {
            AppDelegate.postNotification("Error", bodyText: "Error closing ink serivce:\(e.localizedDescription)")
        }
    }
    
}

//========================================================================================================
// MARK: File data delegate
//========================================================================================================

extension FileTransferViewController: FileDataReceiver {
    func noMoreFiles() {
        if showFinishedPrompt {
            AppDelegate.postNotification("Complete", bodyText: "No more files to download from smartpad")
        }
        
        showFinishedPrompt = false
        ((try? fileService?.end(completionHandler: { (success, error) in
            print("file service end")
            print("success -> \(success)")
            print("error -> \(String(describing: error))")
        })) as ()??)
        
        //Poll for new files
        downloadQueue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let s = self?.fileService else {
                return
            }
            
            //If the service isn't started, start it
            if (self?.pollForNewFiles ?? false) {
                try? s.start(provideRawData: true, completionHandler: { (success, error) in
                    print("file service start")
                    print("success -> \(success)")
                    print("error -> \(String(describing: error))")
                })
            }
        }
    }
    
    func receiveFile(fileData: InkDocument, remainingFilesCount: Int) -> FileDataReceiverStatus {
        //Add the document to our list and update the collection view
        downloadedDocuments.append(fileData)
        DispatchQueue.main.async {
            self.showFinishedPrompt = true
            print("New file received from device")
            self.collectionView.reloadData()
        }
        
        //We return file saved. This causes the file to be deleted from the device
        return .fileSaved
    }
    
    func errorWhileDownloadingFile(_ error: Error) {
        print("Error during download:\(error.localizedDescription)")
    }
}

//========================================================================================================
// MARK: UICollection view delegates / datasource
//========================================================================================================


extension FileTransferViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return downloadedDocuments.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "previewCell", for: indexPath)
        
        if let sublayers = cell.layer.sublayers {
            for l in sublayers {
                if l is CAShapeLayer {
                    l.removeFromSuperlayer()
                }
            }
        }
        
        let document = downloadedDocuments[indexPath.row]
        
        //Get a bezier curve for the document. As we set a scale when the document was downloaded, we can just use the
        //property from the InkDocument directly
        var documentIterator = document.getRoot().makeIterator()
        
        while documentIterator.hasNext() {
            guard let node = documentIterator.next() else {
                print("Error getting next node on document iterator!")
                break
            }
            
            if node is InkStroke, let bezPath = (node as! InkStroke).bezierPath {
                let shapeLayer = CAShapeLayer()
          
                shapeLayer.path = bezPath.cgPath
                shapeLayer.position = CGPoint.zero
                shapeLayer.fillColor = UIColor.black.cgColor
                shapeLayer.strokeColor = UIColor.clear.cgColor
                cell.layer.addSublayer(shapeLayer)
            }
        }
 
        return cell
    }
}
