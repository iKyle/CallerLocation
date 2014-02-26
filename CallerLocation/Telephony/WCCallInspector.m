//
//  WCCallInspector.m
//  WhoCall
//
//  Created by Wang Xiaolei on 11/18/13.
//  Copyright (c) 2013 Wang Xiaolei. All rights reserved.
//

@import AudioToolbox;
#import "WCCallInspector.h"
#import "WCCallCenter.h"
#import "WCAddressBook.h"
#import "WCPhoneLocator.h"

#define kSettingKeyAutoRemoveNumberContact @"com.molon.SettingKeyAutoRemoveNumberContact"

@interface WCCallInspector ()

@property (nonatomic, strong) WCCallCenter *callCenter;
@property (nonatomic, copy) NSString *incomingPhoneNumber;

@end


@implementation WCCallInspector

+ (instancetype)sharedInspector
{
    static WCCallInspector *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WCCallInspector alloc] init];
    });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

#pragma mark - Call Inspection

- (void)startInspect
{
    if (self.callCenter) {
        return;
    }
    
    self.callCenter = [[WCCallCenter alloc] init];
    
    __weak WCCallInspector *weakSelf = self;
    self.callCenter.callEventHandler = ^(WCCall *call) { [weakSelf handleCallEvent:call]; };
}

- (void)stopInspect
{
    self.callCenter = nil;
}


//来电事件
- (void)handleCallEvent:(WCCall *)call
{
    if (![WCAddressBook isCanAccessAddressBook]) {
        return;
    }
    
    // 接通后震动一下
    if (call.callStatus == kCTCallStatusConnected) {
        [self vibrateDevice];
    }

    // 不是打进电话和接通以及拨出电话时候
    if (call.callStatus != kCTCallStatusCallIn&&call.callStatus!=kCTCallStatusConnected&&call.callStatus!=kCTCallStatusCallOut) {
        //这个会影响处理删除添加的数字联系人记录
        self.incomingPhoneNumber = nil;
        return;
    }
    
    NSString *number = call.phoneNumber;
    self.incomingPhoneNumber = number;
    
    BOOL isContact = [[WCAddressBook defaultAddressBook] isContactPhoneNumber:number];
    
    //如果不是已经添加的联系人，那就添加一份。
    if (!isContact) {
        NSInteger tempContactRecordID = [[WCAddressBook defaultAddressBook] recordIDByAddNumberNameContactWithPhoneNumber:number andCustomPhoneLabel:[[WCPhoneLocator sharedLocator] locationForPhoneNumber:number]];
        [self notifyMessage:@"" forPhoneNumber:number andTempRecordID:tempContactRecordID];
    }else{
        [[WCAddressBook defaultAddressBook]updateCustomPhoneLabel:[[WCPhoneLocator sharedLocator] locationForPhoneNumber:number] forPhoneNumber:number];
        //这里不需要有结束操作
    }
}


#pragma mark - Notify Users

- (void)notifyMessage:(NSString *)text forPhoneNumber:(NSString *)phoneNumber andTempRecordID:(NSInteger)tempContactRecordID
{
    // delay一下,1秒检查一次
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if ([self.incomingPhoneNumber isEqualToString:phoneNumber]) {
            // 下一轮提醒
            [self notifyMessage:text forPhoneNumber:phoneNumber andTempRecordID:tempContactRecordID];
        }else{
            //结束操作
            //删除临时联系人
            if (self.handleAutoRemoveNumberContact) {
                [[WCAddressBook defaultAddressBook]removeContactWithRecordID:tempContactRecordID];
            }
        }
    });
}


#pragma mark - other
- (void)sendLocalNotification:(NSString *)message
{
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)vibrateDevice
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}


#pragma mark - Settings

- (void)loadSettings
{
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def registerDefaults:@{
                            kSettingKeyAutoRemoveNumberContact        : @(YES),
                            }];
    
    self.handleAutoRemoveNumberContact = [def boolForKey:kSettingKeyAutoRemoveNumberContact];
}

- (void)saveSettings
{
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:self.handleAutoRemoveNumberContact forKey:kSettingKeyAutoRemoveNumberContact];
    
    [def synchronize];
}

@end
