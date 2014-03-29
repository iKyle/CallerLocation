//
//  AppDelegate.m
//  CallerLocation
//
//  Created by molon on 14-2-25.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "AppDelegate.h"
#import "MMPDeepSleepPreventer.h"
#import "WCCallInspector.h"
#import "WCPhoneLocator.h"
#import "FMDB.h"

@interface AppDelegate()

@property (nonatomic, strong) MMPDeepSleepPreventer *sleepPreventer;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTaskID;

@end

@implementation AppDelegate


//可以将QC的txt归属地文档格式化为db的方法
- (void)analyzeTxtFile
{
    NSError *error;
    NSString *textFileContents = [NSString
                                  stringWithContentsOfFile:[[NSBundle mainBundle]
                                                            pathForResource:@"locations"
                                                            ofType:@"txt"]
                                  encoding:NSUnicodeStringEncoding error:&error];
    
    if (textFileContents == nil) {
        NSLog(@"Error reading text file. %@",[error localizedFailureReason]);
    }
    
    textFileContents = [NSString stringWithCString:[textFileContents UTF8String] encoding:NSUTF8StringEncoding];
    
    NSArray *lines = [textFileContents componentsSeparatedByString:@"\n"];
    NSLog(@"Number of lines in the file:%ld", lines.count);
    
    //打开数据库
    NSString *dbPath = [@"~/Documents/locations.db" stringByExpandingTildeInPath];
    
    //删除之前的
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    BOOL bRet = [fileMgr fileExistsAtPath:dbPath];
    if (bRet) {
        NSError *err;
        [fileMgr removeItemAtPath:dbPath error:&err];
    }
    NSLog(@"%@",dbPath);
    
    FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
    
    if (![db open]) { //没打开成功
        NSLog(@"DB异常");
        return;
    }
    [db setShouldCacheStatements:NO];
    
    // 创建特服号记录表
	if (![db tableExists:@"special_number"]) {
		[db executeUpdate:@"create table special_number ('number' int, 'location' text)"];
	}
    //创建固话记录表
    if (![db tableExists:@"telephone_number"]) {
		[db executeUpdate:@"create table tel_number ('area_code' int, 'location' text ,'service_provider' text)"];
	}
    //创建手机号前7位记录表
    if (![db tableExists:@"mobile_number"]) {
		[db executeUpdate:@"create table mobile_number ('prefix' int, 'location' text, 'service_provider' text)"];
	}
    
    //插入数据
    NSUInteger count = 0;
    for (NSString *aLine in lines) {
        count++;
        if (aLine.length<=0) {
            NSLog(@"发现空行,行数:%ld 内容:%@",count,aLine);
            break;
        }
        
        NSMutableArray *cells = [[aLine componentsSeparatedByString:@"\t"]mutableCopy];
        if (cells.count!=3) {
            NSLog(@"发现非3元素行,行数:%ld 内容:%@",count,aLine);
            break;
        }
        
        for (NSUInteger i=0; i<cells.count; i++) {
            cells[i] = [[[cells[i] stringByReplacingOccurrencesOfString:@" " withString:@""]stringByReplacingOccurrencesOfString:@"\r" withString:@""]stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        }
        NSString *service_provider = cells[2];
        
        NSString *location = cells[1];
        if (location.length%2==0) {
            NSString *left = [location substringToIndex:location.length/2];
            NSString *right = [location substringFromIndex:location.length/2];
            if ([left isEqualToString:right]) {
                //这里是数据里会有像 吉林吉林 北京北京 之类的数据 修改为吉林市和北京市
                location = [left stringByAppendingString:@"市"];
            }
        }
        
        if ([service_provider isEqualToString:@"特服号"]) {
            [db executeUpdate:@"insert into special_number values (?, ?)",[NSNumber numberWithInteger:[cells[0] integerValue]],location];
            continue;
        }
        if ([service_provider isEqualToString:@"固话"]||[service_provider isEqualToString:@"非正常号"]||[service_provider rangeOfString:@"铁通"].length > 0) {
            [db executeUpdate:@"insert into tel_number values (?, ?, ?)",[NSNumber numberWithInteger:[cells[0] integerValue]],location,service_provider];
            continue;
        }
        
        [db executeUpdate:@"insert into mobile_number values (?, ?, ?)",[NSNumber numberWithInteger:[cells[0] integerValue]],location,service_provider];
    }
    NSLog(@"处理完毕");
    
    [db close];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    // prevent sleep
    self.sleepPreventer = [[MMPDeepSleepPreventer alloc] init];
    
    // 必须正确处理background task，才能在后台发声
    self.bgTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.bgTaskID];
        self.bgTaskID = UIBackgroundTaskInvalid;
    }];
    
    [[WCCallInspector sharedInspector]startInspect]; //开始监听来电事件
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [self.sleepPreventer startPreventSleep];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    [self.sleepPreventer stopPreventSleep];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
