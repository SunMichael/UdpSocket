//
//  AdressTool.h
//  UdpEchoClient
//
//  Created by mac on 15/5/12.
//
//

#import <Foundation/Foundation.h>

@interface AdressTool : NSObject

+ (NSString *)getMacAdress;

+ (NSArray *)getIpAddresses ;

+ (NSArray *) getSSIDAndMAC ;

+ (NSString *) getWiFiSSID ;
@end
