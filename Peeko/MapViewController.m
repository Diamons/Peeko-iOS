//
//  MapViewController.m
//  Peeko
//
//  Created by Shahruk Khan on 4/25/14.
//  Copyright (c) 2014 Shahruk Khan and Minling Zhao. All rights reserved.
//

#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

#import "MapViewController.h"
#import "QuartzCore/CALayer.h"
#import <SDWebImage/UIImageView+WebCache.h>

@interface MapViewController () <CLLocationManagerDelegate, UIScrollViewDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate>

@end

@implementation MapViewController

//Global variables
RMMapView *mapView;
float MyLastLatitude = 0;
float MyLastLongitude = 0;

bool minimizedDetail = false;
bool webviewActive = false;

float detailHeight = 0;

NSString *baseURL = @"http://peekoapp.com/";
//NSString *baseURL = @"http://peeko.dev/";
//NSString *baseURL = @"http://peeko.dev.192.168.1.16.xip.io/";

NSMutableArray *photos;
UIScrollView *detailView;
bool alertedBefore = false;

UIButton *bannerButton;
NSNumber *currentPromotionIndex;
UIWebView *webView;

bool FlagForFirstTimeOpen;
bool CloseButtonIsInfo;

Pinterest*  _pinterest;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    self.screenName = @"Map view!";
    
    _ArrayOfImages = [[NSMutableDictionary alloc] init];
    _ArrayOfPromotions = [[NSMutableDictionary alloc] init];
    _ArrayOfStores = [[NSMutableDictionary alloc] init];
    bannerButton = [[UIButton alloc] init];
    _pinterest = [[Pinterest alloc] initWithClientId:@"1438379" urlSchemeSuffix:@"peeko"];
    [self toggleNavigationButtons];
    
    // Do any additional setup after loading the view.
    
    RMMapboxSource *interactiveSource = [[RMMapboxSource alloc] initWithMapID:@"diamons.ifd6agf1"];
    mapView = [[RMMapView alloc] initWithFrame:_MapContainer.bounds andTilesource:interactiveSource];
    
    mapView.delegate = self;
    mapView.showsUserLocation = true;
    mapView.zoom = 16;
    
    //mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    mapView.adjustTilesForRetinaDisplay = YES; // these tiles aren't designed specifically for retina, so make them legible
    //mapView.userTrackingMode = RMUserTrackingModeFollowWithHeading;
    [_MapContainer addSubview:mapView];
    
    //Get the location now
    [self GetLocation];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//Get the user's latitude and longitude
-(void)GetLocation{
    NSLog(@"GET LOCATION");
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_locationManager startUpdatingLocation];
    
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    //Only show the alert once and center in on Times Square
    NSLog(@"FAILED!");
    if(!alertedBefore){
        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error getting your location." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [errorAlert show];
        alertedBefore = true;
        float tempLat = 40.759039;
        float tempLong =-73.984680;
        mapView.centerCoordinate = CLLocationCoordinate2DMake(tempLat, tempLong);
        //Show markers
        [self GetStoreMarkers:tempLat withLongitude:tempLong];
    }
    
}

