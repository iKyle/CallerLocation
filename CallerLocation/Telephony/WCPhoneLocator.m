//
//  WCPhoneLocator.m
//  WhoCall
//
//  Created by Wang Xiaolei on 11/20/13.
//  Copyright (c) 2013 Wang Xiaolei. All rights reserved.
//

#import "WCPhoneLocator.h"
#import "WCUtil.h"
#import "FMDB.h"

@interface WCPhoneLocator ()

@property (nonatomic, strong) FMDatabase *db;

@end

@implementation WCPhoneLocator

+ (instancetype)sharedLocator
{
    static WCPhoneLocator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WCPhoneLocator alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        NSString *dbFile = [[NSBundle mainBundle] pathForResource:@"locations" ofType:@"db"];
        self.db = [FMDatabase databaseWithPath:dbFile];
        
        if (![self.db open]) {
            self.db = nil;
        } else {
            [self.db close];
        }
    }
    
    return self;
}

- (NSString *)locationForPhoneNumber:(NSString *)phoneNumber
{
    phoneNumber = [phoneNumber normalizedPhoneNumber];
    if (phoneNumber.length == 0) {
        return nil;
    }
    
    NSString *location = nil;
    
    @synchronized (self.db) {
        [self.db open];
        
        if ([phoneNumber hasPrefix:@"+86"]) {
            phoneNumber = [phoneNumber substringFromIndex:3];
        }
        
        //检测是否是特服号
        FMResultSet *s = [self.db executeQuery:@"SELECT location FROM special_number where [number]=?", @([phoneNumber integerValue])];
        if ([s next]) {
            location = [s stringForColumn:@"location"];
            [s close];
        }else{
            //检测是否是移动电话
            if ([phoneNumber characterAtIndex:0] == '1' && phoneNumber.length == 11) {
                NSString *prefix = [phoneNumber substringToIndex:7];
                FMResultSet *s = [self.db executeQuery:@"SELECT * FROM mobile_number where [prefix]=?", @([prefix integerValue])];
                if ([s next]) {
                    location = [NSString stringWithFormat:@"%@ %@",[s stringForColumn:@"location"],[s stringForColumn:@"service_provider"]];
                    [s close];
                }
            }
            if (!location) {
                if ([phoneNumber characterAtIndex:0] == '0') {
                    //首字母为0代表很可能是区号
                    NSString *phoneNumberWithNoFirst0 = [phoneNumber substringFromIndex:1];
                    //挨个从6个字符作为前缀到2个字符作为前缀来找到是否有对应的
                    for (NSUInteger curPrefixLength=6; curPrefixLength>=2; curPrefixLength--) {
                        NSString *areacode = [phoneNumberWithNoFirst0 substringToIndex:curPrefixLength];
                        FMResultSet *s = [self.db executeQuery:@"SELECT * FROM tel_number where [area_code]=?", @([areacode integerValue])];
                        if ([s next]) {
                            location = [NSString stringWithFormat:@"%@ %@",[s stringForColumn:@"location"],[s stringForColumn:@"service_provider"]];
                            [s close];
                        }
                        if (location) {
                            break; //找到了就跳出
                        }
                    }
                }
            }
            if (!location) {
                location = @"未知地";
            }
        }
        [self.db close];
    }
    
    return location;
}

@end
