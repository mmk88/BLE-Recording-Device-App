//
//  YourESPViewController.m
//  ECOSmartPen
//
//  Created by apple on 8/7/17.
//  Copyright © 2017 mac. All rights reserved.
//

#import "YourESPViewController.h"
#import "Const.h"


@interface YourESPViewController ()
{
    NSMutableArray  *deviceArray;
    CBPeripheral    *device;

}
@end

@implementation YourESPViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addGestureRecogniser:_mMenuView];
    [self addGestureRecogniser:_mChildSafetyView];
    // Do any additional setup after loading the view.
    
    [self.tblView setBackgroundView:nil];
    [self.tblView setBackgroundColor:[UIColor clearColor]];
    [self.tblView setSeparatorColor:[UIColor clearColor]];
    
    deviceArray =  [[NSMutableArray alloc] init];
    
    [self progressInit];
    //[self initShowToast];
    
    if([[self getSavedConnectStatus] isEqualToString:@"connect"])
    {
        [_vwWorkStation setHidden:YES];
        [_tblDevices setHidden:NO];
        [_searchBtn setTitle:@"Disconnect" forState:UIControlStateNormal];
        [_lblMyDevice setText:[self getSavedDeviceName]];
    }
    else
    {
        [_vwWorkStation setHidden:NO];
        [_tblDevices setHidden:YES];
        [_searchBtn setTitle:@"Search" forState:UIControlStateNormal];
    }
    
    [_lblBatteryLevel setText:[NSString stringWithFormat:@"%d %%",batteryLevel]];
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
    maskView.alpha = 0.6;
    
    mProgressLabel = [[UILabel alloc] initWithFrame:CGRectMake(ScreenWidth/2 - 50, ScreenHeight/2 + 40, 100, 30)];
    mProgressLabel.text = @"";
    mProgressLabel.textAlignment = NSTextAlignmentCenter;
    mProgressLabel.textColor = [UIColor whiteColor];
    //mProgressLabel.backgroundColor = [UIColor greenColor];

}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DisconnectEvent object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    
    [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(scanDevices) userInfo:nil repeats:NO];
    [self changeChildSafetyButtonImage:childSafetyValue];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleDisconnected:)
                                                 name:DisconnectEvent
                                               object:nil];

}

-(void) scanDevices
{
     if([[self getSavedConnectStatus] isEqualToString:@"disconnect"])
     {
         [self showProgress:@"Searching for your ESP..."];
         [mBLEComm startScanDevicesWithInterval:2.5 CompleteBlock:^(NSArray *devices)
          {
              [deviceArray removeAllObjects];
              for (CBPeripheral *per in devices)
              {
                  if([per.name containsString:@"BLE"])
                  {
                      if(![deviceArray containsObject:per])
                          [deviceArray addObject:per];
                      NSLog(@"address %@",[per.identifier UUIDString]);
                  }
              }
              if([deviceArray count]>0)
                  device = [deviceArray objectAtIndex:0];
              [self.tblView reloadData];
              [self hideProgress];
          }];
     }
}
-(void)addGestureRecogniser:(UIView *)touchView{
    
    UITapGestureRecognizer *singleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(maskViewTouch)];
    [touchView addGestureRecognizer:singleTap];
}
-(void)maskViewTouch{
    [_mMenuView setHidden:YES];
    [_mChildSafetyView setHidden:YES];
}




#pragma mark - Button Event


- (IBAction)searchButtonClick:(id)sender {
    NSString *buttonName = _searchBtn.currentTitle;
    
    [self showProgress:@"Searching for your ESP..."];
    if([buttonName isEqualToString:@"Disconnect"])
    {
        [mBLEComm disconnectionDevice];
        [self saveDeviceName:@""];
        [self saveDeviceAddress:@""];
        [self saveConnectStatus:NO];
        if(childSafetyValue > 1)
            childSafetyValue -=2;
        [self changeChildSafetyButtonImage:childSafetyValue];
        sleep(1.0);
        [_tblDevices setHidden:YES];
        [_vwWorkStation setHidden:NO];
        [_searchBtn setTitle:@"Search" forState:UIControlStateNormal];
        [mBLEComm startScanDevicesWithInterval:1.5 CompleteBlock:^(NSArray *devices)
         {
             [deviceArray removeAllObjects];
             for (CBPeripheral *per in devices)
             {
                 if([per.name containsString:@"BLE"])
                 {
                     if(![deviceArray containsObject:per])
                         [deviceArray addObject:per];
                 }
             }
             if([deviceArray count]>0)
                 device = [deviceArray objectAtIndex:0];
             [self hideProgress];
             [self.tblView reloadData];
         }];
        isRefresh = YES;
    }
    else if([buttonName isEqualToString:@"Search"])
    {
        [mBLEComm startScanDevicesWithInterval:1.5 CompleteBlock:^(NSArray *devices)
         {
             [deviceArray removeAllObjects];
             for (CBPeripheral *per in devices)
             {
                 if([per.name containsString:@"BLE"])
                 {
                     if(![deviceArray containsObject:per])
                         [deviceArray addObject:per];
                     NSLog(@"address %@",[per.identifier UUIDString]);
                 }
             }
             if([deviceArray count]>0)
                 device = [deviceArray objectAtIndex:0];
             [self.tblView reloadData];
             [self hideProgress];
         }];
    }
}



