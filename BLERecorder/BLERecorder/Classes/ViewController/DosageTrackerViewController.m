//
//  DosageTrackerViewController.m
//  ECOSmartPen
//
//  Created by apple on 8/7/17.
//  Copyright © 2017 mac. All rights reserved.
//

#import "DosageTrackerViewController.h"
#import "Const.h"
#import <sqlite3.h>
#import <AudioToolbox/AudioToolbox.h>

#import <AVFoundation/AVAudioEngine.h>
#import <AVFoundation/AVAudioPlayerNode.h>
#import <AVFoundation/AVAudioTypes.h>
#import <AVFoundation/AVAudioMixerNode.h>
//#import "PopoverViewController.h"
//#import "UIPopoverController+iPhone.h"

//#import "ClipViewController.h"


#define MAX_LEN     999999
// Audio settings.
#define AUDIO_SAMPLE_RATE        8000
#define AUDIO_CHANNELS_PER_FRAME    1
#define AUDIO_BITS_PER_CHANNEL      8

//#define AUDIO_FRAMES_PER_PACKET 1
//#define AUDIO_BYTES_PER_PACKET 1
//#define AUDIO_BYTES_PER_FRAME 1



@interface DosageTrackerViewController ()
{
    //PopoverViewController *viewPopController;
    //UIPopoverController *popover;
    NSMutableArray  *playArray;
    NSMutableArray  *playStatusArray;
    Byte readAllData[MAX_LEN];
    int readSize;
    NSString        *currentTime;
    Boolean         busyFlag;
    int             recvMaxBytes;
    int             recv_mode;
    int             last_selection;
    
    AVAudioEngine       *engine;
    AVAudioMixerNode    *mixer;
    AVAudioPlayerNode   *player;
}

@end

@implementation DosageTrackerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    playArray   = [[NSMutableArray alloc] init];
    playStatusArray = [[NSMutableArray alloc] init];
    readSize = 0;
    isStreaming = NO;
   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleNotification:)
                                                 name:NotiValueChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleReadValue:)
                                                 name:ReadValueChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleWriteSuccess:)
                                                 name:WriteSuccessChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleDisconnected:)
                                                 name:DisconnectEvent
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleReadBatteryValue:)
                                                 name:ReadBatteryValueChange
                                               object:nil];
    
    childSafetyValue = 0;
    stopFlag =false;
    continiousFlag = false;
    [self progressInit];
    [self initArray];
    _proBar.progress = 0;
    [_lblBatteryLevel setText:[NSString stringWithFormat:@"%d %%",batteryLevel]];
    
    [_lblProgress setHidden:YES];
    [_proBar setHidden:YES];
    
    
    AVAudioSession *recordingSession = [AVAudioSession sharedInstance];
    [recordingSession setCategory:AVAudioSessionCategoryPlayAndRecord error:NULL];
    [recordingSession setActive:true error:nil];
    [self startMyPlaying];
}


-(void) initDatePicker
{
    
}

#pragma mark - refresh

-(void) refreshAllData
{

}
-(void) initArray
{
   
}


-(void) progressInit
{
    // Do any additional setup after loading the view.
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(self.view.center.x, self.view.center.y, 50, 50)];
    [button addTarget:self action:@selector(cancelProgress) forControlEvents:UIControlEventTouchUpInside];
    button.center = HUD.center;
    [HUD addSubview:button];
    
    HUD.delegate = self;
    [HUD hide:YES];
    
    maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, ScreenHeight)];
    [maskView setBackgroundColor:[UIColor blackColor]];
    maskView.alpha = 0.4;
    
    mProgressLabel = [[UILabel alloc] initWithFrame:CGRectMake(ScreenWidth/2 - 50, ScreenHeight/2 + 40, 100, 30)];
    mProgressLabel.text = @"";
    mProgressLabel.textAlignment = NSTextAlignmentCenter;
    mProgressLabel.textColor = [UIColor whiteColor];
    mProgressLabel.backgroundColor = [UIColor clearColor];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    if([[self getConnectStatus] isEqualToString:@"disconnect"])
    {
        [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(scanDevices) userInfo:nil repeats:NO];
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(connectProcessing) userInfo:nil repeats:NO];
    }
    else
    {
        _lblDeviceName.text = [self getSavedDeviceName];
        _lblDeviceState.text = @"Connected";
    }
    
    if(isRefresh)
    {
        [_btnClear setHidden:NO];
        [_btnStreaming setHidden:NO];
        [_btnSend setHidden:NO];
        
        [_proBar setHidden:YES];
        [_lblProgress setHidden:YES];
        read_count = 0;
        [playArray removeAllObjects];
        [playStatusArray removeAllObjects];
        [_tblView setHidden:YES];
        [_tblView reloadData];
    }
}



