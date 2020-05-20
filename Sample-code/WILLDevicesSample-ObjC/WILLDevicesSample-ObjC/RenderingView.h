//
//  RenderingView.h
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import <UIKit/UIKit.h>
@import WILLInk;

@interface RenderingView : UIView

- (void)addStrokePart:(WCMFloatVector *)strokePath isEnd:(BOOL)isEnd;
- (void)addStrokeBezier:(UIBezierPath *)path;

@end