- (IBAction)dosageSchedulerButtonClick:(id)sender {
    [self.navigationController popViewControllerAnimated:NO];
}
-(void)gotoSelectCatridge
{
    [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark - UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (deviceArray == nil)
        return 0;
    return [deviceArray count];    //count of section
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
    
    CBPeripheral *dev = (CBPeripheral*)[deviceArray objectAtIndex:indexPath.section];
    cell.textLabel.text = [dev name];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont fontWithName:@"Arial" size:20.0];
   
    [cell.imageView setImage:nil];
    //UIImageView *myView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"devicepen"]];
    //cell.accessoryView  = myView;
   
    
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
    selectIndex = indexPath.section;
    device = [deviceArray objectAtIndex:indexPath.section];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showProgress:@"Connecting..."];
    NSString* address = [device.identifier UUIDString];
    NSLog(@"connect addr:%@",address);
    [mBLEComm connectionWithDeviceUUID:address TimeOut:3 CompleteBlock:^(CBPeripheral *device_new, NSError *err)
     {
         if (device_new)
         {
             NSLog(@"Discovery servicess...");
             [mBLEComm discoverServiceAndCharacteristicWithInterval:3 CompleteBlock:^(NSArray *serviceArray, NSArray *characteristicArray, NSError *err)
              {
                  [mBLEComm setNotificationForCharacteristicWithServiceUUID:@"6E400001-B5A3-F393-E0A9-E50E24DCCA9E" CharacteristicUUID:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E" enable:YES];
                  
                  [mBLEComm setNotificationForCharacteristicWithServiceUUID:@"180F" CharacteristicUUID:@"2A19" enable:YES];
                  
                  NSLog(@"Device Connected");
                  isRefresh = YES;
                  //[self readBLEData];
                  dispatch_async(dispatch_get_main_queue(), ^{
                      [_tblDevices setHidden:NO];
                      [_vwWorkStation setHidden:YES];
                      [_lblMyDevice setText:device.name];
                      [self saveDeviceName:device.name];
                      [self saveDeviceAddress:address];
                      [self saveConnectStatus:YES];
                      [_searchBtn setTitle:@"Disconnect" forState:UIControlStateNormal];
                      [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(gotoSelectCatridge) userInfo:nil repeats:NO];
                  });
             }];
         }
         else
         {
             NSLog(@"Connect device failed.");
             [self hideProgress];
         }
     }];

}


#pragma mark - Progress methods
- (void)showProgress:(NSString*) str
{
    //mProgressLabel.text = str;
    [self.view addSubview:maskView];
    [self.view addSubview:mProgressLabel];
    [self.view addSubview:HUD];
    [HUD show:YES];
}

- (void)hideProgress {
    [self.view willRemoveSubview:maskView];
    [self.view willRemoveSubview:mProgressLabel];
    [self.view addSubview:HUD];
    [HUD hide:YES];
}

-(void) cancelProgress
{
    [self hideProgress];
}

#pragma Save Device Name

-(void)saveDeviceName:(NSString*)myDev
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if (standardUserDefaults) {
        [standardUserDefaults setObject:myDev forKey:@"device_name"];
        [standardUserDefaults synchronize];
    }
}

-(void)saveDeviceAddress:(NSString*)myDevAddr
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if (standardUserDefaults) {
        [standardUserDefaults setObject:myDevAddr forKey:@"device_address"];
        [standardUserDefaults synchronize];
    }
}

-(void)saveConnectStatus:(Boolean)status
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString* saveStatus = status==true?@"connect":@"disconnect";
    if (standardUserDefaults) {
        [standardUserDefaults setObject:saveStatus forKey:@"connect_status"];
        [standardUserDefaults synchronize];
    }
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

