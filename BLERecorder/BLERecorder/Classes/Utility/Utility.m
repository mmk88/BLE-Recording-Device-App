//
//  Utility.m
//  SmartHub
//
//  Created by apple on 15/5/27.
//  Copyright (c) 2015年 Panda. All rights reserved.
//

#import "Utility.h"

@implementation Utility

+ (NSString*)NSLocalizedString:(NSString*)key {
    return [[NSBundle mainBundle] localizedStringForKey:key value:key table:@"LocalizationNote"];
}

@end
