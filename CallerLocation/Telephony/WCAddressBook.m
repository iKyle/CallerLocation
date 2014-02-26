//
//  WCAddressBook.m
//  WhoCall
//
//  Created by Wang Xiaolei on 10/1/13.
//  Copyright (c) 2013 Wang Xiaolei. All rights reserved.
//

#import "WCAddressBook.h"
#import "WCUtil.h"
#import "WCPhoneLocator.h"

NSString * const kGroupNameOfNumberContacts = @"丁丁来电_数字联系人";

@import AddressBook;

@interface WCAddressBook ()

@property (strong, nonatomic) NSMutableDictionary *allPhoneNumbers;

- (void)reload:(ABAddressBookRef)addressBook;

@end

@implementation WCAddressBook

+ (instancetype)defaultAddressBook
{
    static WCAddressBook *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WCAddressBook alloc] init];
        
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
        [instance reload:addressBook];
        
        ABAddressBookRegisterExternalChangeCallback(addressBook,
                                                    addressBookChangeHandler,
                                                    (__bridge void *)(instance));
        
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            if (granted) {
                [instance reload:addressBook];
            }
        });
        
    });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.allPhoneNumbers = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (BOOL)isCanAccessAddressBook
{
    return (ABAddressBookGetAuthorizationStatus()==kABAuthorizationStatusAuthorized);
}

- (ABRecordID)numberContactsGroupRecordID
{
    //检测是否有 丁丁来电_数字联系人 分组，没有则创建
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
    NSArray *array = (__bridge_transfer NSArray *)(ABAddressBookCopyArrayOfAllGroups(addressBook));
    if (array) {
        for (id group in array) {
            ABRecordRef groupRecord = (__bridge ABRecordRef)group;
            NSString *groupName = (__bridge_transfer NSString *)(ABRecordCopyValue(groupRecord, kABGroupNameProperty));
            if ([groupName isEqualToString:kGroupNameOfNumberContacts]) {
                CFRelease(addressBook);
                ABRecordID groupRecordID = ABRecordGetRecordID(groupRecord);
                return groupRecordID;
            }
        }
    }
    
    //新建一个记录
    ABRecordRef  newGroup = ABGroupCreate();
    ABRecordSetValue(newGroup, kABGroupNameProperty, (__bridge CFTypeRef)(kGroupNameOfNumberContacts), nil);
    ABAddressBookAddRecord(addressBook, newGroup, nil);
    ABAddressBookSave(addressBook, nil);
    
    ABRecordID groupRecordID = ABRecordGetRecordID(newGroup);
    
    CFRelease(newGroup);
    CFRelease(addressBook);
    
    return groupRecordID;
    
}

- (void)reload:(ABAddressBookRef)addressBook
{
    @synchronized (self) {
        [self.allPhoneNumbers removeAllObjects];
        
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
        if (allPeople) {
            CFIndex numberOfPeople = CFArrayGetCount(allPeople);
            for (CFIndex idxPeople = 0; idxPeople < numberOfPeople; idxPeople++) {
                ABRecordRef person = CFArrayGetValueAtIndex(allPeople, idxPeople);
                
                NSString *personName = (__bridge_transfer NSString *)(ABRecordCopyCompositeName(person));
                if (!personName) {
                    continue;
                }
                
                ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
                if (phoneNumbers) {
                    for (CFIndex idxNumber = 0; idxNumber < ABMultiValueGetCount(phoneNumbers); idxNumber++) {
                        NSString *phoneNumber = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phoneNumbers, idxNumber);
                        phoneNumber = [phoneNumber normalizedPhoneNumber];
                        if (!phoneNumber) {
                            continue;
                        }
                        
                        self.allPhoneNumbers[phoneNumber] = personName;
                    }
                    
                    CFRelease(phoneNumbers);
                }
            }
            
            CFRelease(allPeople);
        }
    }
}

- (BOOL)isContactPhoneNumber:(NSString *)number
{
    return ([self contactNameForPhoneNumber:number] != nil);
}

