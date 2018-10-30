//
//  BlueTooth.m
//  BluetoothDemo
//
//  Created by whatywhaty on 16/4/13.
//  Copyright © 2016年 whatywhaty. All rights reserved.
//

#import "BlueTooth.h"

@interface BlueTooth ()

@property (nonatomic, assign)  CBCentralManagerState state;

@property (nonatomic, strong) NSMutableArray *DeviceArray;
@property (nonatomic, strong) NSMutableArray *ServiceArray;
@property (nonatomic, strong) NSMutableArray *CharacteristicArray;

@property (nonatomic, strong) CBPeripheral *ConnectionDevice;

@property (nonatomic, copy)  ScanDevicesCompleteBlock scanBlock;
@property (nonatomic, copy)  ConnectionDeviceBlock connectionBlock;
@property (nonatomic, copy)  ServiceAndCharacteristicBlock serviceAndcharBlock;
@end

@implementation BlueTooth

#define DEBUGLOG_BLE    1


#pragma mark - 自定义方法
static id _instance;
+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        _ServiceArray = [[NSMutableArray alloc] init];
        _CharacteristicArray = [[NSMutableArray alloc] init];
        _DeviceArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)startScanDevicesWithInterval:(NSUInteger)timeout CompleteBlock:(ScanDevicesCompleteBlock)block
{
#if DEBUGLOG_BLE
    NSLog(@"start search device ...");
#endif
    [self.DeviceArray removeAllObjects];
    [self.ServiceArray removeAllObjects];
    [self.CharacteristicArray removeAllObjects];
    self.scanBlock = block;
    [self.manager scanForPeripheralsWithServices:nil options:nil];
    [self performSelector:@selector(stopScanDevices) withObject:nil afterDelay:timeout];
}

- (void)stopScanDevices
{
#if DEBUGLOG_BLE
    NSLog(@"stop search device ...");
#endif
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopScanDevices) object:nil];
    [self.manager stopScan];
    if (self.scanBlock)
    {
        self.scanBlock(self.DeviceArray);
    }
    self.scanBlock = nil;
}




- (void)connectionWithDeviceUUID:(NSString *)uuid TimeOut:(NSUInteger)timeout CompleteBlock:(ConnectionDeviceBlock)block
{
    self.connectionBlock = block;
    [self performSelector:@selector(connectionTimeOut) withObject:nil afterDelay:timeout];
    for (CBPeripheral *device in self.DeviceArray)
    {
        if ([device.identifier.UUIDString isEqualToString:uuid])
        {
            [self.manager connectPeripheral:device options:@{ CBCentralManagerScanOptionAllowDuplicatesKey:@YES }];
            break;
        }
    }
}

- (void)disconnectionDevice
{
#if DEBUGLOG_BLE
    NSLog(@"device disconnect.");
#endif
    [self.ServiceArray removeAllObjects];
    [self.CharacteristicArray removeAllObjects];
    if(self.ConnectionDevice !=nil)
        [self.manager cancelPeripheralConnection:self.ConnectionDevice];
    self.ConnectionDevice = nil;
}

- (void)discoverServiceAndCharacteristicWithInterval:(NSUInteger)time CompleteBlock:(ServiceAndCharacteristicBlock)block
{
    [self.ServiceArray removeAllObjects];
    [self.CharacteristicArray removeAllObjects];
    self.serviceAndcharBlock = block;
    self.ConnectionDevice.delegate = self;
    
    [self.ConnectionDevice discoverServices:nil];
    
    [self performSelector:@selector(discoverServiceAndCharacteristicWithTime) withObject:nil afterDelay:time];
}

- (void)writeCharacteristicWithServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID data:(NSData *)data
{
    for (CBService *service in self.ConnectionDevice.services)
    {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]])
        {
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]])
                {
                    [self.ConnectionDevice writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                }
            }
        }
    }
}


- (BOOL)sendCommand:(NSData *)pktData ServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID
{
   
    NSMutableData *packet;
    packet = [[NSMutableData alloc] init];
    
    if( [pktData length] > 0 )
    {
        [packet appendData:pktData];
    }
    #if DEBUGLOG_BLE
    NSLog(@"BLE Send Command --> %@", packet);
    #endif
    
    [self writeCharacteristicWithServiceUUID:sUUID CharacteristicUUID:cUUID data:packet];
    return true;
}

- (BOOL)sendCommand:(Byte)cmd data:(NSData *)pktData ServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID
{
    Byte header[3];
    
    header[0] = 0;
    header[1] = cmd;
    if(pktData == nil)
        header[2] = 0;
    else
        header[2] = [pktData length];
    NSMutableData *packet;
    packet = [[NSMutableData alloc] initWithBytes:header length:3];
    
    if( [pktData length] > 0 )
    {
        [packet appendData:pktData];
    }
    #if DEBUGLOG_BLE
    NSLog(@"BLE Send Command --> %@", packet);
    #endif

    [self writeCharacteristicWithServiceUUID:sUUID CharacteristicUUID:cUUID data:packet];
    return true;
}

