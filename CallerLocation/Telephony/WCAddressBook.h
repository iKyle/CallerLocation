//
//  WCAddressBook.h
//  WhoCall
//
//  Created by Wang Xiaolei on 10/1/13.
//  Copyright (c) 2013 Wang Xiaolei. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WCAddressBook : NSObject

+ (instancetype)defaultAddressBook;

- (BOOL)isContactPhoneNumber:(NSString *)number;
- (NSString *)contactNameForPhoneNumber:(NSString *)number;

//添加一个以Number作为名字的联系人
- (NSInteger)recordIDByAddNumberNameContactWithPhoneNumber:(NSString*)phoneNumber andCustomPhoneLabel:(NSString*)customPhoneLabel;

//删除对应联系人
- (void)removeContactWithRecordID:(NSInteger)recordID;

//删除数字联系人组和其中所有的联系人
- (void)removeNumberContactsGroupAndAllNumberContacts;

//更新已存储联系人某号码的标签
- (void)updateCustomPhoneLabel:(NSString*)customPhoneLabel forPhoneNumber:(NSString*)phoneNumber;


//一键标记归属地
- (void)signLocationLabelForAllContacts;

+ (BOOL)isCanAccessAddressBook;

@end