- (NSString *)contactNameForPhoneNumber:(NSString *)number {
    number = [number normalizedPhoneNumber];
    @synchronized (self) {
        return self.allPhoneNumbers[number];
    }
}

static void addressBookChangeHandler(ABAddressBookRef addressBook,
                                     CFDictionaryRef info,
                                     void *context)
{
    if (context) {
        [(__bridge WCAddressBook *)context reload:addressBook];
    }
}

//添加数字联系人，返回起recordID
- (NSInteger)recordIDByAddNumberNameContactWithPhoneNumber:(NSString*)phoneNumber andCustomPhoneLabel:(NSString*)customPhoneLabel
{
    
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
    ABRecordRef newPerson = ABPersonCreate();
    CFErrorRef error = NULL;
    
    ABRecordSetValue(newPerson, kABPersonFirstNameProperty, (__bridge CFTypeRef)(phoneNumber), &error);
    //phone number
    ABMutableMultiValueRef multiPhone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(phoneNumber),  (__bridge CFStringRef)customPhoneLabel, NULL);
    ABRecordSetValue(newPerson, kABPersonPhoneProperty, multiPhone, &error);
    CFRelease(multiPhone);
    
    ABAddressBookAddRecord(addressBook, newPerson, &error);
    ABAddressBookSave(addressBook, &error);
    
    //添加到数字联系人组
    ABRecordID groupRecordID = [self numberContactsGroupRecordID];
    ABRecordRef groupRecord = ABAddressBookGetGroupWithRecordID(addressBook,groupRecordID);
    if (!ABGroupAddMember(groupRecord, newPerson, &error)) {
        //此方法必须保证俩record当前所处是同一个addressBook对象，并且person是确切已经存储在通讯录内，所以上面先添加联系人了再添加的
        NSLog(@"添加联系人到组失败，error:%@",error);
    }
    ABAddressBookSave(addressBook, &error);
    
    NSInteger recordID = ABRecordGetRecordID(newPerson);
    
    CFRelease(newPerson);
    CFRelease(addressBook);
    
    if (error) {
        return -1;
    }
    return recordID;
}

//删除对应联系人
- (void)removeContactWithRecordID:(NSInteger)recordID
{
    if (recordID==-1) {
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
    ABRecordRef oldPeople = ABAddressBookGetPersonWithRecordID(addressBook, (ABRecordID)recordID);
    if (!oldPeople) {
        CFRelease(addressBook);
        return;
    }
    ABAddressBookRemoveRecord(addressBook, oldPeople, &error);
    ABAddressBookSave(addressBook, &error);
    CFRelease(addressBook);
    
}

//删除数字联系人组和其中所有的联系人
- (void)removeNumberContactsGroupAndAllNumberContacts
{
    
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
    ABRecordID groupRecordID = [self numberContactsGroupRecordID];
    ABRecordRef groupRecord = ABAddressBookGetGroupWithRecordID(addressBook,groupRecordID);
    if (!groupRecord) {
        CFRelease(addressBook);
        return;
    }
    
    //遍历group找到其内部所有联系人标记删除
    CFArrayRef allPeople = ABGroupCopyArrayOfAllMembers(groupRecord);
    if (allPeople) {
        CFIndex numberOfPeople = CFArrayGetCount(allPeople);
        for (CFIndex idxPeople = 0; idxPeople < numberOfPeople; idxPeople++) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, idxPeople);
            ABAddressBookRemoveRecord(addressBook, person, &error);
        }
        CFRelease(allPeople);
    }
    
    
    //删除组
    ABAddressBookRemoveRecord(addressBook, groupRecord, &error);
    ABAddressBookSave(addressBook, &error);
    
    CFRelease(addressBook);
}


