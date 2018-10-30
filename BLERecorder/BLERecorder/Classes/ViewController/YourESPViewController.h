//
//  YourESPViewController.h
//  ECOSmartPen
//
//  Created by apple on 8/7/17.
//  Copyright © 2017 mac. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "Const.h"
#import "../Utility/MBProgressHUD.h"
@interface YourESPViewController : UIViewController<MBProgressHUDDelegate>
{
    UIView              *maskView;
    UILabel             *mProgressLabel;
    MBProgressHUD       *HUD;
    
    NSInteger           selectIndex;
}

@property (weak, nonatomic) IBOutlet UIImageView *imgBattery;
@property (retain, nonatomic) IBOutlet UITableView *tblView;
@property (strong, nonatomic) IBOutlet UIView *tblDevices;
@property (strong, nonatomic) IBOutlet UIView *vwWorkStation;
@property (strong, nonatomic) IBOutlet UIView *vwResultStation;
@property (strong, nonatomic) IBOutlet UILabel *lblMyDevice;
@property (strong, nonatomic) IBOutlet UIView *mMenuView;
@property (strong, nonatomic) IBOutlet UIView *mChildSafetyView;
@property (strong, nonatomic) IBOutlet UIButton *searchBtn;

@property (strong, nonatomic) IBOutlet UIButton *childSafetyButton;
@property (weak, nonatomic) IBOutlet UILabel *lblBatteryLevel;

@property (weak, nonatomic) IBOutlet UILabel *lblChildOn;
@property (weak, nonatomic) IBOutlet UILabel *lblChildOff;



@end
