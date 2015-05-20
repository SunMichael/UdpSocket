#import <UIKit/UIKit.h>
#import "GCDAsyncUdpSocket.h"
#import "GCDAsyncSocket.h"
@class ViewController;


@interface AppDelegate : UIResponder <UIApplicationDelegate,GCDAsyncUdpSocketDelegate,GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *s;
}
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) ViewController *viewController;

@end
