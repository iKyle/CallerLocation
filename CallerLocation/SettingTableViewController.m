//
//  SettingTableViewController.m
//  CallerLocation
//
//  Created by molon on 14-2-25.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "SettingTableViewController.h"
#import "WCAddressBook.h"
#import "WCCallInspector.h"
#import "MBProgressHUD.h"

@import AddressBook;

@interface SettingTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *swicthAutoRemoveNumberContact;

@end

@implementation SettingTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    WCCallInspector *inspector = [WCCallInspector sharedInspector];
    self.swicthAutoRemoveNumberContact.on = inspector.handleAutoRemoveNumberContact;
}

- (void)viewDidAppear:(BOOL)animated {
    [self isAuthorizationStatusWithRequestAccessCompletionBlock:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

typedef void(^ABAddressBookAuthorizedCompletionBlock)();

- (BOOL)isAuthorizationStatusWithRequestAccessCompletionBlock:(ABAddressBookAuthorizedCompletionBlock)block
{
    // 根据通讯录的访问权限，有不同的处理
    switch (ABAddressBookGetAuthorizationStatus()) {
        case kABAuthorizationStatusNotDetermined:
        {
            ABAddressBookRef addrBook = ABAddressBookCreateWithOptions(nil, NULL);
            ABAddressBookRequestAccessWithCompletion(addrBook, ^(bool granted, CFErrorRef error){
                if (granted) {
                    if (block) {
                        block();
                    }
                }
                CFRelease(addrBook);
            });
            return NO;
            break;
        }
        case kABAuthorizationStatusDenied:
        {
            [[[UIAlertView alloc]initWithTitle:nil message:@"无法使用联系人信息，请先到\n[设置]-[隐私]-[联系人]\n允许该App使用联系人信息。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil]show];
            return NO;
            break;
        }
        default:
            break;
    }
    return YES;
}

- (IBAction)onSwitchValueChanged:(UISwitch *)sender {
    if (![self isAuthorizationStatusWithRequestAccessCompletionBlock:^{
        [self onSwitchValueChanged:sender];
    }]){
        sender.on = NO;
        return;
    }
    
    WCCallInspector *inspector = [WCCallInspector sharedInspector];
    if (sender == self.swicthAutoRemoveNumberContact) {
        inspector.handleAutoRemoveNumberContact = sender.on;
    }
    
    [inspector saveSettings];
}


- (IBAction)cleanAllNumberContacts:(id)sender {
    if (![self isAuthorizationStatusWithRequestAccessCompletionBlock:^{
        [self cleanAllNumberContacts:sender];
    }]) {
        return;
    }
    
    //一键标记所有归属地
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.view.window];
	[self.view.window addSubview:hud];
	hud.labelText = @"清理中...";
	
	[hud showAnimated:YES whileExecutingBlock:^{
		[[WCAddressBook defaultAddressBook] removeNumberContactsGroupAndAllNumberContacts];
	} completionBlock:^{
		[hud removeFromSuperview];
        [[[UIAlertView alloc]initWithTitle:nil message:@"清理数字联系人完毕！" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil]show];
	}];
}


- (IBAction)oneKeySignLocationLabel:(id)sender {
    if (![self isAuthorizationStatusWithRequestAccessCompletionBlock:^{
        [self oneKeySignLocationLabel:sender];
    }]) {
        return;
    }
    
    //一键标记所有归属地
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.view.window];
	[self.view.window addSubview:hud];
	hud.labelText = @"标记中...";
	
	[hud showAnimated:YES whileExecutingBlock:^{
		[[WCAddressBook defaultAddressBook] signLocationLabelForAllContacts];
	} completionBlock:^{
		[hud removeFromSuperview];
        [[[UIAlertView alloc]initWithTitle:nil message:@"标记号码归属地完毕！" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil]show];
	}];
}

@end
