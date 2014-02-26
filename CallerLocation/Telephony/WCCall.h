//
//  WCCall.h
//  WhoCall
//
//  Created by Wang Xiaolei on 11/18/13.
//  Copyright (c) 2013 Wang Xiaolei. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreTelephony;

// private API
typedef NS_ENUM(short, CTCallStatus) {
    kCTCallStatusConnected = 1, //已接通
    kCTCallStatusCallOut = 3, //拨出去
    kCTCallStatusCallIn = 4, //打进来
    kCTCallStatusHungUp = 5 //挂断
};

@interface WCCall : NSObject

@property (nonatomic, assign) CTCallStatus callStatus;
@property (nonatomic, copy) NSString *phoneNumber;

@property (nonatomic, strong) CTCall *internalCall; //真实的系统CTCall

@end
