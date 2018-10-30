//
//  Const.h
//  SmartHub
//
//  Created by Anaconda on 11/26/14.
//  Copyright (c) 2014 Panda. All rights reserved.
//
#ifndef CONST_H
#define CONST_H

#import "bluetooth.h"


extern  BlueTooth            *mBLEComm;

#define DEBUGLOG_BLE                0

#define PHONE_WIDTH                 320

#define KEY_USERNAME            @"UserName"
#define KEY_EMAIL               @"Email"
#define KEY_NAME                @"Name"
#define KEY_PASSWORD            @"Password"
#define KEY_GENDER              @"Gender"
#define KEY_BIRTH               @"Birth"
#define KEY_HEIGHT              @"Height"
#define KEY_WEIGHT              @"Weight"

extern int                     gSelectDoorIdx;
extern BOOL                    gShowAudioHistory;
extern BOOL                    isHistoryDeleteState;

extern int                     ScreenWidth;
extern int                     ScreenHeight;


extern int                     selectScreenIndex;
extern int                     childSafetyValue;
extern NSString*                myDB;

extern NSString                *sendCatName;
extern NSString                *sendImageName;
extern NSString                *defaultCatridgeName;
extern NSString                *defaultImageName;
extern NSString                *defaultUserImageName;
extern Boolean                 isRefresh;

extern NSString                *learnSiteURL;
extern NSString                *fillOutURL;

extern int                     sendMode;
extern int                     batteryLevel;

#define SCREEN_NONE                 -1
#define SCREEN_YOURESP              0
#define SCREEN_DOSAGESCHEDULER      1
#define SCREEN_DOSAGETRACKER        2
#define SCREEN_SELECTCATRIDGE       3
#define SCREEN_PROFILE              4
#define SCREEN_GUESTUSER            5
#define SCREEN_LOGOUT               6



#define CHILD_SAFETY_ON_NONE        0
#define CHILD_SAFETY_OFF_NONE       1
#define CHILD_SAFETY_ON             2
#define CHILD_SAFETY_OFF            3


#define SEND_CATRIDGE_ADDMODE       1
#define SEND_CATRIDGE_EDITMODE      2
#define SEND_CATRIDGE_DEFAULT       3
///////////////////

#define IS_iOS8             ([[[UIDevice currentDevice] systemVersion] floatValue] >=8.0)
#define IS_iOS7             (([[[UIDevice currentDevice] systemVersion] floatValue] >=7.0) && ([[[UIDevice currentDevice] systemVersion] floatValue] <8.0))
#define IS_iOS6             [[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0 && [[[UIDevice currentDevice] systemVersion] floatValue] <7.0
#define IS_iOS5             [[[UIDevice currentDevice] systemVersion] floatValue] < 6.0




#endif /*CONST_H*/