-(void) scanDevices
{
        [self showProgress];
        [mBLEComm startScanDevicesWithInterval:1.5 CompleteBlock:^(NSArray *devices)
         {
            for (CBPeripheral *per in devices)
             {
                 if([per.name containsString:@"VAPE"])
                 {
                     NSLog(@"devices : %@", per.name);
                 }
             }

        }];
}

-(void) connectProcessing
{
    if([[self getConnectStatus] isEqualToString:@"disconnect"])
    {
        [self showProgress];
        NSString *addr = [self getSavedDeviceAddress];
        if([addr length] < 2)
        {
            [self hideProgress];
            return;
        }
        NSLog(@"address : %@", addr);
        [mBLEComm connectionWithDeviceUUID:addr TimeOut:10 CompleteBlock:^(CBPeripheral *device_new, NSError *err)
         {
             if (device_new)
             {
                 NSLog(@"Discovery servicess...");
                 [mBLEComm discoverServiceAndCharacteristicWithInterval:5 CompleteBlock:^(NSArray *serviceArray, NSArray *characteristicArray, NSError *err)
                  {
                      [mBLEComm setNotificationForCharacteristicWithServiceUUID:@"6E400001-B5A3-F393-E0A9-E50E24DCCA9E" CharacteristicUUID:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E" enable:YES];
                      
                      [mBLEComm setNotificationForCharacteristicWithServiceUUID:@"180F" CharacteristicUUID:@"2A19" enable:YES];
                      
                      
                      [self showToastShort:@"Device Connected"];
                      NSLog(@"Device Connected");
                      
                      
                      read_count = 0;
                      _proBar.progress = 0;
                      
                      dispatch_async(dispatch_get_main_queue(), ^{
                          _lblDeviceState.text = @"Connected";
                          [self saveConnectStatus:true];
                          _lblDeviceName.text = device_new.name;
                          [_btnClear setHidden:NO];
                          [_btnSend setHidden:NO];
                          [_btnStreaming setHidden:NO];
                          [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(getBatteryInformation) userInfo:nil repeats:NO];
                      });
                      
                  }];
             }
             else
             {
                 NSLog(@"Connect device failed.");
                 [self showToastShort:@"Device discconect."];
                 //[NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(connectProcessing) userInfo:nil repeats:NO];
                 [self hideProgress];
             }
         }];
    }
}

-(void)getBatteryInformation
{
    [self readBatteryData];
}
-(void)addGestureRecogniser:(UIView *)touchView{
    
    UITapGestureRecognizer *singleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(maskViewTouch)];
    [touchView addGestureRecognizer:singleTap];
}
-(void)maskViewTouch{
  
}


#pragma mark - Button Event

- (IBAction)yourESPButtonClick:(id)sender {
    [self performSegueWithIdentifier:@"segueYourESP" sender:self];
}

