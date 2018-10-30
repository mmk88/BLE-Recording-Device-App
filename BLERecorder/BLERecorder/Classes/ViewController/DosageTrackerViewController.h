//
//  DosageTrackerViewController.h
//  ECOSmartPen
//
//  Created by apple on 8/7/17.
//  Copyright © 2017 mac. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
//#import "PopoverViewController.h"
//#import "UIPopoverController+iPhone.h"
#import <AVFoundation/AVAudioPlayer.h>

@interface DosageTrackerViewController : UIViewController<MBProgressHUDDelegate, UIPopoverControllerDelegate>
{
    UIView              *maskView;
    UILabel             *mProgressLabel;
    MBProgressHUD       *HUD;
    Boolean             continiousFlag;
    Boolean             stopFlag;
    int                 read_count;
    Boolean             isStreaming;
}

@property (weak, nonatomic) IBOutlet UITableView *tblView;

@property (strong, nonatomic) AVAudioPlayer * audioPlayer;
@property (weak, nonatomic) IBOutlet UILabel *lblDeviceName;
@property (weak, nonatomic) IBOutlet UILabel *lblDeviceState;
@property (strong, nonatomic) IBOutlet UIView *mWorkStationChildView;
@property (weak, nonatomic) IBOutlet UILabel *lblBatteryLevel;

@property (weak, nonatomic) IBOutlet UIButton *btnSend;
@property (weak, nonatomic) IBOutlet UIButton *btnClear;
@property (weak, nonatomic) IBOutlet UIButton *btnStreaming;
@property (weak, nonatomic) IBOutlet UIProgressView *proBar;
@property (weak, nonatomic) IBOutlet UILabel *lblProgress;

@property (weak, nonatomic) IBOutlet UIImageView *dataImage;
@property (weak, nonatomic) IBOutlet UILabel *lblTip;

@end
