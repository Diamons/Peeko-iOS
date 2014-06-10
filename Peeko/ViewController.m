//
//  ViewController.m
//  Peeko
//
//  Created by Shahruk Khan on 4/23/14.
//  Copyright (c) 2014 Shahruk Khan and Minling Zhao. All rights reserved.
//

#import "ViewController.h"
#import "MapViewController.h"

@interface ViewController () <FBLoginViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.EmailLoginField.delegate = self;
    self.PasswordLoginField.delegate = self;
    _EmailLoginField.hidden = YES;
    _PasswordLoginField.hidden = YES;
    _EmailLabel.hidden = YES;
    _PasswordLabel.hidden = YES;
    _SubmitButton.hidden = YES;
    
    FBLoginView *loginView = [[FBLoginView alloc] init];
    loginView.delegate = self;
    
    // Align the button in the center horizontally
    loginView.frame = CGRectMake(10, 400, 300, 300);
    [self.view addSubview:loginView];
    
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView
                            user:(id<FBGraphUser>)user {
   
    [_SubmitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return NO;
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