- (BOOL)sendPacket:(Byte)cmd packetIndex:(int)idx data:(NSData *)pktData ServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID
{
    Byte header[5];
    NSInteger pktLen;
    
    header[0] = 0;
    header[1] = cmd;
    if( pktData == nil )
        pktLen = 0;
    else
        pktLen = [pktData length] + 2;
    
    header[2] = pktLen & 0x00FF;
    header[3] = idx & 0x00FF;
    header[4] = (idx >> 8) & 0x00FF;
    
    NSMutableData *packet;
    packet = [[NSMutableData alloc] initWithBytes:header length:5];
    if( pktLen )
    {
        [packet appendData:pktData];
    }
    
#if DEBUGLOG_BLE
    NSLog(@"BLE Send Buf --> %@", packet);
#endif
    // send func
    [self writeCharacteristicWithServiceUUID:sUUID CharacteristicUUID:cUUID data:packet];
    return true;
}
- (void)setNotificationForCharacteristicWithServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID enable:(BOOL)enable
{
    for (CBService *service in self.ConnectionDevice.services)
    {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]])
        {
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]])
                {
                    [self.ConnectionDevice setNotifyValue:enable forCharacteristic:characteristic];
                }
            }
        }
    }
}
-(void)readCharacteristicWithServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID{
    for (CBService *service in self.ConnectionDevice.services)
    {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]])
        {
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]])
                {
                    [self.ConnectionDevice readValueForCharacteristic:characteristic];
                }
            }
        }
    }
}

#pragma mark - 私有方法

- (void)connectionTimeOut
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeOut) object:nil];
    if (self.connectionBlock)
    {
        self.connectionBlock(nil, [self wrapperError:@"连接设备超时!" Code:400]);
    }
    self.connectionBlock = nil;
}

- (void)discoverServiceAndCharacteristicWithTime
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeOut) object:nil];
    if (self.serviceAndcharBlock)
    {
        self.serviceAndcharBlock(self.ServiceArray, self.CharacteristicArray, [self wrapperError:@"发现服务和特征完成!" Code:400]);
    }
    self.connectionBlock = nil;
}

- (NSError *)wrapperError:(NSString *)msg Code:(NSInteger)code
{
    NSError *error = [NSError errorWithDomain:msg code:code userInfo:nil];
    return error;
}

#pragma mark - CBCentralManagerDelegate代理方法

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
#if DEBUGLOG_BLE
    NSLog(@"当前的设备状态:%ld", (long)central.state);
#endif
    self.state = (CBCentralManagerState)central.state;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
#if DEBUGLOG_BLE
    NSLog(@"Disconvered device : %@", peripheral);
    NSLog(@"advertisementData : %@", advertisementData);
#endif
    [self.DeviceArray addObject:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeOut) object:nil];
 #if DEBUGLOG_BLE
    NSLog(@"Device Connection succeed : %@", peripheral);
#endif
    self.ConnectionDevice = peripheral;
    self.ConnectionDevice.delegate = self;
    
    if (self.connectionBlock)
    {
        self.connectionBlock(peripheral, [self wrapperError:@"连接成功!" Code:401]);
    }
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;

{
    if (error)
    {
#if DEBUGLOG_BLE
        NSLog(@"The connection has timed out unexpectedly.:%@", error);
#endif
         [[NSNotificationCenter defaultCenter] postNotificationName:DisconnectEvent object:error];
    }
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;

{
    if (error)
    {
#if DEBUGLOG_BLE
        NSLog(@"The connection has timed out unexpectedly.:%@", error);
#endif
        
         [[NSNotificationCenter defaultCenter] postNotificationName:DisconnectEvent object:error];
    }
}






- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"搜索服务发生错误,错误信息:%@", error);
    }
    for (CBService *service in peripheral.services)
    {
        [self.ServiceArray addObject:service];
        [self.ConnectionDevice discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"搜索特征发生错误,错误信息:%@", error);
    }
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        [self.CharacteristicArray addObject:characteristic];
    }
}

- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic;
{
    NSLog(@"readValueForCharacteristic");
    
}
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
#if DEBUGLOG_BLE
        NSLog(@"didWriteValueForCharacteristic接收数据发生错误,%@", error);
#endif
        return;
    }
#if DEBUGLOG_BLE
    NSLog(@"didWriteValueForCharacteristic写入值发生改变,%@", error);
#endif
    [[NSNotificationCenter defaultCenter] postNotificationName:WriteSuccessChange object:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#if DEBUGLOG_BLE
    //NSLog(@"didUpdateNotificationStateForCharacteristic收到的数据为%@", characteristic.UUID);
#endif
    if (error)
    {
        NSLog(@"didUpdateValueForCharacteristic接收数据发生错误,%@", error);
        return;
    }
    NSString *uuid = [characteristic.UUID UUIDString];
    if([uuid isEqualToString:@"AAA1"])
        [[NSNotificationCenter defaultCenter] postNotificationName:ReadValueChange object:characteristic.value];
    else if([uuid isEqualToString:@"2A19"])
        [[NSNotificationCenter defaultCenter] postNotificationName:ReadBatteryValueChange object:characteristic.value];
    else
        [[NSNotificationCenter defaultCenter] postNotificationName:NotiValueChange object:characteristic.value];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    if (error)
    {
        NSLog(@"didUpdateNotificationStateForCharacteristic接收数据发生错误,%@", error);
        return;
    }
    //NSString *string=[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"didUpdateNotificationStateForCharacteristic收到的数据为%@", characteristic.UUID);

}
#pragma mark - getter
- (BOOL)isReady
{
    return self.state == CBCentralManagerStatePoweredOn ? YES : NO;
}

- (BOOL)isConnection
{
    return self.ConnectionDevice.state == CBPeripheralStateConnected ? YES : NO;
}


@end