- (IBAction)editImageButtonClick:(id)sender {
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
    {
        [self openWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    }
}

CGContextRef maxContext;

-(IBAction)sendButtonClick:(id)sender
{
    Byte data[1] = {0};
    data[0] = 0x41;
    NSData *cmdData = [[NSData alloc] initWithBytes:data length:1];
    [self sendBLEData:cmdData];
    busyFlag =false;
    read_count = 0;
    isRefresh = NO;
}

-(IBAction)clearButtonClick:(id)sender
{
    [self confirmClear];
}

-(IBAction)streamingButtonClick:(id)sender
{
    if([_btnStreaming.titleLabel.text isEqualToString:@"Streaming"])
    {
        Byte data[1] = {0};
        data[0] = 0x46;
        NSData *cmdData = [[NSData alloc] initWithBytes:data length:1];
        [self sendBLEData:cmdData];
        busyFlag =false;
        read_count = 0;
    }
    else
    {
        Byte data[1] = {0};
        data[0] = 0x47;
        NSData *cmdData = [[NSData alloc] initWithBytes:data length:1];
        [self sendBLEData:cmdData];
        busyFlag =false;
        read_count = 0;
    }
}
- (CGContextRef) createARGBBitmapContextFromImage:(CGImageRef)inImage
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    void *          bitmapData;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    // Get image width, height. We'll use the entire image.
    size_t pixelsWide = CGImageGetWidth(inImage);
    size_t pixelsHigh = CGImageGetHeight(inImage);
    
    // Declare the number of bytes per row. Each pixel in the bitmap in this
    // example is represented by 4 bytes; 8 bits each of red, green, blue, and
    // alpha.
    bitmapBytesPerRow   = (pixelsWide * 4);
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
    
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (colorSpace == NULL)
    {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
    
    // Allocate memory for image data. This is the destination in memory
    // where any drawing to the bitmap context will be rendered.
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL)
    {
        fprintf (stderr, "Memory not allocated!");
        CGColorSpaceRelease( colorSpace );
        return NULL;
    }
    
    // Create the bitmap context. We want pre-multiplied ARGB, 8-bits
    // per component. Regardless of what the source image format is
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
        context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedFirst);
    
    if (context == NULL)
    {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
    }
    
    // Make sure and release colorspace before returning
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (unsigned char*) getPixelColor
{
    CGImageRef inImage;
    
    UIImage *temp = [self imageWithImage:_dataImage.image scaledToSize:CGSizeMake(240, 204)];
    inImage = temp.CGImage;
    
    // Create off screen bitmap context to draw the image into. Format ARGB is 4 bytes for each pixel: Alpa, Red, Green, Blue
    maxContext =[self createARGBBitmapContextFromImage:inImage];

    CGContextRef cgctx = maxContext;
    if (cgctx == NULL) { return nil; /* error */ }
    
    size_t w = CGImageGetWidth(inImage);
    size_t h = CGImageGetHeight(inImage);
    CGRect rect = {{0,0},{w,h}};
    
    
    // Draw the image to the bitmap context. Once we draw, the memory
    // allocated for the context for rendering will then contain the
    // raw image data in the specified color space.
    CGContextDrawImage(cgctx, rect, inImage);
    
    // Now we can get a pointer to the image data associated with the bitmap
    // context.
    
    //int res = 0;
    unsigned char* data = CGBitmapContextGetData (cgctx);
    if (data != NULL) {
        //offset locates the pixel in the data from x,y.
        //4 for 4 bytes of data per pixel, w is width of one row of data.
       /* int offset = 4*((w*round(point.y))+round(point.x));
        int alpha =  data[offset];
        int red = data[offset+1];
        int green = data[offset+2];
        int blue = data[offset+3];
        color = [UIColor colorWithRed:(red/255.0f) green:(green/255.0f) blue:(blue/255.0f) alpha:(alpha/255.0f)];
        res = res * 65536 + green * 256 + blue;*/
    }
    
    // When finished, release the context
    //CGContextRelease(cgctx);
    // Free image data memory for the context
    //if (data) { free(data); }
    
    //return res;
    return data;
}

#pragma mark - Bluetooth Received

