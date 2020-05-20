//
//  RenderingView.m
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import "RenderingView.h"
@import WILLInk;

typedef void (^Drawcall)(void); //Typedef for drawing block

@interface RenderingView()

/// Display link used to lock render calls to display calls

@property (nonatomic, strong) CADisplayLink *displayLink;

/// Queue of current draw commands
@property (nonatomic, strong) NSMutableArray<Drawcall> *drawQueue;

- (void)clear;
- (void)refreshViewIn:(CGRect)rect;
- (void)updateView;

@end

/// Basic WILL view that renders the output from the CDL
@implementation RenderingView {
    WCMRenderingContext * willContext;
    WCMLayer* viewLayer;
    WCMStrokeRenderer* strokeRenderer;
}

//========================================================================================================
// MARK: UIView / Init methods
//========================================================================================================

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self commonInit];
    }
    return(self);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self commonInit];
    }
    return(self);
}

- (void)commonInit {
    self.contentScaleFactor = [[UIScreen mainScreen] scale];
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    EAGLContext* eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    willContext = [[WCMRenderingContext alloc] initWithEAGLContext:eaglContext];
    if (!eaglContext || ![EAGLContext setCurrentContext:eaglContext])
    {
        NSLog(@"Unable to create EAGLContext!");
        return;
    }
    
    willContext = [WCMRenderingContext contextWithEAGLContext:eaglContext];
    viewLayer = [willContext layerFromEAGLDrawable:(id<EAGLDrawable>)self.layer withScaleFactor:self.contentScaleFactor];
    
    [willContext setTarget:viewLayer];
    [willContext clearColor:[UIColor whiteColor]];
    
    
    strokeRenderer = [willContext  strokeRendererWithSize:viewLayer.bounds.size andScaleFactor:viewLayer.scaleFactor];
    strokeRenderer.brush = [willContext solidColorBrush];
    strokeRenderer.stride = 3;
    strokeRenderer.color = [UIColor blackColor];
    strokeRenderer.copyAllToPreliminaryLayer = YES;
    
}

//Setup the draw queue
- (void)didMoveToWindow {
    if(self.window != NULL) {
        self.displayLink = [self.window.screen displayLinkWithTarget:self selector:@selector(updateView)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        self.drawQueue = [NSMutableArray new];

    } else {
        [self.displayLink invalidate];
        self.displayLink = NULL;
        self.drawQueue = NULL;
        [self clear];
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
- (void)addStrokePart:(WCMFloatVector *)strokePath isEnd:(BOOL)isEnd {
    Drawcall c = ^{
        if(strokePath == NULL) {
            return;
        }
        [strokeRenderer drawPoints:[strokePath pointer] finishStroke:isEnd];
    };
    [self.drawQueue addObject:c];
}

/// Adds a new UIBezier curve to the view. We call this at the end of a CDL stroke to improve
/// rendering performance with many strokes. This will also clear the WILL strokes of the view.
///
/// - Parameter path: The path to add
- (void)addStrokeBezier:(UIBezierPath *)path {
    CAShapeLayer *shapeLayer = [CAShapeLayer new];
    shapeLayer.path = path.CGPath;
    shapeLayer.position = CGPointZero;
    shapeLayer.fillColor = [UIColor blackColor].CGColor;
    shapeLayer.strokeColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:shapeLayer];
    Drawcall c = ^{
        [strokeRenderer resetAndClearBuffers];
    };
    [self.drawQueue addObject:c];
}

//========================================================================================================
// MARK: Internal methods
//========================================================================================================

/// Clears the view
- (void)clear {
    [strokeRenderer resetAndClearBuffers];
    [self.drawQueue removeAllObjects];
    [self refreshViewIn:self.bounds];
}

/// Updates the specified rect of the drawing vierw
///
/// - Parameter rect: The area of the drawing view to update
- (void)refreshViewIn:(CGRect)rect {
    //Don't draw in background modes
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        return;
    }
    
    [willContext setTarget:viewLayer andClipRect:rect];
    [willContext clearColor:[UIColor whiteColor]];
    strokeRenderer.updatedArea = rect;
    [strokeRenderer blendStrokeInLayer:viewLayer withBlendMode:WCMBlendModeNormal];
    [viewLayer present];
}

/// This is called by the displayLink. It will referst the view only after all operations in the drawQueue
/// have been executed
- (void)updateView {
    if(self.drawQueue != NULL) {
        for (Drawcall call in self.drawQueue) {
            if([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                return;
            } else {
                call();
            }
        }
        [self refreshViewIn:viewLayer.bounds];
        [self.drawQueue removeAllObjects];
    }
}

@end
