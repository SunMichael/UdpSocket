#import "ViewController.h"
#import "GCDAsyncUdpSocket.h"
#import "DDLog.h"
#import "AdressTool.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

typedef enum : NSInteger {
    MessageTypeSsid,
    MessageTypePassword,
    MessageTypeIPAdress,
} MessageType;

typedef enum : NSUInteger {
    MessageSubTypeLength,
    MessageSubTypeContent,
    MessageSubTypeCoded,
    MessageSubTypeCheck,
} MessageSubType;

@interface ViewController () <GCDAsyncUdpSocketDelegate >
{
    long tag ;
    GCDAsyncUdpSocket *udpSocket;
    
    NSMutableString *log;
    NSMutableString *senderString ;    //需要发送的23位2进制数据
    NSString *ssidString ;            //SSID字符
    NSTimer *timer ;
    int repeatCount ;                 //发报次数

    
    BOOL havePassWord;              //是否加密
    NSString *passWord ;           //SSID密码
    NSMutableArray *sumCounts ;    //SSID值的和
    MessageType currentType ;
    int sendedCount ;
    NSTimeInterval  timeout;      //超时时间
}

@end


@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        log = [[NSMutableString alloc] init];
    }
    return self;
}

- (void)setupSocket
{
    // Setup our socket.
    // The socket will invoke our delegate methods using the usual delegate paradigm.
    // However, it will invoke the delegate methods on a specified GCD delegate dispatch queue.
    //
    // Now we can configure the delegate dispatch queues however we want.
    // We could simply use the main dispatc queue, so the delegate methods are invoked on the main thread.
    // Or we could use a dedicated dispatch queue, which could be helpful if we were doing a lot of processing.
    //
    // The best approach for your application will depend upon convenience, requirements and performance.
    //
    // For this simple example, we're just going to use the main thread.
    
    udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    NSError *error = nil;
    
    if (![udpSocket bindToPort:25000 error:&error])
    {

        return;
    }
    if (![udpSocket beginReceiving:&error])
    {

        return;
    }
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    if (udpSocket == nil)
    {
        [self setupSocket];
    }
    
    NSError *error;
    [udpSocket enableBroadcast:YES error:&error];
    
    if (error) {
        NSLog(@" Error = %@  ",error);
    }
    tag = 10;
    timeout = 60 ;
    sumCounts = [[NSMutableArray alloc] initWithCapacity:6];
    
//    NSString *message = @"ABCDsss";     //测试代码
//    [udpSocket sendData:[message dataUsingEncoding:NSUTF8StringEncoding] toHost:@"192.168.18.121" port:25000 withTimeout:-1 tag:15];
    [udpSocket beginReceiving:nil];
    
    
    addrField.text = [addrField.text stringByAppendingString:[AdressTool getIpAddresses][1]];
    portField.text = [portField.text stringByAppendingString:[AdressTool getSSIDAndMAC][1]];
    
    
    
}

