//
//  WCCallInspector.h
//  WhoCall
//
//  Created by Wang Xiaolei on 11/18/13.
//  Copyright (c) 2013 Wang Xiaolei. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WCCallInspector : NSObject

@property (nonatomic,assign) BOOL handleAutoRemoveNumberContact;

+ (instancetype)sharedInspector;

// 开始、停止检测来电
- (void)startInspect;
- (void)stopInspect;

- (void)saveSettings;
@end
