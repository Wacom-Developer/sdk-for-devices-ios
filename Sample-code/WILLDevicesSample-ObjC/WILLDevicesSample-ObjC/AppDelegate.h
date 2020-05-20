//
//  AppDelegate.h
//  WILLDevicesSample-ObjC
//
//  Created by Joss Giffard-Burley on 08/12/2017.
//  Copyright © 2017 Wacom. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (void)postNotification:(NSString *)title withBody:(NSString *)bodyText;
+ (void)postNotification:(NSString *)title withBody:(NSString *)bodyText messageID:(NSString *)messageID; 

@end