-(void)bleNotification:(NSNotification*)noti
{
    //Boolean refresh_allow = false;
    NSData *receivedData = (NSData*)(noti.object);
    //NSLog(@"Lock BLE Receive data - %@",receivedData);
    int length = (int)[receivedData length];
    
    Byte *notifi = (Byte *)[receivedData bytes];
    
    if(isStreaming==YES)
    {
        if(notifi[0] == 0x47)
        {
            isStreaming = NO;
            [_btnClear setHidden:NO];
            [_btnSend setHidden:NO];
            [_btnStreaming setTitle:@"Streaming" forState:UIControlStateNormal];
        }
        short res[256];
        if([self decodeAdpcm:notifi length:131 result:res] == 1)
        {
            [self scheduleMy:res length:256];
        }
        return;
    }
    
    if(notifi[0] == 0x41 && busyFlag == false)
    {
        read_count = length;
        memcpy(readAllData, notifi, length);
        recvMaxBytes = (notifi[1]+notifi[2]*256+notifi[3]*256*256+notifi[4]*256*256*256)*4+5;
        if(read_count>=recvMaxBytes)
        {
            busyFlag = false;
            [playArray removeAllObjects];
            int cnt = (read_count - 5)/4;
            for(int i=0; i<cnt; i++)
            {
                int del = i*4+5;
                int size = (notifi[del]+notifi[del+1]*256+notifi[del+2]*256*256+notifi[del+3]*256*256*256);
                [playArray addObject:[NSNumber numberWithInteger:size]];
                if([playStatusArray count]<[playArray count])
                    [playStatusArray addObject:[NSNumber numberWithBool:NO]];
            }
            if(cnt<1)
            {
                [self showToastLong:@"Empty item!"];
                [_tblView setHidden:YES];
            }
            else{
                 [_tblView setHidden:NO];
                
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                NSFileManager *df = [NSFileManager defaultManager];
                for(int i=0; i<[playStatusArray count]; i++)
                {
                    NSString *fileName = [NSString stringWithFormat:@"file_%d.caf", i];
                    NSString *appFile = [documentsDirectory
                                         stringByAppendingPathComponent:fileName];
                    if([df fileExistsAtPath:appFile])
                    {
                        [playStatusArray replaceObjectAtIndex:i withObject:[NSNumber numberWithBool:@"YES"]];
                    }
                }
            }
            [_tblView reloadData];
        }
        else
        {
            busyFlag = true;
            recv_mode = 1;
            return;
        }
    }
    else if(notifi[0] == 0x42 && busyFlag == false)
    {
        read_count = length;
        memcpy(readAllData, notifi, length);
        recvMaxBytes = (notifi[1]+notifi[2]*256+notifi[3]*256*256+notifi[4]*256*256*256)+5;
        if(read_count>=recvMaxBytes)
        {
            busyFlag = false;
            [_tblView reloadData];
        }
        else
        {
            busyFlag = true;
            recv_mode = 2;
            [_proBar setHidden:NO];
            [_lblProgress setHidden:NO];
            return;
        }
    }
    else if(notifi[0] == 0x43 && busyFlag == false)
    {
        [playArray removeAllObjects];
        [playStatusArray removeAllObjects];
        [_tblView reloadData];
    }
    else if(notifi[0] == 0x46 && isStreaming == NO && busyFlag == false)
    {
        isStreaming = YES;
        [_btnClear setHidden:YES];
        [_btnSend setHidden:YES];
        [_btnStreaming setTitle:@"Stop" forState:UIControlStateNormal];
    }
    
    
    if(busyFlag == true)
    {
        memcpy(readAllData+read_count, notifi, length);
        read_count += length;
        //NSLog(@"read_count = %d, recvMaxBytes = %d", read_count, recvMaxBytes);
        
        int percent = read_count * 100 / recvMaxBytes;
        _proBar.progress = (float)percent/100;
        [_lblProgress setText:[NSString stringWithFormat:@"%d %%", percent]];
        if(read_count>=recvMaxBytes)
        {
            busyFlag = false;
            if(recv_mode == 1)
            {
                NSData *dats= [[NSData alloc] initWithBytes:readAllData length:read_count];
                NSLog(@"data - %@",  dats);
                [playArray removeAllObjects];
                //[playStatusArray removeAllObjects];
                int cnt = (read_count - 5)/4;
                for(int i=0; i<cnt; i++)
                {
                    int del = i*4+5;
                    int size = (readAllData[del]+readAllData[del+1]*256+readAllData[del+2]*256*256+readAllData[del+3]*256*256*256);
                    [playArray addObject:[NSNumber numberWithInteger:size]];
                    if([playStatusArray count]<[playArray count])
                        [playStatusArray addObject:[NSNumber numberWithBool:NO]];
                }
                
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                NSFileManager *df = [NSFileManager defaultManager];
                for(int i=0; i<[playStatusArray count]; i++)
                {
                    NSString *fileName = [NSString stringWithFormat:@"file_%d.caf", i];
                    NSString *appFile = [documentsDirectory
                                         stringByAppendingPathComponent:fileName];
                    if([df fileExistsAtPath:appFile])
                    {
                        [playStatusArray replaceObjectAtIndex:i withObject:[NSNumber numberWithBool:@"YES"]];
                    }
                }
                [_tblView setHidden:NO];
            }
            else if(recv_mode == 2)
            {
                Byte* saveD = (Byte*)malloc(read_count-5);
                memcpy(saveD, readAllData + 5,read_count-5);
                
                /*NSURL *purl = [NSURL fileURLWithPath:[[NSBundle mainBundle]pathForResource:@"test2" ofType:@"caf"]];
                
                NSData * cmdData = [[NSData alloc] initWithContentsOfURL:purl];*/
                
                NSData *cmdData = [[NSData alloc] initWithBytes:saveD length:read_count-5];
                
                
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                NSString *fileName = [NSString stringWithFormat:@"file_%d.caf", last_selection];
               NSString *appFile = [documentsDirectory
                                         stringByAppendingPathComponent:fileName];
                [cmdData writeToFile:appFile atomically:YES];
                
                
                //[self getAndCreatePlayableFileFromPcmData:fileName];
                [playStatusArray replaceObjectAtIndex:last_selection withObject:[NSNumber numberWithBool:YES]];
                [_proBar setHidden:YES];
                [_lblProgress setHidden:YES];
                
                [_btnSend setHidden:NO];
                [_btnClear setHidden:NO];
                [_btnStreaming setHidden:NO];
            }
            [_tblView reloadData];
            busyFlag = false;
            read_count = 0;
        }
    }
    
    
}
-(void) afterSuccess
{
    [_lblTip setHidden:YES];
    [_btnClear setHidden:NO];
    [_btnSend setHidden:NO];
}

