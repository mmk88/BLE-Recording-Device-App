//
//  ImageBaseViewController.m
//  SmartHub
//
//  Created by apple on 14/12/9.
//  Copyright (c) 2014年 Panda. All rights reserved.
//

#import "ImageBaseViewController.h"
#import "Const.h"
#import "../Utility/Utility.h"

@interface ImageBaseViewController ()
{
    NSDictionary        *imageDict;
    NSTimer             *progressTimer;
    float                importProgress;
    NSThread            *importThread;
    BOOL                isFoundAsset;
    ALAsset             *foundAsset;
    BOOL                isStopImport;
}
@end

@implementation ImageBaseViewController

@synthesize mAlertView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    mAlertView = nil;
    
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setImageName:(NSString*)name
{
    mImageName = name;
}

#pragma mark - Camera Roll Import(elc Image Picker)
- (void)openCameraRoll
{
    ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];
    elcPicker.maximumImagesCount = 1;
    elcPicker.returnsOriginalImage = NO; //Only return the fullScreenImage, not the fullResolutionImage
    elcPicker.imagePickerDelegate = self;
    [self presentViewController:elcPicker animated:YES completion:nil];
}

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(copyMediaFromCameraRollLibrary:) userInfo:info repeats:NO];
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) copyMediaFromCameraRollLibrary:(NSTimer *)timer
{
    NSDictionary *info = (NSDictionary *)timer.userInfo;
    
    /********************************/
    imageDict = nil;
    for(NSDictionary *dict in info)
    {
        imageDict = dict;
    }
    if( imageDict == nil )
        return;
    isStopImport = NO;
    [self showProgress];
    /*********************************************************************/
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(StartImport) userInfo:nil repeats:NO];
    
    importProgress  = 0.0;
    /*********************************************************************/
}

- (void)StartImport
{
    importThread = [[NSThread alloc] initWithTarget:self selector:@selector(importFromCamThreadProc) object:nil];
    [importThread start];
    progressTimer   = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(refreshProgress) userInfo:nil repeats:YES];
}

- (void) importFromCamThreadProc
{
    NSURL           *srcUrl;
    
    srcUrl       = [imageDict objectForKey:UIImagePickerControllerReferenceURL];
    
    ALAssetsLibrary *assetLibrary = [ALAssetsLibrary new];
    
    [assetLibrary assetForURL:srcUrl resultBlock:^(ALAsset *asset)
     {
         if( asset == nil ){
             isFoundAsset = NO;
             [assetLibrary enumerateGroupsWithTypes:ALAssetsGroupPhotoStream
                                         usingBlock:^(ALAssetsGroup *group, BOOL *stop)
              {
                  [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                      if( isStopImport )
                          *stop = YES;
                      if([result.defaultRepresentation.url isEqual:srcUrl])
                      {
                          *stop = YES;
                          isFoundAsset = YES;
                          foundAsset = result;
                      }
                  }];
              }
              
                    failureBlock:^(NSError *error)
              {
                  NSLog(@"Error: Cannot load asset from photo stream - %@", [error localizedDescription]);
                  
              }];
             while (!isFoundAsset && !isStopImport)
             {
                 [NSThread sleepForTimeInterval:0.01];
             }
             if( isFoundAsset )
                 asset = foundAsset;
             if( asset == nil ){
                 NSError *err = [[NSError alloc] init];
                 [self proccessResultofImport:err];
                 return;
             }
         }
         
         if( isStopImport ){
             return;
         }
         
         ALAssetRepresentation *rep = [asset defaultRepresentation];
         NSUInteger length = (NSUInteger)[rep size];
         
         // Local File
         NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:mImageName];
         if (file == nil)
         {
             [[NSFileManager defaultManager] createFileAtPath:mImageName contents:nil attributes:nil];
             file = [NSFileHandle fileHandleForWritingAtPath:mImageName];
         }
         
         // Import to Local
         NSUInteger offset = 0;
         NSData *data;
         NSUInteger bytesCopied;
         NSUInteger chunkSize = 100 * 1024;
         uint8_t *buffer = malloc(chunkSize * sizeof(uint8_t));
         do
         {
             if(isStopImport)
                 break;
             bytesCopied = [rep getBytes:buffer fromOffset:offset length:chunkSize error:nil];
             offset += bytesCopied;
             data = [[NSData alloc] initWithBytes:buffer length:bytesCopied];
             [file writeData:data];
             importProgress = (100.0 * offset)/length;
         } while(offset < length);
         [file closeFile];
         
         // Finish importing to local
         [self proccessResultofImport:nil];
     }
                 failureBlock:^(NSError *err)
     {
         [self proccessResultofImport:err];
     }
     ];
}

- (void)proccessResultofImport:(NSError *)error
{
    isStopImport = YES;
    if (error == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishedImportImage];
        });
    }
    else {
        [self showAlertMessage:[Utility NSLocalizedString:@"Import is failed"] withOkButton:[Utility NSLocalizedString:@"OK"] withCancelButton:nil withTag:0];
    }
}

- (void)refreshProgress
{
    if( isStopImport )
    {
        [self hideProgress];
        [progressTimer invalidate];
        progressTimer = nil;
        return;
    }
    
   [self setProgress:importProgress];
}

- (void)finishedImportImage
{
    
}

#pragma mark - Progress methods
- (void)showProgress
{
    mProgressLabel.text = @"";
    [self.view addSubview:maskView];
    [self.view addSubview:mProgressLabel];
    [self.view addSubview:HUD];
    [HUD show:YES];

}

- (void)hideProgress {
    //[self cancelAudioBtn:nil];
    [HUD hide:YES];
}

-(void) cancelProgress
{
    [self hideProgress];
}

- (void)setProgress:(float)value
{
    mProgressLabel.text = [NSString stringWithFormat:@"%.1f%%", value];
}

#define ALERT_OFFLINE 100
- (void)showAlertMessage:(NSString*)msg withOkButton:(NSString*)okBtn withCancelButton:(NSString*)cancelBtn withTag:(int)tag
{
    if( mAlertView != nil ){
        if( mAlertView.tag == ALERT_OFFLINE )
            return;
        [mAlertView dismissWithClickedButtonIndex:1 animated:YES];
    }
    if( cancelBtn ){
        mAlertView = [[UIAlertView alloc] initWithTitle:nil
                                                message:msg
                                               delegate:self
                                      cancelButtonTitle:okBtn
                                      otherButtonTitles:cancelBtn, nil];
    } else {
        mAlertView = [[UIAlertView alloc] initWithTitle:nil
                                                message:msg
                                               delegate:self
                                      cancelButtonTitle:okBtn
                                      otherButtonTitles:nil];
    }
    mAlertView.tag = tag;
    mAlertView.delegate = self;
    
    [mAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if( alertView.tag == ALERT_OFFLINE )
    {
        if( buttonIndex == 0 )
        {
            
        }
    }
    mAlertView = nil;
}

@end