-(void)sendMessageToSmartConfig{
    if (sumCounts.count > 0) {
        [sumCounts removeAllObjects];
    }
    [self sendMagicMessageRepeat]; //发送魔术报文
    
    NSMutableString *msgHead = [[NSMutableString alloc] initWithString:@"1001"];
    // ssid报文
    [self senderMessageFromatWithType:MessageTypeSsid withSubtype:MessageSubTypeLength withString:msgHead andContent:nil andIndex:0];
    
    NSString *bssidstring = [AdressTool getSSIDAndMAC][1];
    NSArray *array = [bssidstring componentsSeparatedByString:@":"];
    int index = 0;
    
    for (NSString *str in array) {
        NSString *ssidContentMsg = [self senderMessageFromatWithType:MessageTypeSsid withSubtype:MessageSubTypeContent withString:msgHead andContent:str andIndex:index];
        index++ ;
        NSLog(@" SSID Content Msg = %@  %@  %d",ssidContentMsg,str,index);
    }
    /*   测试代码
     const char *charsString = [bssidField.text cStringUsingEncoding:NSASCIIStringEncoding];
     for (int i= 0; i < strlen(charsString); i++) {
     currentType = MessageTypeSsid ;
     NSString *str = [NSString stringWithFormat:@"%c",charsString[i]];
     [self senderMessageFromatWithType:MessageTypeSsid withSubtype:MessageSubTypeContent withString:msgHead andContent:str andIndex:i];
     
     }
     */
    //******注意收集值的数组数据重复
    [self senderMessageFromatWithType:MessageTypeSsid withSubtype:MessageSubTypeCheck withString:msgHead andContent:nil andIndex:0];
    
    [self senderMessageFromatWithType:MessageTypeSsid withSubtype:MessageSubTypeCoded withString:msgHead andContent:nil andIndex:0];
    
    
    
    
    if (sumCounts.count > 0) {   //注意清除之前的数据
        [sumCounts removeAllObjects];
    }
    // password报文
    [self senderMessageFromatWithType:MessageTypePassword withSubtype:MessageSubTypeLength withString:msgHead andContent:passWord andIndex:0];
    
    const char *chars = [passWord cStringUsingEncoding:NSASCIIStringEncoding];
    for (int i=0; i< strlen(chars); i++) {
        currentType = MessageTypePassword ;
        [self senderMessageFromatWithType:MessageTypePassword withSubtype:MessageSubTypeContent withString:msgHead andContent:[NSString stringWithFormat:@"%c",chars[i]] andIndex:i];
    }
    
    [self senderMessageFromatWithType:MessageTypePassword withSubtype:MessageSubTypeCheck withString:msgHead andContent:nil andIndex:0];
    
    
    // ip地址报文
     [self senderMessageFromatWithType:MessageTypeIPAdress withSubtype:10 withString:msgHead andContent:nil andIndex:0];
    
    

}

//十六进制转ASCII
-(int )HexConvertToASCII:(NSString *)hexString{
    int j=0;
    Byte bytes[22];  ///3ds key的Byte 数组， 128位
    int int_ch;  /// 两位16进制数转化后的10进制数
    if (hexString.length == 1) {
        hexString = [@"0" stringByAppendingString:hexString];
    }
    for(int i=0;i<[hexString length];i++)
    {
        
        
        unichar hex_char1 = [hexString characterAtIndex:i]; ////两位16进制数中的第一位(高位*16)
        
        int int_ch1;
        
        if(hex_char1 >= '0' && hex_char1 <='9')
            
            int_ch1 = (hex_char1-48)*16;   //// 0 的Ascll - 48
        
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            
            int_ch1 = (hex_char1-55)*16; //// A 的Ascll - 65
        
        else
            
            int_ch1 = (hex_char1-87)*16; //// a 的Ascll - 97
        
        i++;
        
        unichar hex_char2 = [hexString characterAtIndex:i]; ///两位16进制数中的第二位(低位)
        
        int int_ch2;
        
        if(hex_char2 >= '0' && hex_char2 <='9')
            
            int_ch2 = (hex_char2-48); //// 0 的Ascll - 48
        
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            
            int_ch2 = hex_char2-55; //// A 的Ascll - 65
        
        else
            
            int_ch2 = hex_char2-87; //// a 的Ascll - 97
        
        
        
        int_ch = int_ch1+int_ch2;
        
        NSLog(@"int_ch=%d",int_ch);
        
        bytes[j] = int_ch;  ///将转化后的数放入Byte数组里
        
        j++;
        
    }
    
    //    NSData *newData = [[NSData alloc] initWithBytes:bytes length:22];
    return int_ch;
}


-(void)sendMagicMessageRepeat{    //发送魔术字报文

    NSString *message = @"11100000011001100110011001100110";
    [udpSocket sendData:[message dataUsingEncoding:NSUTF8StringEncoding] toHost:[self formatIPAdressWith:message] port:43708 withTimeout:timeout tag:10];
    [NSThread sleepForTimeInterval:0.02];

    
}