-(void) bleWriteSuccess:(NSNotification*)noti
{

}

-(void) bleDisconnected:(NSNotification*)noti
{
    NSLog(@"Disconnected");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self saveConnectStatus:NO];
        if(childSafetyValue > 1)
            childSafetyValue -=2;
        _lblDeviceState.text = @"Disconnected";
        [_btnSend setHidden:NO];
        [_btnStreaming setHidden:NO];
        [_btnStreaming setHidden:NO];
        read_count = 0;
        [_proBar setHidden:YES];
        [_lblProgress setHidden:YES];
        [self showToastLong:@"Device Disconnected"];
    });
}

-(void)bleReadValue:(NSNotification*)noti
{
    NSData *receivedData = (NSData*)(noti.object);
    NSLog(@"Read Value - %@",receivedData);
    if([receivedData length]<1)
        return;
    //Byte *message = (Byte *)[receivedData bytes];
    [self hideProgress];
}

-(void)bleReadBatteryValue:(NSNotification*)noti
{
    NSData *receivedData = (NSData*)(noti.object);
    NSLog(@"Read Battery Value - %@",receivedData);
    if([receivedData length]<1)
        return;
    
    Byte *message = (Byte *)[receivedData bytes];
    int val = message[0];
    [_lblBatteryLevel setText:[NSString stringWithFormat:@"%d %%",val]];
    [self hideProgress];
}





#pragma mark - Bluetooth Send

-(void) sendBLEData:(NSData*) data
{
    [mBLEComm sendCommand:data ServiceUUID:@"6E400001-B5A3-F393-E0A9-E50E24DCCA9E" CharacteristicUUID:@"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"];
}
#pragma mark - Bluetooth Read

-(void) readBatteryData
{
    NSLog(@"Call readBatteryData");
    if([mBLEComm isConnection] == TRUE)
        [mBLEComm readCharacteristicWithServiceUUID:@"180F" CharacteristicUUID:@"2A19"];
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
    [HUD hide:YES];
}

-(void) cancelProgress
{
    [self hideProgress];
}

#pragma mark - Save Device Name

-(void)saveConnectStatus:(Boolean)status
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString* saveStatus = status==true?@"connect":@"disconnect";
    if (standardUserDefaults) {
        [standardUserDefaults setObject:saveStatus forKey:@"connect_status"];
        [standardUserDefaults synchronize];
    }
}

-(NSString*)getConnectStatus
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"abc";
    if (standardUserDefaults) {
        result=(NSString*)[standardUserDefaults valueForKey:@"connect_status"];
    }
    return result;
}

-(NSString*)getSavedDeviceName
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"abc";
    if (standardUserDefaults) {
        result=(NSString*)[standardUserDefaults valueForKey:@"device_name"];
    }
    return result;
}

