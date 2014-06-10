//
//  ViewController.h
//  Peeko
//
//  Created by Shahruk Khan on 4/23/14.
//  Copyright (c) 2014 Shahruk Khan and Minling Zhao. All rights reserved.
//

#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>

@interface ViewController : UIViewController <UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UITextField *EmailLoginField;
@property (strong, nonatomic) IBOutlet UITextField *PasswordLoginField;
@property (strong, nonatomic) IBOutlet UILabel *EmailLabel;
@property (strong, nonatomic) IBOutlet UILabel *PasswordLabel;
@property (strong, nonatomic) IBOutlet UIButton *SubmitButton;

//- (IBAction)LoginButtonPressed:(id)sender;
@end
