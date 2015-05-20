#import <UIKit/UIKit.h>


@interface ViewController : UIViewController
{
	IBOutlet UITextField *addrField;
	IBOutlet UITextField *portField;
	IBOutlet UITextField *messageField;

    __weak IBOutlet UITextView *logField;
    __weak IBOutlet UITextField *bssidField;
}

- (IBAction)send:(id)sender;

@end