-(NSString*)getSavedEmail
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"guest";
    if (standardUserDefaults) {
        result=(NSString*)[standardUserDefaults valueForKey:KEY_EMAIL];
        if(result == nil)
            result = @"guest";
    }
    return result;
}

-(NSString*)getSavedDeviceAddress
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"abc";
    if (standardUserDefaults) {
        result=(NSString*)[standardUserDefaults valueForKey:@"device_address"];
    }
    return result;
}

-(void)saveCatridgeName:(NSString*)myCat
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if (standardUserDefaults) {
        [standardUserDefaults setObject:myCat forKey:@"catridge_name"];
        [standardUserDefaults synchronize];
    }
}

-(NSString*)getSavedCatridgeName
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"abc";
    if (standardUserDefaults) {
        result=(NSString*)[standardUserDefaults valueForKey:@"catridge_name"];
    }
    if(result == nil)
        result = defaultCatridgeName;
    return result;
}


#pragma mark - show toast message
-(void) showToastShort:(NSString*) message
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = message;
    hud.margin = 10.f;
    hud.yOffset = 150.f;
    hud.removeFromSuperViewOnHide = YES;
    //hud.backgroundColor = [UIColor redColor];
    [hud hide:YES afterDelay:1.5];
}

-(void) showToastLong:(NSString*) message
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = message;
    hud.margin = 10.f;
    hud.yOffset = 150.f;
    hud.removeFromSuperViewOnHide = YES;
    //hud.backgroundColor = [UIColor redColor];
    [hud hide:YES afterDelay:3];
}

#pragma mark - vibrate
-(void) vibratePhone
{
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"])
    {
        AudioServicesPlaySystemSound (1352); //works ALWAYS as of this post
    }
    else
    {
        // Not an iPhone, so doesn't have vibrate
        // play the less annoying tick noise or one of your own
        AudioServicesPlayAlertSound (1105);
    }
}


#pragma mark  -- 打开相机或相册

/**
 *  打开相机或相册
 */


//
- (void)openWithSourceType:(UIImagePickerControllerSourceType)sourceType
{
    UIImagePickerController *imagePickerVC = [[UIImagePickerController alloc] init];
    imagePickerVC.sourceType = sourceType;
    //imagePickerVC.delegate = self;
    
    [self presentViewController:imagePickerVC animated:YES completion:nil];
}



#pragma mark - UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (playArray == nil)
        return 0;
    return [playArray count];    //count of section
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1; //count number of row from counting array hear cataGorry is An Array
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:MyIdentifier] ;
    }
    
    int pos = (int)indexPath.section;
    cell.textLabel.text = [NSString stringWithFormat:@"file %d", pos];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld bytes", (long)[[playArray objectAtIndex:pos] integerValue]];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont fontWithName:@"Arial" size:20.0];
    
    UIImage *image = nil;
    Boolean status = [[playStatusArray objectAtIndex:pos] boolValue];
    if(status == YES)
        image = [UIImage imageNamed:@"play"];
    else
        image = [UIImage imageNamed:@"download"];
        
    [cell.imageView setImage:image];
    
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.backgroundColor = [UIColor clearColor];
    [tableView setBackgroundView:nil];
    [tableView setBackgroundColor:[UIColor clearColor]];
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 20;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *v = [UIView new];
    [v setBackgroundColor:[UIColor clearColor]];
    return v;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    last_selection = (int)indexPath.section;
    Boolean status = [[playStatusArray objectAtIndex:last_selection] boolValue];
    if(status == YES)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        //NSString *fileName = [NSString stringWithFormat:@"file_%d.wav", last_selection];
        NSString *fileName = [NSString stringWithFormat:@"file_%d.caf", last_selection];
        NSString *appFile = [documentsDirectory
                             stringByAppendingPathComponent:fileName];
        
        NSFileManager *ff = [NSFileManager defaultManager];
        if(![ff fileExistsAtPath:appFile])
            return;
        NSURL *url = [NSURL fileURLWithPath:appFile];
        
        NSData *data=[[NSData alloc] initWithContentsOfURL:url];
        
        int packet = 131;
        int length = (int)[data length];
        Byte *pData=(Byte*)data.bytes;
        
        Byte pTemp[131];
        short res[256];
        for(int i=0; i<length/packet; i++)
        {
            memcpy(pTemp, pData+packet * i, packet);
            if([self decodeAdpcm:pTemp length:131 result:res] == 1)
            {
                [self scheduleMy:res length:256];
            }
        }
    }
    else
    {
        Byte data[2] = {0,0};
        data[0] = 0x42;
        data[1] = (Byte)last_selection;
        NSData *cmdData = [[NSData alloc] initWithBytes:data length:2];
        [self sendBLEData:cmdData];
        continiousFlag = false;
        read_count = 0;
        busyFlag = false;
        
        [_btnSend setHidden:YES];
        [_btnClear setHidden:YES];
        [_btnStreaming setHidden:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}
short indexTable[] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8 };
short stepTable[] = { 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28,
                  31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143,
                  157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544,
                  598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878,
                  2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894,
                  6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818,
                18500, 20350, 22385, 24623, 27086, 29794, 32767 };

