//
//  ImageBaseViewController.h
//  SmartHub
//
//  Created by apple on 14/12/9.
//  Copyright (c) 2014年 Panda. All rights reserved.
//

//#import "BaseViewController.h"
#import "../../ELCImagePicker/ELCImagePickerController.h"
#import "../../ELCImagePicker/ELCAlbumPickerController.h"
#import "MBProgressHUD.h"

@interface ImageBaseViewController : UIViewController<ELCImagePickerControllerDelegate>
{
    NSString *mImageName;
    
    UIView              *maskView;
    UILabel             *mProgressLabel;
    MBProgressHUD       *HUD;
}

@property (nonatomic, retain)    UIAlertView   *mAlertView;

- (void)setImageName:(NSString*)name;
- (void)openCameraRoll;
- (void)finishedImportImage;

@end