/**
 *  根据拼接的数据生产IP地址
 *
 *  @param sender 拼接的数据
 *
 *  @return IP地址
 */
-(NSString *) formatIPAdressWith:(NSString *)sender{
    
    NSMutableArray *numbers = [[NSMutableArray alloc]init];
    for (int i=0; i< 4; i++) {
        NSString *binary = [sender substringWithRange:NSMakeRange(i*8, 8)];
        NSString *str = [NSString stringWithFormat:@"%d",[self toDecimal:binary]];
        [numbers addObject:str];
    }
    NSString *string =@"" ;
    for (NSString *str in numbers) {
        string = [string stringByAppendingString:[NSString stringWithFormat:@"%@.",str]];
    }
    string = [string substringToIndex:string.length-1];
    //    NSLog(@" 生成的IP地址为 == %@  %@",string,numbers);
    dispatch_async(dispatch_get_main_queue(), ^{
        logField.text = [logField.text stringByAppendingString:[@"\n IP:" stringByAppendingString:string]];
    });
    return string;
}
/**
 *  拼组消息
 *
 *  @param type    消息类型
 *  @param subtype 子类型
 *  @param sender  字符串
 *
 *  @return 拼接好的二进制字符串
 */
-(NSMutableString *)senderMessageFromatWithType:(MessageType) type withSubtype:(MessageSubType)subtype withString:(NSMutableString *)sender andContent:(NSString *)content andIndex:(int)index{
    switch (type) {
        case MessageTypeSsid:
        {
            sender =(NSMutableString *)[sender stringByAppendingString:@"000"];
            sender = [self senderMessageFromatWithSubtype:subtype withString:sender andContent:content andIndex:index];
        }
            break;
        case MessageTypePassword:
        {
            sender =(NSMutableString *)[sender stringByAppendingString:@"001"];
            sender = [self senderMessageFromatWithSubtype:subtype withString:sender andContent:content andIndex:index];
        }
            break;
        case MessageTypeIPAdress:
        {
            sender =(NSMutableString *)[sender stringByAppendingString:@"010"];
            sender =(NSMutableString *)[sender stringByAppendingString:@"100"];
            //第4位ip地址的值
            NSArray *array = [AdressTool getIpAddresses];
            NSString *ipAdress = array[1];
            NSArray *ips = [ipAdress componentsSeparatedByString:@"."];
            NSString *number = ips[3];
            NSString *numberbinary = [self toBinary:number];
            if (numberbinary.length < 8) {
                for (int  i=0; i< 8 -numberbinary.length; i++) {
                    numberbinary = [NSString stringWithFormat:@"0%@",numberbinary];
                }
            }
            sender = (NSMutableString *)[sender stringByAppendingString:[NSString stringWithFormat:@"%@00000",numberbinary]];
            sender = (NSMutableString *)[@"111000000" stringByAppendingString:sender];
            
            for (int i= 0; i<2; i++) {
                [udpSocket sendData:[sender dataUsingEncoding:NSUTF8StringEncoding] toHost:[self formatIPAdressWith:sender] port:43708 withTimeout:timeout tag:10];
                [NSThread sleepForTimeInterval:0.02];
                [self sendMagicMessageRepeat];
            }
            
        }
            break;
        default:
            break;
    }
    return sender ;
}
-(NSMutableString *)senderMessageFromatWithSubtype:(MessageSubType) subtype withString:(NSMutableString *)sender andContent:(NSString *)content andIndex:(int)index{
    switch (subtype) {
        case MessageSubTypeLength:
        {
            sender = (NSMutableString *)[sender stringByAppendingString:@"00"];
            NSString *string ;
            string = content == nil ? [self toBinary:@"6"] : [self toBinary:[NSString stringWithFormat:@"%lu",(unsigned long)content.length]];
            
            if (string.length < 6) {
                int number = 6 - (int)string.length ;
                for (int i=0; i < number; i++) {
                    string = [NSString stringWithFormat:@"0%@",string];
                }
            }
            sender = (NSMutableString *)[sender stringByAppendingString:[NSString stringWithFormat:@"%@00000000",string]];
        }
            break;
        case MessageSubTypeContent:
        {
            sender = (NSMutableString *)[sender stringByAppendingString:@"01"];
            //字符第几位
            NSString *indexStr = [self toBinary:[NSString stringWithFormat:@"%d",index+1]];
            if (indexStr.length < 6) {
                int number = 6 - (int)indexStr.length ;
                for (int i =0; i < number; i++) {
                    indexStr = [NSString stringWithFormat:@"0%@",indexStr];
                }
            }
            sender = (NSMutableString *)[sender stringByAppendingString:indexStr];

            unichar c ;
            if (currentType == MessageTypeSsid) {
//                c= [bssidField.text characterAtIndex:index];
                //字符在ASCII中的值,测试是使用假设已经十六进制转过的字符
                c = [self HexConvertToASCII:content];
            }else{
                c = [passWord characterAtIndex:index];
            }
            [sumCounts addObject:[NSNumber numberWithInteger:c]];
            NSString *indexStr2 = [self toBinary:[NSString stringWithFormat:@"%d",c]];
            if (indexStr2.length < 8) {
                int number = 8 - (int)indexStr2.length ;
                for (int i = 0; i < number; i++) {
                    indexStr2 = [NSString stringWithFormat:@"0%@",indexStr2];
                }
            }

            sender = (NSMutableString *)[sender stringByAppendingString:indexStr2];
            
        }
            break;
        case MessageSubTypeCheck:
        {
            sender = (NSMutableString *)[sender stringByAppendingString:@"10"];
            //取bssid值的和
            NSLog(@" sumCount == %@ ",sumCounts);
            int sumNumber = 0;
            for (NSNumber *number in sumCounts) {
                sumNumber += [number intValue];
            }
            
            NSString *binaryStr = [self toBinary:[NSString stringWithFormat:@"%d",sumNumber]];
            
            if (binaryStr.length < 14) {
                int number = 14 -(int)binaryStr.length ;
                for (int i=0; i< number; i++) {
                    binaryStr =[NSString stringWithFormat:@"0%@",binaryStr];
                }
            }
            sender = (NSMutableString *)[sender stringByAppendingString:binaryStr];
            
            
        }
            break;
        case MessageSubTypeCoded:
        {
            sender = (NSMutableString *)[sender stringByAppendingString:@"11"];
            if (havePassWord ==YES) { //加密
                sender = (NSMutableString *)[sender stringByAppendingString:@"0001"];
            }else{  //不加密
                sender = (NSMutableString *)[sender stringByAppendingString:@"0000"];
            }
            sender = (NSMutableString *)[sender stringByAppendingString:@"0000000000"];
            
        }
            break;
        default:
            break;
    }
    sender = (NSMutableString *)[@"111000000" stringByAppendingString:sender];
    for (int i=0; i<2; i++) {
        [udpSocket sendData:[sender dataUsingEncoding:NSUTF8StringEncoding] toHost:[self formatIPAdressWith:sender] port:43708 withTimeout:timeout tag:10];
        [NSThread sleepForTimeInterval:0.02f];
        [self sendMagicMessageRepeat];
    }
    
    
    return sender ;
}