-(int) decodeAdpcm:(Byte*)data length:(int)length result:(short*)output;
{
    // A ADPCM frame on Thingy ia 131 bytes long:
    // 2 bytes - predicted value
    // 1 byte  - index
    // 128 bytes - 256 4-bit samples convertable to 16-bit PCM
    
    if (length >= 131)
    {
       // Read 16-bit predicted value
        int32_t valuePredicted = (int16_t)((int16_t)(data[1]) | ((int16_t)data[0] << 8 ));
       
        // Read the first index
        int index = (int)(data[2]);
        unsigned char nextValue = 0;
        Boolean bufferStep = false;

        unsigned char delta = 0 ;    // index delta; each following frame is calculated based on the previous using an index
        unsigned char sign = 0;
        short step = stepTable[index];
        int count = 0;
        for(int i=0; i< (length - 3) * 2; i++)
        { // 3 bytes have already been eaten
            if (bufferStep)
            {
                delta = nextValue & 0x0F;
            } else {
                nextValue = data[3 + i / 2];
                delta = (nextValue >> 4) & 0x0F;
            }
            bufferStep = !bufferStep;
            
            index += indexTable[delta];
            index = MIN(MAX(index, 0), 88); // index must be <0, 88>
            
            sign  = delta & 8;    // the first bit of delta is the sign
            delta = delta & 7;   // the rest is a value
            
            int32_t diff = (int32_t)(step >> 3);
            if ((delta & 4) > 0) {
                diff += (int32_t)(step);
            }
            if ((delta & 2) > 0) {
                diff += (int32_t)(step >> 1);
            }
            if ((delta & 1) > 0) {
                diff += (int32_t)(step >> 2);
            }
            if (sign > 0) {
                valuePredicted -= diff;
            } else {
                valuePredicted += diff;
            }
            
            short value = (short)(MIN((int32_t)(32767), MAX(-32766, valuePredicted)));
            
            step = stepTable[index];
            output[count++]=value;
        }
    }
    return 1;
}

-(void) startMyPlaying
{
    AVAudioFormat* format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:16000 channels:1 interleaved:true];
    
    engine = [[AVAudioEngine alloc] init];
    mixer = [engine mainMixerNode];
    player = [[AVAudioPlayerNode alloc] init];
    [engine attachNode:player];
    [mixer setVolume:1.0];
    [engine connect:player to:mixer format:format];
    [player setVolume:1.0];
    
    
    NSError *error;
    @try {
        [engine prepare];
        [engine startAndReturnError:&error];
    }
    @catch(NSException *ex) {
        NSLog(@"AVAudioEngine.start() error: \(error.localizedDescription)");
    }
    [player play];
    
    
    
}

-(void) scheduleMy:(short*)pData length:(int) length
{
    if(!engine.isRunning)
    {
        // Streaming has been already stopped
        return;
    }
    
    const AVAudioFrameCount count = (AVAudioFrameCount)(length);
    AVAudioFormat *av = [mixer inputFormatForBus:(AVAudioNodeBus)0];
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:av frameCapacity:count];
    //let buffer = AVAudioPCMBuffer(pcmFormat: engine.mainMixerNode.inputFormat(forBus: 0), frameCapacity: AVAudioFrameCount(pcm16Data.count))!
    buffer.frameLength = buffer.frameCapacity;
    
    //var graphData = [Double]()
    for(int i=0;  i < length; i++)
    {
        buffer.floatChannelData[0 /* channel 1 */][i] = (float)pData[i] / (float)(32767);
        //NSLog(@"value - %d, %d", pData[i], i);
    }
    
    [player scheduleBuffer:buffer completionHandler:nil];
}

