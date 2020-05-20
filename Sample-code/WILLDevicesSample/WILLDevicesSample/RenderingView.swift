//
//  RenderingView.swift
//  WILLDevicesSample
//
//  Created by Joss Giffard-Burley on 31/07/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

import Foundation
import WILLInk

/// Basic WILL view that renders the output from the CDL
public class RenderingView: UIView {
    //========================================================================================================
    // MARK: Properties
    //========================================================================================================
    
    /// Display link used to lock render calls to display calls
    private var displayLink: CADisplayLink?
    
    /// Queue of current draw commands
    private var drawQueue: Array<()->()>?
    
    /// WILL Rendering context for the view
    private var willContext: WCMRenderingContext!
    
    /// WILL Drawing layer
    private var viewLayer: WCMLayer!
    
    /// WILL Stroke renderer
    private var strokeRenderer: WCMStrokeRenderer!
    
    //========================================================================================================
    // MARK: UIView / Init methods
    //========================================================================================================
    
    /// Identify as a GL view
    override public class var layerClass: AnyClass {
        get {
            return CAEAGLLayer.self
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    /// Common init functions. Sets up the WILL rendering context
    private func commonInit() {
        contentScaleFactor = UIScreen.main.scale
        let eaglLayer = layer as! CAEAGLLayer
        eaglLayer.isOpaque = true
        
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking: NSNumber(value:true),
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
        ]
        
        guard let eaglContext = EAGLContext(api: .openGLES2), EAGLContext.setCurrent(eaglContext) else {
            fatalError("Unable to create EAGLContext!")
        }
       
        willContext = WCMRenderingContext(eaglContext: eaglContext)
        viewLayer = willContext.layer(from: layer as! EAGLDrawable, withScaleFactor: Float(contentScaleFactor))
        
        strokeRenderer = willContext.strokeRenderer(with: viewLayer.bounds.size, andScaleFactor: CGFloat(viewLayer.scaleFactor))
        strokeRenderer.brush = willContext.solidColorBrush()
        strokeRenderer.stride = 3
        strokeRenderer.color = UIColor.black
        strokeRenderer.copyAllToPreliminaryLayer = true
    }
    
    // Setup the displayLink and drawQueue
    override public func didMoveToWindow() {
        if let window = window {
            displayLink = window.screen.displayLink(withTarget: self, selector: #selector(updateView))
            displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
            drawQueue = []
        } else {
            displayLink?.invalidate()
            displayLink = nil
            drawQueue = nil
            clear()
        }
    }
    

    //========================================================================================================
    // MARK: Public interface
    //========================================================================================================
    
    /// Called when a new stroke is received from the CDL. This creates or appends data to a WILL stroke. This
    /// adds the draw operation to the draw queue.
    ///
    /// - Parameters:
    ///   - strokePart: The stroke part to add
    ///   - isEnd: If this is true, then this is the last part of the stroke to add to the view
    public func addStrokePart(_ strokePart: WCMFloatVector?, isEnd:Bool) {
        drawQueue?.append { [weak self] in
            guard let points = strokePart else {
                return
            }
            self?.strokeRenderer.drawPoints(points.pointer(), finishStroke: isEnd)
        }
    }
    
    
    /// Adds a new UIBezier curve to the view. We call this at the end of a CDL stroke to improve
    /// rendering performance with many strokes. This will also clear the WILL strokes of the view.
    ///
    /// - Parameter path: The path to add
    public func addStrokeBezier(_ path: UIBezierPath) {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.position = CGPoint.zero
        shapeLayer.fillColor = UIColor.black.cgColor
        shapeLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(shapeLayer)
        drawQueue?.append { [weak self] in
            self?.strokeRenderer.resetAndClearBuffers()
        }
    }

    //========================================================================================================
    // MARK: Internal methods
    //========================================================================================================

    /// Clears the view
    private func clear() {
        strokeRenderer.resetAndClearBuffers()
        drawQueue?.removeAll()
        refreshView(in: bounds)
    }
    
    /// Updates the specified rect of the drawing vierw
    ///
    /// - Parameter rect: The area of the drawing view to update
    private func refreshView(in rect: CGRect) {
        
        // Don't draw while in background - it will crash
        guard UIApplication.shared.applicationState != .background else {
            return
        }
        
        willContext.setTarget(viewLayer, andClipRect: viewLayer.bounds)
        willContext.clear(UIColor.white)
        
        strokeRenderer.updatedArea = rect
        strokeRenderer.blendStrokeUpdatedArea(in: viewLayer, with: .normal)
        
        viewLayer.present()
    }
    
    /// This is called by the displayLink. It will referst the view only after all operations in the drawQueue
    /// have been executed
    @objc private func updateView() {
        if let drawQueue = self.drawQueue, drawQueue.count > 0 {
            for drawBlock in drawQueue {
                if UIApplication.shared.applicationState != .background {
                    drawBlock()
                } else {
                    return
                }
            }
            self.refreshView(in: viewLayer.bounds)
            self.drawQueue?.removeAll()
        }
    }
}