//10进制转2进制
-(NSString *)toBinary:(NSString *)decimal
{
    
    int num = [decimal intValue];
    int remainder = 0;      //余数
    int divisor = 0;        //除数
    
    NSString * prepare = @"";
    
    while (true)
    {
        remainder = num%2;
        divisor = num/2;
        num = divisor;
        prepare = [prepare stringByAppendingFormat:@"%d",remainder];
        
        if (divisor == 0)
        {
            break;
        }
    }
    
    NSString * result = @"";
    for (int i = (int)prepare.length - 1; i >= 0; i --)
    {
        result = [result stringByAppendingFormat:@"%@",
                  [prepare substringWithRange:NSMakeRange(i , 1)]];
    }
    
    return result;
}
//2进制转10进制
-(int) toDecimal:(NSString *) input{
    int number = 0;
    for (int i = (int)input.length -1; i>=0; i--)
    {
        NSString *a=[input substringWithRange:NSMakeRange(i,1)];
        number +=[a intValue]*pow(2, input.length-1-i);
        //        NSLog(@"a=%@ zoneHour=%d dd=%lu hh=%1f",a,number,input.length-1-i,pow(2, input.length-1-i));
    }
    return number ;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address{
    NSLog(@"  did connect ");
    
}
- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error{
    NSLog(@" socket error == %@ ",error);
}



- (IBAction)send:(id)sender
{
    if (![messageField.text isEqualToString:@""]) {
        havePassWord = YES;
        passWord = messageField.text;
        [self sendMessageToSmartConfig];
    }else{
        havePassWord = NO;
        UIAlertView *alert =[[UIAlertView alloc] initWithTitle:@"" message:@"请输入密码" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
    }
    
    NSString *host = addrField.text;
    if ([host length] == 0)
    {
        return;
    }
    
    int port = [portField.text intValue];
    if (port <= 0 || port > 65535)
    {
        return;
    }
    
    NSString *msg = messageField.text;
    if ([msg length] == 0)
    {
        return;
    }

    [udpSocket beginReceiving:nil];
    //    tag++;
    
    
}
#pragma mark - UDP socket delegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    // You could add checks here
    NSLog(@" socket send data  %d %d  %@",[sock isIPv4Enabled],[sock localPort],[sock localHost]);
    dispatch_async(dispatch_get_main_queue(), ^{
        logField.text = [logField.text stringByAppendingString:[NSString stringWithFormat:@"\n Message sended %d",sendedCount]];
        sendedCount ++;
    });
    
}
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error{
    logField.text = [logField.text stringByAppendingString:[NSString stringWithFormat:@"\n %@",error.userInfo]];
}
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    // You could add checks here
    NSLog(@" send data with error  == %@",error);
    dispatch_async(dispatch_get_main_queue(), ^{
        logField.text = [logField.text stringByAppendingString:error.domain];
    });
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (msg)   //收到探针返回消息后发送一个消息
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            logField.text = [logField.text stringByAppendingString:[NSString stringWithFormat:@"\n Received Message == %@",msg]];
        });
        
        NSString *host = nil;
        uint16_t port = 0;
        [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        NSError *error ;
        if ([udpSocket connectToHost:host onPort:port error:&error]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                logField.text = [logField.text stringByAppendingString:@"\n UDP Socket Connect Success"];
            });
            
            GCDAsyncUdpSocket *socket2 =[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
//            if (![socket2 bindToPort:25001 error:nil]) {   //可以绑定端口也可以不绑定
            
//            }
//            [socket2 bindToPort:25000 error:nil];
            [socket2 sendData:[@"Tb smart config recv ok" dataUsingEncoding:NSUTF8StringEncoding] toHost:host port:25001 withTimeout:timeout tag:10];
            [socket2 beginReceiving:nil];
            NSLog(@" receive host = %@ ",host);

        }else{
            logField.text = [logField.text stringByAppendingString:@"\n UDP Socket Connect Failed"];
        }
        
    }
    else
    {
        NSString *host = nil;
        uint16_t port = 0;
        [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        
        
        logField.text = [logField.text stringByAppendingString:[NSString stringWithFormat:@"\n RECV: Unknown message from: %@:%hu", host, port]];
        
    }
}

-(void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
}
@end
