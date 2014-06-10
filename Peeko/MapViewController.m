//
//  MapViewController.m
//  Peeko
//
//  Created by Shahruk Khan on 4/25/14.
//  Copyright (c) 2014 Shahruk Khan and Minling Zhao. All rights reserved.
//

#import "MapViewController.h"
#import "QuartzCore/CALayer.h"

@interface MapViewController () <CLLocationManagerDelegate>

@end

@implementation MapViewController

//Global variables
RMMapView *mapView;
float MyLastLatitude = 0;
float MyLastLongitude = 0;

bool minimizedDetail = false;
bool webviewActive = false;

//NSString *baseURL = @"http://peekoapp.com/";
//NSString *baseURL = @"http://peeko.dev/";
NSString *baseURL = @"http://peeko.dev.192.168.1.16.xip.io/";

NSMutableArray *photos;
UIView *detailView;
bool alertedBefore = false;

UIButton *bannerButton;
NSNumber *currentPromotionIndex;
UIWebView *webView;

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
    _ArrayOfImages = [[NSMutableDictionary alloc] init];
    _ArrayOfPromotions = [[NSMutableDictionary alloc] init];
    _ArrayOfStores = [[NSMutableDictionary alloc] init];
    bannerButton = [[UIButton alloc] init];
    _pinterest = [[Pinterest alloc] initWithClientId:@"1234" urlSchemeSuffix:@"prod"];
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
}

-(void)GetStoreMarkers:(float)latitude withLongitude:(float)longitude{
    NSLog(@"GET");
    NSString *appendingString = [NSString stringWithFormat:@"api/stores/%.4f/%.4f/", latitude, longitude];
    NSString *ApiURL = [baseURL stringByAppendingString:appendingString];

    NSURL *url = [NSURL URLWithString:ApiURL];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;

    id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if(!response){
        //NSLog(@"ERROR");
    }else{
        //NSLog(@"GOOD!");
        [self GenerateMarkersForStoresOnMap:response];
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
    NSString *iconURL = [_ArrayOfImages objectForKey:index];
    NSData *imageData = [self imageFromUrl:iconURL];
    RMMarker *marker;
    marker = [[RMMarker alloc] initWithUIImage:[UIImage imageWithData:imageData scale: 2] anchorPoint:CGPointMake(0.5, 1)];
    marker.canShowCallout = true;
    
    
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
        
        detailView = [[UIView alloc] init];
        detailView.frame = CGRectMake(0, 470, 320, 100);
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
        
        UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget: self action:@selector(BannerSwipedUp:)];
        [gestureRecognizer setDirection: (UISwipeGestureRecognizerDirectionUp)];
        [bannerButton addGestureRecognizer:gestureRecognizer];
        
        [bannerButton setBackgroundImage:banner forState:UIControlStateNormal];
        [bannerButton addTarget:self action:@selector(BannerPressed:) forControlEvents:UIControlEventTouchUpInside];
        [detailView addSubview: bannerButton];
        
        
    }
}

-(void)BannerSwipedUp:(UISwipeGestureRecognizer *)recognizer{
    [self BannerPressed:nil];
}

-(void)BannerPressed:(id)sender{
    if(!minimizedDetail){
        [UIView animateWithDuration: 0.5 animations: ^{
            detailView.frame = CGRectMake(0, 62, 320, 568);
            //[bannerButton removeFromSuperview];
            [self GenerateFullPromoView];

        }];
        minimizedDetail = !minimizedDetail;
    }else{
        [self minimizeDetail];
    }
    
        //[self.view addSubview:detailView];
    /*
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MapDetailViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"MapDetailViewController"];
    [self presentViewController:viewController animated:YES completion: NULL];
     */
}

-(void)GenerateFullPromoView{
    UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget: self action:@selector(DetailSwiped:)];
    [gestureRecognizer setDirection: (UISwipeGestureRecognizerDirectionDown)];
    [detailView addGestureRecognizer:gestureRecognizer];
    
    UILabel *addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 115, 300, 20)];
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    addressLabel.text = [[NSMutableString alloc] initWithString:[store objectForKey:@"address"]];
    [detailView addSubview:addressLabel];
    
    UIImage *callBackground = [UIImage imageNamed:@"button-call"];
    UIButton *callButton = [[UIButton alloc] init];
    [callButton setImage:callBackground forState:UIControlStateNormal];
    [callButton setFrame: CGRectMake(10, 140, 140, 170)];
    [callButton addTarget: self action:@selector(CallButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:callButton];
    
    UIImage *menuBackground = [UIImage imageNamed:@"button-menu"];
    UIButton *menuButton = [[UIButton alloc] init];
    [menuButton setImage:menuBackground forState:UIControlStateNormal];
    [menuButton setFrame: CGRectMake(170, 140, 140, 170)];
    [menuButton addTarget: self action:@selector(MenuButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:menuButton];
    
    UIImage *fbBackground = [UIImage imageNamed:@"button-facebook"];
    UIButton *fbButton = [[UIButton alloc] init];
    [fbButton setImage:fbBackground forState:UIControlStateNormal];
    [fbButton setFrame: CGRectMake(10, 320, 300, 80)];
    [fbButton addTarget: self action:@selector(FacebookButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:fbButton];
    
    UIImage *pinterestBackground = [UIImage imageNamed:@"button-pinterest"];
    UIButton *pinterestButton = [[UIButton alloc] init];
    [pinterestButton setImage:pinterestBackground forState:UIControlStateNormal];
    [pinterestButton setFrame: CGRectMake(10, 410, 300, 80)];
    [pinterestButton addTarget: self action:@selector(PinterestButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [detailView addSubview:pinterestButton];

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

}

- (IBAction)CloseButtonPressed:(id)sender {
    [self toggleNavigationButtons];
    
    [webView removeFromSuperview];
    detailView.hidden = NO;
}

- (IBAction)FacebookButtonPressed:(id)sender {
    
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
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
    
    [_pinterest createPinWithImageURL:@"http://placekitten.com/500/400"
                            sourceURL:@"http://placekitten.com"
                          description:@"Pinning from Pin It Demo"];
}

-(void)CallButtonPressed:(id)sender{
    NSMutableString *phone;
    NSDictionary *store = [_ArrayOfStores objectForKey:currentPromotionIndex];
    phone = [[NSMutableString alloc] initWithString:[store objectForKey:@"phone"]];
    
    //Make 718-444-4444 -> tel:718-444-4444 to open in Phone appv
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
    [UIView animateWithDuration: 0.5 animations: ^{
        detailView.frame = CGRectMake(0, 470, 320, 100);
        //[bannerButton removeFromSuperview];
        [self GenerateFullPromoView];
        
    }];
    
    minimizedDetail = !minimizedDetail;
}

-(void)toggleNavigationButtons{
    //If webview is up, hide close button and show navigation
    if(webviewActive){
        NSLog(@"Show close");
        _CloseButton.image = [UIImage imageNamed:@"close"];
        _CloseButton.style = UIBarButtonItemStyleBordered;
        _CloseButton.enabled = true;
        
        _NavButton.image = nil;
        _NavButton.style = UIBarButtonItemStylePlain;
        _NavButton.enabled = false;
        _NavButton.title = @"";
    }else{
        NSLog(@"Hide close");
        _NavButton.image = [UIImage imageNamed:@"locateme"];
        _NavButton.style = UIBarButtonItemStylePlain;
        _NavButton.enabled = true;
        
        _CloseButton.image = nil;
        _CloseButton.style = UIBarButtonItemStylePlain;
        _CloseButton.enabled = false;
        _CloseButton.title = @"";
    }
    webviewActive = !webviewActive;
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