-(void)locationManager: (CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    //NSLog(@"location updated!");
    CLLocation *currentLocation = [locations lastObject];
    float latitude = currentLocation.coordinate.latitude;
    float longitude = currentLocation.coordinate.longitude;
    
    //If moving at least a few blocks, then get the new markers for stores. This way we're not firing a request to the server every 4 seconds.
    bool proceed = [self checkWithLastLocation:latitude withLongitude:longitude];
    if(proceed == true){
        
        mapView.centerCoordinate = CLLocationCoordinate2DMake(latitude, longitude);
        
        //Store these numbers for future reference
        MyLastLatitude = latitude;
        //NSLog(@"Lat set to: %f", MyLastLatitude);
        MyLastLongitude = longitude;
        
        //Show markers
        [self GetStoreMarkers:currentLocation.coordinate.latitude withLongitude:currentLocation.coordinate.longitude];
    }
    //ONE TIME ALERT #2
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if (! [defaults boolForKey:@"secondTutorial"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"How to Shop"
                                                        message:@"This app is for NYC (beta). If you don't see any stores, try zooming out. To start shopping tap on a store icon to bring up that store's deal. Tap the banner to learn more about the deal."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        [alert show];
        [defaults setBool:YES forKey:@"secondTutorial"];
    }
}

-(void)GetStoreMarkers:(float)latitude withLongitude:(float)longitude{
    NSLog(@"GET");
    NSString *appendingString = [NSString stringWithFormat:@"api/stores/%.4f/%.4f/", latitude, longitude];
    NSString *ApiURL = [baseURL stringByAppendingString:appendingString];

    NSURL *url = [NSURL URLWithString:ApiURL];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;

    @try{
        id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        if(!response){
            NSLog(@"ERROR");
        }else{
            //NSLog(@"GOOD!");
            [self GenerateMarkersForStoresOnMap:response];
        }
    }
    @catch(...){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No network connection"
                                                        message:@"You must be connected to the internet to use this app."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    
}

-(void)GenerateMarkersForStoresOnMap:(id)response{
    //NSLog(@"Generate!");
    for(NSDictionary *store in response){
        float latitude = [[store objectForKey:@"latitude"] doubleValue];
        float longitude = [[store objectForKey:@"longitude"] doubleValue];
        NSString *icon = [store objectForKey:@"icon"];
        NSDictionary *promotions = [store objectForKey:@"promotions"];
        NSString *name = [store objectForKey:@"name"];
        NSLog(@"Name!");
        NSNumber *index = [NSNumber numberWithInt:[[store objectForKey:@"id"] intValue]];
        
        [_ArrayOfImages setObject:icon forKey:index];
        [_ArrayOfPromotions setObject:promotions forKey:index];
        [_ArrayOfStores setObject:store forKey:index];
        //NSLog(@"RESULT:%@",_ArrayOfImages[index]);
        
        CLLocationCoordinate2D coordinate =CLLocationCoordinate2DMake(latitude, longitude);
        RMAnnotation *annotation = [[RMAnnotation alloc] initWithMapView:mapView coordinate:coordinate andTitle: name];
        annotation.userInfo = index;
        [mapView addAnnotation:annotation];
        //NSString *iconURL = [_ArrayOfImages objectForKey:1];
       // NSLog(@"FOR #1: %i", ]);
        //NSLog(@"%@", _ArrayOfPromotions);
    }
}

//MapBox delegate for generating marker images

-(RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation{
    if(annotation.isUserLocationAnnotation){
        return nil;
    }
    
    NSNumber *index = [NSNumber numberWithInt:[annotation.userInfo intValue]];
    
    //Set up remote image ICON for the map
    NSURL *baseURLTemp = [NSURL URLWithString:baseURL];
    NSString *iconURL = [_ArrayOfImages objectForKey:index];
    iconURL = [iconURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    iconURL = [iconURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *imageURL = [NSURL URLWithString:iconURL relativeToURL:baseURLTemp];
    
    
    
    __block RMMarker *marker;
    
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager downloadWithURL:imageURL
                     options:0
                    progress:^(NSInteger receivedSize, NSInteger expectedSize)
     {
         // progression tracking code
     }
                   completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished)
     {
         if (image)
         {
             image = [UIImage imageWithCGImage:[image CGImage]
                                         scale: 2.25
                                        orientation:UIImageOrientationUp];
             marker = [[RMMarker alloc] initWithUIImage:image];
             marker.canShowCallout = true;
             
         }
     }];
    
    return marker;
    
}

-(BOOL)checkWithLastLocation:(float)latitude withLongitude:(float)longitude{

    //If they haven't been set yet, we know that this is our first location update.
    if(fabs(latitude) <= 0 || fabs(longitude) <= 0){
        return true;
    }
    float differenceInLatitude = latitude - MyLastLatitude;
    float differenceInLongitude = longitude - MyLastLongitude;
    
    //NSLog(@"Received Difference between %f and %f: %f", latitude,MyLastLatitude, differenceInLatitude);
    
    //If we've walked about 2 city blocks away, let's update the location eh?
    if(fabs(differenceInLatitude) > .00175){
        //NSLog(@"Latitude: %f", latitude);
        //NSLog(@"Past Latitude: %f", MyLastLatitude);
        //NSLog(@"HERE: %f", fabs(differenceInLatitude));
        return true;
    }
    
    if(fabs(differenceInLongitude) > .00175){
        //NSLog(@"HERE: %f", fabs(differenceInLongitude));
        return true;
    }
    
    //By default let's not update the location unless we absolutely have to
    return false;
}

- (IBAction)NavLocateButtonPressed:(id)sender {
    mapView.centerCoordinate = CLLocationCoordinate2DMake(MyLastLatitude, MyLastLongitude);
    /*
    if(!webviewActive){
        mapView.centerCoordinate = CLLocationCoordinate2DMake(MyLastLatitude, MyLastLongitude);
    }else{
        NSLog(@"CLOSE!");
        _NavButton.image = [UIImage imageNamed:@"locate.png"];
        [webView removeFromSuperview];
        detailView.hidden = NO;
    }
    */
    //Flip Flop
    //webviewActive = !webviewActive;

}

- (void)tapOnAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map{
    currentPromotionIndex = [NSNumber numberWithInt:[annotation.userInfo intValue]];
    NSDictionary *promotions = [_ArrayOfPromotions objectForKey:currentPromotionIndex];
    //NSLog(@"TEST #1: %@", [promotions objectForKey:@"image"]);
    for(NSDictionary *promo in promotions){
        //NSLog(@"%@", [promo objectForKey:@"image"]);
        
        
        /*UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 470, 320, 90)];
        //imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.image = [UIImage imageWithData:[self imageFromUrl:[promo objectForKey:@"image"]]];
        
        //Add shadow
        imageView.layer.shadowColor = [UIColor grayColor].CGColor;
        imageView.layer.shadowOffset = CGSizeMake(0,1);
        imageView.layer.shadowOpacity = 1;
        imageView.clipsToBounds = NO;
        [self.view addSubview:imageView];
         */
        
        detailView = [[UIScrollView alloc] init];
        detailView.alwaysBounceVertical = YES;
        detailView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        detailView.frame = CGRectMake(0, self.view.frame.size.height-100, 320, 100);
        detailView.layer.shadowColor = [UIColor grayColor].CGColor;
        //detailView.backgroundColor = [[self colorFromHexString:@"#FFFFFF"] colorWithAlphaComponent:.4];
        detailView.backgroundColor = [UIColor colorWithWhite: 1.0 alpha: 1];
        detailView.layer.shadowOffset = CGSizeMake(0, 4);
        detailView.layer.shadowOpacity = 1;
        [self.view addSubview: detailView];
        
        /* Button implementation*/
        UIImage *banner = [UIImage imageWithData:[self imageFromUrl:[promo objectForKey:@"image"]]];
        
        [bannerButton removeFromSuperview];
        //bannerButton = [[UIButton alloc] init];
        bannerButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        bannerButton.frame = CGRectMake(0, 0, 320, 100);
        bannerButton.layer.shadowColor = [UIColor grayColor].CGColor;
        bannerButton.layer.shadowOffset = CGSizeMake(0, 1);
        bannerButton.layer.shadowOpacity = 1;
        
        //UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget: self action:@selector(BannerSwipedUp:)];
        //[gestureRecognizer setDirection: (UISwipeGestureRecognizerDirectionUp)];
        
        UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc]
                                                     initWithTarget:self action:@selector(handlePanGesture:)];
        [detailView addGestureRecognizer:panRecognizer];
        
        
        //[bannerButton addGestureRecognizer:gestureRecognizer];
        
        [bannerButton setBackgroundImage:banner forState:UIControlStateNormal];
        [bannerButton addTarget:self action:@selector(BannerPressed:) forControlEvents:UIControlEventTouchUpInside];
        [detailView addSubview: bannerButton];
        
        
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    //NSLog(@"GESTURE!");
    CGPoint velocity = [gestureRecognizer velocityInView:detailView];
    
    //Check if the detail is open. If it isn't, don't scroll.
    //NSLog(@" %s", minimizedDetail ? "true" : "false");
    if(minimizedDetail){
        //Are we going down? If so minimize detail
        
        //NSLog(@"%f", velocity.y);
        if(velocity.y < 2000){
            CGPoint translation = [gestureRecognizer translationInView:detailView];
            CGRect bounds = [detailView bounds];
            [detailView setContentSize:CGSizeMake(self.view.frame.size.width,detailHeight)];
            // Translate the view's bounds, but do not permit values that would violate contentSize
            CGFloat newBoundsOriginX = bounds.origin.x - translation.x;
            CGFloat minBoundsOriginX = 0.0;
            CGFloat maxBoundsOriginX = detailView.contentSize.width - bounds.size.width;
            bounds.origin.x = fmax(minBoundsOriginX, fmin(newBoundsOriginX, maxBoundsOriginX));
            
            CGFloat newBoundsOriginY = bounds.origin.y - translation.y;
            CGFloat minBoundsOriginY = 0.0;
            CGFloat maxBoundsOriginY = detailView.contentSize.height - bounds.size.height;
            bounds.origin.y = fmax(minBoundsOriginY, fmin(newBoundsOriginY, maxBoundsOriginY));
            
            detailView.bounds = bounds;
            [gestureRecognizer setTranslation:CGPointZero inView:detailView];
            
            //If this is the opening gesture, go to the top. This is to fix a user interface bug.
            if(!FlagForFirstTimeOpen){
                if(gestureRecognizer.state == UIGestureRecognizerStateEnded)
                {
                    //NSLog(@"BAM!");
                    
                    CGRect bounds = [detailView bounds];
                    bounds.origin.x = 0;
                    bounds.origin.y = 0;
                    detailView.bounds = bounds;
                  
                    FlagForFirstTimeOpen = true;
                }
            }
        }else{
            [self minimizeDetail];
            if(gestureRecognizer.state == UIGestureRecognizerStateEnded)
            {
                CGRect bounds = [detailView bounds];
                bounds.origin.x = 0;
                bounds.origin.y = 0;
                detailView.bounds = bounds;
            }
        }
    }else{
        if(velocity.y < -1500){
            NSLog(@"Scrolly view");
            [self BannerPressed:nil];
        }
        /*
        if(gestureRecognizer.state == UIGestureRecognizerStateEnded)
        {
            CGRect bounds = [detailView bounds];
            bounds.origin.x = 0;
            bounds.origin.y = 0;
            detailView.bounds = bounds;
        }
         */
        
    }
}

-(void)BannerSwipedUp:(UISwipeGestureRecognizer *)recognizer{
    [self BannerPressed:nil];
}

-(void)BannerPressed:(id)sender{
    //We're in full view baby!
    if(!minimizedDetail){
        NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
        [FBAppEvents logEvent:[NSString stringWithFormat:@"%@ Viewed Full", currentPromotionIndex]];
        detailView.scrollEnabled = YES;
        [UIScrollView animateWithDuration: 0.5 animations: ^{
            self.NavigationTitle.topItem.title = [store objectForKey:@"name"];
            if(IPAD){
                detailView.backgroundColor = [self colorFromHexString:@"#f0fbfd"];
                detailView.frame = CGRectMake(0, 78, 320, self.view.frame.size.height-77);
            }else{
                detailView.frame = CGRectMake(0, 62, 320, self.view.frame.size.height-62);
            }
            [self GenerateFullPromoView];

        }];
        minimizedDetail = !minimizedDetail;
    }else{
        NSLog(@"NO scroll!");
        detailView.scrollEnabled = NO;
        [self minimizeDetail];
    }
    

}

-(void)GenerateFullPromoView{
    
    int descHeight = 0;
    detailHeight = 100; //Reset height tracker to height of banner
    detailHeight += 50; //Offset
    
    //Reset the position of the view
    CGRect bounds = [detailView bounds];
    bounds.origin.x = 0;
    bounds.origin.y = 0;
    detailView.bounds = bounds;
    if(IPAD){
        detailView.backgroundColor = [self colorFromHexString:@"#f0fbfd"];
    }
    UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget: self action:@selector(DetailSwiped:)];
    [gestureRecognizer setDirection: (UISwipeGestureRecognizerDirectionDown)];
    [detailView addGestureRecognizer:gestureRecognizer];
    
    UILabel *addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 111, 300, 20)];
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    addressLabel.text = [[NSMutableString alloc] initWithString:[store objectForKey:@"address"]];
    [detailView addSubview:addressLabel];
    
    NSDictionary *promotions = [_ArrayOfPromotions objectForKey:currentPromotionIndex];
    for(NSDictionary *promo in promotions){
        UILabel *descriptionLabel = [[UILabel alloc] initWithFrame: CGRectMake(10, 130, 300, 999)];
        NSMutableString *desc = [[NSMutableString alloc] initWithString:[promo objectForKey:@"description"]];
        descriptionLabel.text = desc;
        descriptionLabel.numberOfLines = 0;
        [descriptionLabel sizeToFit];
        [detailView addSubview:descriptionLabel];
        descHeight = (int)descriptionLabel.frame.size.height;
    }
    
    detailHeight += addressLabel.frame.size.height;
    detailHeight += descHeight;
    
    
    UIImage *callBackground = [UIImage imageNamed:@"button-call"];
    UIButton *callButton = [[UIButton alloc] init];
    [callButton setImage:callBackground forState:UIControlStateNormal];
    [callButton setFrame: CGRectMake(10, 140 + descHeight, 140, 170)];
    [callButton addTarget: self action:@selector(CallButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:callButton];
    detailHeight += callBackground.size.height; //Only one button
    
    UIImage *menuBackground = [UIImage imageNamed:@"button-menu"];
    UIButton *menuButton = [[UIButton alloc] init];
    [menuButton setImage:menuBackground forState:UIControlStateNormal];
    [menuButton setFrame: CGRectMake(170, 140 + descHeight, 140, 170)];
    [menuButton addTarget: self action:@selector(MenuButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:menuButton];
    
    UIImage *fbBackground = [UIImage imageNamed:@"button-facebook"];
    UIButton *fbButton = [[UIButton alloc] init];
    [fbButton setImage:fbBackground forState:UIControlStateNormal];
    [fbButton setFrame: CGRectMake(10, 320 + descHeight, 300, 80)];
    [fbButton addTarget: self action:@selector(FacebookButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:fbButton];
    detailHeight += fbBackground.size.height;
    
    UIImage *pinterestBackground = [UIImage imageNamed:@"button-pinterest"];
    UIButton *pinterestButton = [[UIButton alloc] init];
    [pinterestButton setImage:pinterestBackground forState:UIControlStateNormal];
    [pinterestButton setFrame: CGRectMake(10, 410 + descHeight, 300, 80)];
    [pinterestButton addTarget: self action:@selector(PinterestButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:pinterestButton];
    detailHeight += pinterestBackground.size.height;
    
    //Set the height to accomodate all this stuff
    [detailView setContentSize:CGSizeMake(self.view.frame.size.width,detailHeight)];
    
    //NSLog(@"TEST #1: %@", [promotions objectForKey:@"image"]);
    
    //Get menu URL
    /*
    for(NSDictionary *promo in promotions){
        UIImage *menu = [UIImage imageWithData:[self imageFromUrl:[promo objectForKey:@"menu"]]];
        UIImageView *menuView = [[UIImageView alloc] initWithImage:menu];
        menuView.frame = CGRectMake(10, 500, 300, 100);
        [detailView addSubview:menuView];
    }
     */
    
    /*
    NSDictionary *promotions = [_ArrayOfPromotions objectForKey:currentPromotionIndex];
    for(NSDictionary *promo in promotions){
       // UIImage *banner = [UIImage imageWithData:[self imageFromUrl:[promo objectForKey:@"image"]]];
        //UIImageView *bannerImage = [[UIImageView alloc] initWithImage: banner];
        //bannerImage.frame = CGRectMake(0, 0, 320, 100);
        //bannerImage.layer.shadowOpacity = 0;
        //[detailView addSubview: bannerImage];
        
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(bannerImage, <#CGFloat y#>, <#CGFloat width#>, <#CGFloat height#>)
    }
    */
    
    //ONE TIME ALERT #3
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if (! [defaults boolForKey:@"thirdTutorial"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Redeeming your Offer"
                                                        message:@"To redeem this offer simply walk in and present the offer to the cashier. No vouchers to print or buy ahead of time - it's that easy! Tap the banner again or swipe downward to return to the Peeko shopping map!"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        [alert show];
        [defaults setBool:YES forKey:@"thirdTutorial"];
    }

}

- (IBAction)CloseButtonPressed:(id)sender {
    if(CloseButtonIsInfo){
        UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:@"" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:
                                @"Suggest a Shop",
                                @"Send Feedback",
                                @"Email to a Friend",
                                @"Rate this App",
                                nil];
        popup.tag = 1;
        [popup showInView:[UIApplication sharedApplication].keyWindow];
    }else{
        [self toggleNavigationButtons];
        
        [webView removeFromSuperview];
        detailView.hidden = NO;
    }
}

- (void)actionSheet:(UIActionSheet *)popup clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (popup.tag) {
        case 1: {
            switch (buttonIndex) {
                case 0:
                    [self sendEmail:@"support@peekoapp.com" withSubject:@"Store Suggestion for Peeko" withBody:@"Store X 123 Fake Street offers free drink and appetizer with their lunch combo!"];
                    break;
                case 1:
                    [self sendEmail:@"support@peekoapp.com" withSubject:@"Feedback for Peeko" withBody:@"Hi Peeko I love your app! I use your app every day and think adding feature X would be great!"];
                    break;
                case 2:
                    [self sendEmail:nil withSubject:@"Peeko App" withBody:@"Wanna try something new for lunch next week with this cool app? http://bit.ly/peeko3"];
                    break;
                case 3:
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id781198595"]];
                    break;
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

- (IBAction)FacebookButtonPressed:(id)sender {
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    [FBAppEvents logEvent:[NSString stringWithFormat:@"%@ Shared on Facebook", [store objectForKey:@"index"]]];
    NSMutableString *icon = [[NSMutableString alloc] initWithString:[store objectForKey:@"icon"]];
    [icon insertString:baseURL atIndex:0];
   
    NSMutableString *promoName;
    
    NSDictionary *promotions = [_ArrayOfPromotions objectForKey:currentPromotionIndex];
    for(NSDictionary __strong *promo in promotions){
        promoName = [[NSMutableString alloc] initWithString:[promo objectForKey:@"name"]];
    }
    id<FBGraphObject> promoObject = [FBGraphObject openGraphObjectForPostWithType:@"peekoapp:promotion"
                                            title:[store objectForKey:@"name"]
                                            image:icon
                                              url:@"http://peekoapp.com/"
                                      description:promoName];
    
    id<FBOpenGraphAction> promoAction = (id<FBOpenGraphAction>)[FBGraphObject graphObject];
    [promoAction setObject:promoObject forKey:@"promotion"];
    
    [FBDialogs presentShareDialogWithOpenGraphAction:promoAction
                                          actionType:@"peekoapp:share"
                                 previewPropertyName:@"promotion"
                                             handler:^(FBAppCall *call, NSDictionary *results, NSError *error) {
                                                 if(error) {
                                                     NSLog(@"Error: %@", error.description);
                                                 } else {
                                                     NSLog(@"Success!");
                                                 }
                                             }];
}

- (IBAction)PinterestButtonPressed:(id)sender {
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    NSMutableString *icon = [[NSMutableString alloc] initWithString:[store objectForKey:@"icon"]];
    [icon insertString:baseURL atIndex:0];
    
    NSMutableString *promoName;
    
    NSDictionary *promotions = [_ArrayOfPromotions objectForKey:currentPromotionIndex];
    for(NSDictionary __strong *promo in promotions){
        promoName = [[NSMutableString alloc] initWithString:[promo objectForKey:@"name"]];
    }
    
    [_pinterest createPinWithImageURL:[NSURL URLWithString:icon]
                            sourceURL:[NSURL URLWithString:baseURL]
                          description:promoName];
}

-(void)CallButtonPressed:(id)sender{
    NSMutableString *phone;
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    phone = [[NSMutableString alloc] initWithString:[store objectForKey:@"phone"]];
    
    [FBAppEvents logEvent:[store objectForKey:@"phone"]];
    
    //Make 718-444-4444 -> telprompt:718-444-4444 to open in Phone app
    [phone insertString:@"telprompt:" atIndex:0];
    
    NSLog(@"%@", phone);
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:phone]];
}

-(void)MenuButtonPressed:(id)sender{
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    NSString *urlAddress = [[NSMutableString alloc] initWithString:[store objectForKey:@"menu"]];
    
    NSURLRequest *url = [NSURLRequest requestWithURL:[NSURL URLWithString:urlAddress relativeToURL:[NSURL URLWithString:baseURL]]];
    
    [webView removeFromSuperview];
    webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 62, 320, 506)];
    detailView.hidden = true;
    
    [webView loadRequest:url];
    webView.scalesPageToFit = YES;
    
    [self toggleNavigationButtons];
    
    [self.view addSubview:webView];
    
    
}
-(void)DetailSwiped:(UISwipeGestureRecognizer *)recognizer{
    [self minimizeDetail];
}

-(void)minimizeDetail{
    FlagForFirstTimeOpen = false; //Reset that the banner has been closed and we want PanGesture to work properly again
    [UIScrollView animateWithDuration: 0.5 animations: ^{
        self.NavigationTitle.topItem.title = @"Peeko";
        detailView.frame = CGRectMake(0, self.view.frame.size.height-100, 320, 100);
        [detailView setContentSize:CGSizeMake(detailView.contentSize.width,detailView.frame.size.height)];
        //[bannerButton removeFromSuperview];
        //[self GenerateFullPromoView];
        
    }];
    
    minimizedDetail = !minimizedDetail;
}

-(void)toggleNavigationButtons{
    //If webview was up, hide close button and show navigation
    if(webviewActive){
        NSLog(@"Show close");
        _CloseButton.image = [UIImage imageNamed:@"close"];
        _CloseButton.style = UIBarButtonItemStyleBordered;
        //_CloseButton.enabled = true;
        CloseButtonIsInfo = false;
        
        _NavButton.image = nil;
        _NavButton.style = UIBarButtonItemStylePlain;
        _NavButton.enabled = false;
        _NavButton.title = @"";
    }else{
        NSLog(@"Hide close");
        _NavButton.image = [UIImage imageNamed:@"locateme"];
        _NavButton.style = UIBarButtonItemStylePlain;
        _NavButton.enabled = true;
        
        //Repurpose the close button to ask for feedback
        _CloseButton.image = [UIImage imageNamed:@"info"];
        CloseButtonIsInfo = true;
        //_CloseButton.style = UIBarButtonItemStylePlain;
        //_CloseButton.enabled = false;
        _CloseButton.title = @"";
    }
    webviewActive = !webviewActive;
}

//Helper for menu options to suggest store / feedback
-(void)sendEmail:(NSString*)email withSubject:(NSString*)subject withBody:(NSString*)body{
    /*
     NSString *emailLine = [NSString stringWithFormat:@"mailto:%@", email];
    NSString *subjectLine = [NSString stringWithFormat:@"&subject=%@", subject];
    NSString *bodyLine = [NSString stringWithFormat:@"&body=%@", body];
    
    NSString *emailLink = [NSString stringWithFormat:@"%@%@%@", emailLine, subjectLine, bodyLine];
    NSLog(@"Email:%@", emailLink);
    emailLink = [emailLink stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:emailLink]];
     */
    
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        
        mailer.mailComposeDelegate = self;
        
        [mailer setSubject:subject];
        
        //Destination adress
        NSArray *toRecipients = [NSArray arrayWithObjects:email, nil];
        [mailer setToRecipients:toRecipients];
        
        /* Attachment Code - for reference later
        //Attachement Object
        UIImage *myImage = [UIImage imageNamed:@"image.jpeg"];
        NSData *imageData = UIImagePNGRepresentation(myImage);
        [mailer addAttachmentData:imageData mimeType:@"image/png" fileName:@"mobiletutsImage"];
        */
        
        //Message Body
        NSString *emailBody = body;
        [mailer setMessageBody:emailBody isHTML:NO];
        
        [self presentViewController:mailer animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failure"
                                                        message:@"Your device doesn't support the composer sheet"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        [alert show];
    }
}

-(void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled: you cancelled the operation and no email message was queued.");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved: you saved the email message in the drafts folder.");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail send: the email message is queued in the outbox. It is ready to send.");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail failed: the email message was not saved or queued, possibly due to an error.");
            break;
        default:
            NSLog(@"Mail not sent.");
            break;
    }
    
    // Remove the mail view
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(NSData*)imageFromUrl:(NSString*)iconURL{
    NSURL *baseURLTemp = [NSURL URLWithString:baseURL];

    iconURL = [iconURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    iconURL = [iconURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *imageURL = [NSURL URLWithString:iconURL relativeToURL:baseURLTemp];
    //NSLog(@"URL %@", imageURL);
    //Now generate the actual image
    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
    return imageData;
}


-(UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
