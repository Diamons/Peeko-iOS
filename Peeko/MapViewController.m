//
//  MapViewController.m
//  Peeko
//
//  Created by Shahruk Khan on 4/25/14.
//  Copyright (c) 2014 Shahruk Khan and Minling Zhao. All rights reserved.
//

#import "MapViewController.h"
#import "QuartzCore/CALayer.h"
#import "MapDetailViewController.h"

@interface MapViewController () <CLLocationManagerDelegate>

@end

@implementation MapViewController

RMMapView *mapView;
float MyLastLatitude = 0;
float MyLastLongitude = 0;
NSString *baseURL = @"http://peeko.dev.192.168.1.16.xip.io/";


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _ArrayOfImages = [[NSMutableDictionary alloc] init];
    _ArrayOfPromotions = [[NSMutableDictionary alloc] init];
    
    // Do any additional setup after loading the view.
    
    RMMapboxSource *interactiveSource = [[RMMapboxSource alloc] initWithMapID:@"diamons.i2cfcc2m"];
    mapView = [[RMMapView alloc] initWithFrame:_MapContainer.bounds andTilesource:interactiveSource];
    
    mapView.delegate = self;
    mapView.showsUserLocation = true;
    mapView.zoom = 16;
    
    //mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    //mapView.adjustTilesForRetinaDisplay = YES; // these tiles aren't designed specifically for retina, so make them legible
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
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_locationManager startUpdatingLocation];
    
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error getting your location." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    
    [errorAlert show];
}

-(void)locationManager: (CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
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
    for(NSDictionary *store in response){
        float latitude = [[store objectForKey:@"latitude"] doubleValue];
        float longitude = [[store objectForKey:@"longitude"] doubleValue];
        NSString *icon = [store objectForKey:@"icon"];
        NSDictionary *promotions = [store objectForKey:@"promotions"];
        NSString *name = [store objectForKey:@"name"];

        NSNumber *index = [NSNumber numberWithInt:[[store objectForKey:@"id"] intValue]];
        
        [_ArrayOfImages setObject:icon forKey:index];
        [_ArrayOfPromotions setObject:promotions forKey:index];
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
    marker = [[RMMarker alloc] initWithUIImage:[UIImage imageWithData:imageData]];
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

}

- (void)tapOnAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map{
    NSNumber *index = [NSNumber numberWithInt:[annotation.userInfo intValue]];
    NSDictionary *promotions = [_ArrayOfPromotions objectForKey:index];
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
        
        /* Button implementation
        UIImage *banner = [UIImage imageWithData:[self imageFromUrl:[promo objectForKey:@"image"]]];
        UIButton *bannerButton = [[UIButton alloc] init];
        bannerButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        bannerButton.frame = CGRectMake(0, 470, 320, 90);
        bannerButton.layer.shadowColor = [UIColor grayColor].CGColor;
        bannerButton.layer.shadowOffset = CGSizeMake(0, 1);
        bannerButton.layer.shadowOpacity = 1;
        [bannerButton setBackgroundImage:banner forState:UIControlStateNormal];
        
        [bannerButton addTarget:self action:@selector(BannerPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview: bannerButton];
         */
        
        
    }
}

-(void)BannerPressed{
    /*
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MapDetailViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"MapDetailViewController"];
    [self presentViewController:viewController animated:YES completion: NULL];
     */
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