//更新已存储联系人某号码的标签
- (void)updateCustomPhoneLabel:(NSString*)customPhoneLabel forPhoneNumber:(NSString*)phoneNumber
{
    if (![self isContactPhoneNumber:phoneNumber]) {
        return;
    }
    
    //找到所有包含此号码的record
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
    if (allPeople) {
        BOOL isHasModified = NO;
        
        for (CFIndex idxPeople = 0; idxPeople < CFArrayGetCount(allPeople); idxPeople++) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, idxPeople);
            
            NSString *personName = (__bridge_transfer NSString *)(ABRecordCopyCompositeName(person));
            if (!personName) {
                continue;
            }
            
            ABMultiValueRef tempNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
            if (tempNumbers) {
                ABMutableMultiValueRef numbers = ABMultiValueCreateMutableCopy(tempNumbers);
                if (numbers) {
                    BOOL isModified = NO;
                    for (CFIndex idxNumber = 0; idxNumber < ABMultiValueGetCount(numbers); idxNumber++) {
                        NSString *number = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(numbers, idxNumber);
                        number = [number normalizedPhoneNumber];
                        if (!number) {
                            continue;
                        }
                        if ([number isEqualToString:phoneNumber]) {
                            //查看其标签
                            NSString *label = (__bridge_transfer NSString *)ABMultiValueCopyLabelAtIndex(numbers, idxNumber);
                            if (![label isEqualToString:customPhoneLabel]) {
                                //改变此phoneNumber的标签
                                NSLog(@"号码:%@的标签需要修改从%@修改为%@",phoneNumber,label,customPhoneLabel);
                                ABMultiValueReplaceLabelAtIndex(numbers,(__bridge CFStringRef)(customPhoneLabel),idxNumber);
                                isModified = YES;
                            }
                        }
                    }
                    
                    if (isModified) {
                        ABRecordSetValue(person, kABPersonPhoneProperty, numbers, nil);
                        isHasModified = YES;
                    }
                    
                    CFRelease(numbers);
                }
                CFRelease(tempNumbers);
            }
        }
        CFRelease(allPeople);
        
        if (isHasModified) {
            ABAddressBookSave(addressBook, nil);
        }
    }
    
    CFRelease(addressBook);
    
}


//一键标记归属地
- (void)signLocationLabelForAllContacts
{
    //找到所有包含此号码的record
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, NULL);
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
    if (allPeople) {
        BOOL isHasModified = NO;
        
        for (CFIndex idxPeople = 0; idxPeople < CFArrayGetCount(allPeople); idxPeople++) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, idxPeople);
            
            NSString *personName = (__bridge_transfer NSString *)(ABRecordCopyCompositeName(person));
            if (!personName) {
                continue;
            }
            
            ABMultiValueRef tempNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
            if (tempNumbers) {
                ABMutableMultiValueRef numbers = ABMultiValueCreateMutableCopy(tempNumbers);
                if (numbers) {
                    BOOL isModified = NO;
                    for (CFIndex idxNumber = 0; idxNumber < ABMultiValueGetCount(numbers); idxNumber++) {
                        NSString *number = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(numbers, idxNumber);
                        number = [number normalizedPhoneNumber];
                        if (!number) {
                            continue;
                        }
                        
                        //查看其标签
                        NSString *label = (__bridge_transfer NSString *)ABMultiValueCopyLabelAtIndex(numbers, idxNumber);
                        NSString *locationLabel = [[WCPhoneLocator sharedLocator] locationForPhoneNumber:number];
                        if (![label isEqualToString:locationLabel]) {
                            //改变此phoneNumber的标签
                            ABMultiValueReplaceLabelAtIndex(numbers,(__bridge CFStringRef)(locationLabel),idxNumber);
                            isModified = YES;
                        }
                    }
                    
                    if (isModified) {
                        ABRecordSetValue(person, kABPersonPhoneProperty, numbers, nil);
                        isHasModified = YES;
                    }
                    
                    CFRelease(numbers);
                }
                CFRelease(tempNumbers);
            }
        }
        CFRelease(allPeople);
        
        if (isHasModified) {
            ABAddressBookSave(addressBook, nil);
        }
    }
    
    CFRelease(addressBook);
    
}

@end