-(NSString*)getSavedDeviceAddress
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"abc";
    if (standardUserDefaults) {
        result=(NSString*)[standardUserDefaults valueForKey:@"device_address"];
    }
    return result;
}

-(NSString*)getSavedConnectStatus
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *result = @"abc";
    if (standardUserDefaults) {
             result=(NSString*)[standardUserDefaults valueForKey:@"connect_status"];
         }
    return result;
}
#pragma mark - Bluetooth Send

-(void) sendBLEData:(NSData*) data
{
    [mBLEComm sendCommand:data ServiceUUID:@"AAA0" CharacteristicUUID:@"AAA1"];
}
#pragma mark - Bluetooth Read

-(void) readBLEData
{
    NSLog(@"Call readBLEData");
    [mBLEComm readCharacteristicWithServiceUUID:@"AAA0" CharacteristicUUID:@"AAA1"];
}


#pragma mark - Bluetooth Received

-(void) bleDisconnected:(NSNotification*)noti
{
    NSLog(@"Disconnected");
    [self showToastLong:@"Device Disconnected"];
    [self saveConnectStatus:NO];
    if(childSafetyValue > 1)
        childSafetyValue -=2;
    [self changeChildSafetyButtonImage:childSafetyValue];
    isRefresh = YES;
}

-(void)bleReadValue:(NSNotification*)noti
{
    NSData *receivedData = (NSData*)(noti.object);
    NSLog(@"Read Value - %@",receivedData);
    if([receivedData length]<1)
        return;
    
    Byte *message = (Byte *)[receivedData bytes];
    int val = message[0];
    if(val > 0)
    {
        childSafetyValue = CHILD_SAFETY_OFF;
        [self changeChildSafetyButtonImage:childSafetyValue];
    }
    else
    {
        childSafetyValue = CHILD_SAFETY_ON;
        [self changeChildSafetyButtonImage:childSafetyValue];
    }
    [self hideProgress];
    [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(gotoSelectCatridge) userInfo:nil repeats:NO];
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
    batteryLevel = val;
    [self hideProgress];
    [self setBattery:val];
}

-(void)setBattery:(int)val;
{
    if(val == 100)
    {
        [_imgBattery setImage:[UIImage imageNamed:@"b100"]];
    }
    else if(val>75)
    {
        [_imgBattery setImage:[UIImage imageNamed:@"b75"]];
    }
    else if(val>50)
    {
        [_imgBattery setImage:[UIImage imageNamed:@"b50"]];
    }
    else if(val>25)
    {
        [_imgBattery setImage:[UIImage imageNamed:@"b25"]];
    }
    else if(val>0)
    {
        [_imgBattery setImage:[UIImage imageNamed:@"b0"]];
    }
}
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

#pragma mark - child Safety button Image
-(void) changeChildSafetyButtonImage:(int) status
{
    switch(status)
    {
        case CHILD_SAFETY_ON_NONE:
            [_childSafetyButton setImage:[UIImage imageNamed:@"childonnone"] forState:UIControlStateNormal];
            [_childSafetyButton setEnabled:false];
            break;
        case CHILD_SAFETY_OFF_NONE:
            [_childSafetyButton setImage:[UIImage imageNamed:@"childoffnone"] forState:UIControlStateNormal];
            [_childSafetyButton setEnabled:false];
            break;
        case CHILD_SAFETY_ON:
            [_childSafetyButton setImage:[UIImage imageNamed:@"childsafetyon"] forState:UIControlStateNormal];
            [_childSafetyButton setImage:[UIImage imageNamed:@"childsafetyon_high"] forState:UIControlStateHighlighted];
            [_childSafetyButton setEnabled:true];
            _lblChildOn.font = [UIFont boldSystemFontOfSize:22.0];
            _lblChildOff.font = [UIFont systemFontOfSize:20.0];
            break;
        case CHILD_SAFETY_OFF:
            [_childSafetyButton setImage:[UIImage imageNamed:@"childsafetyoff"] forState:UIControlStateNormal];
            [_childSafetyButton setImage:[UIImage imageNamed:@"childsafetyoff_high"] forState:UIControlStateHighlighted];
            [_childSafetyButton setEnabled:true];
            _lblChildOff.font = [UIFont boldSystemFontOfSize:22.0];
            _lblChildOn.font = [UIFont systemFontOfSize:20.0];
            break;
    }
}





@end