-(void) stopMyPlaying {
    [player stop];
    [engine stop];
    [engine reset];
    player = nil;
    engine = nil;
}

- (NSURL *) getAndCreatePlayableFileFromPcmData:(NSString *)filePath
{
    NSString *wavFileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
    NSString *wavFileFullName = [NSString stringWithFormat:@"%@.wav",wavFileName];
    
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [dirPaths objectAtIndex:0];
    NSString *wavFilePath = [docsDir stringByAppendingPathComponent:wavFileFullName];
    NSString *oldFilePath = [docsDir stringByAppendingPathComponent:filePath];
    NSLog(@"PCM file path : %@",filePath);
    
    FILE *fout;
    
    short   NumChannels     = AUDIO_CHANNELS_PER_FRAME;
    short   BitsPerSample   = AUDIO_BITS_PER_CHANNEL;
    int     SamplingRate    = AUDIO_SAMPLE_RATE;
    int     numOfSamples    = (int)[[NSData dataWithContentsOfFile:oldFilePath] length] / 2;
    
    int     ByteRate    = NumChannels * BitsPerSample * SamplingRate/8;
    short   BlockAlign  = NumChannels * BitsPerSample / 8;
    int     DataSize    = NumChannels * BitsPerSample * numOfSamples  / 8;
    int     chunkSize   = 16;
    int     totalSize   = 46 + DataSize;
    short   audioFormat = 1;
    
    if((fout = fopen([wavFilePath cStringUsingEncoding:1], "w")) == NULL)
    {
        printf("Error opening out file ");
    }
    
    fwrite("RIFF", sizeof(char), 4,fout);
    fwrite(&totalSize, sizeof(int), 1, fout);
    fwrite("WAVE", sizeof(char), 4, fout);
    fwrite("fmt ", sizeof(char), 4, fout);
    fwrite(&chunkSize, sizeof(int),1,fout);
    fwrite(&audioFormat, sizeof(short), 1, fout);
    fwrite(&NumChannels, sizeof(short),1,fout);
    fwrite(&SamplingRate, sizeof(int), 1, fout);
    fwrite(&ByteRate, sizeof(int), 1, fout);
    fwrite(&BlockAlign, sizeof(short), 1, fout);
    fwrite(&BitsPerSample, sizeof(short), 1, fout);
    fwrite("data", sizeof(char), 4, fout);
    fwrite(&DataSize, sizeof(int), 1, fout);
    
    fclose(fout);
    
    NSMutableData *pamdata = [NSMutableData dataWithContentsOfFile:oldFilePath];
    NSFileHandle *handle;
    handle = [NSFileHandle fileHandleForUpdatingAtPath:wavFilePath];
    [handle seekToEndOfFile];
    [handle writeData:pamdata];
    [handle closeFile];
    
    return [NSURL URLWithString:wavFilePath];
}

-(void) confirmClear {
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"Clear Data"
                              message:@"Are you sure you want to clear all data?"
                              delegate:self
                              cancelButtonTitle:@"Yes"
                              otherButtonTitles:nil];
    
    [alertView addButtonWithTitle:@"No"];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
    //[appDelegate.managedObjectContext deleteObject:selectedAccount];
    if (buttonIndex == 0) {
        Byte data[1] = {0};
        data[0] = 0x43;
        NSData *cmdData = [[NSData alloc] initWithBytes:data length:1];
        [self sendBLEData:cmdData];
        continiousFlag = false;
        busyFlag =false;
        read_count = 0;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSFileManager *df = [NSFileManager defaultManager];
        for(int i=0; i<50; i++)
        {
            NSString *fileName = [NSString stringWithFormat:@"file_%d.caf", i];
            NSString *appFile = [documentsDirectory
                                 stringByAppendingPathComponent:fileName];
            if([df fileExistsAtPath:appFile])
            {
                [df removeItemAtPath:appFile error:nil];
            }
        }
        
    } else if (buttonIndex == 1) {
        NSLog(@"Cancel button clicked");
    }
}

@end
