//
//  MapViewController.h
//  Peeko
//
//  Created by Shahruk Khan on 4/25/14.
//  Copyright (c) 2014 Shahruk Khan and Minling Zhao. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <Mapbox/Mapbox.h>
#import <FacebookSDK/FacebookSDK.h>
#import <Pinterest/Pinterest.h>

@interface MapViewController : UIViewController <RMMapViewDelegate> //, MWPhotoBrowserDelegate>
@property (strong, nonatomic) IBOutlet UIBarButtonItem *NavButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *CloseButton;


@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSMutableDictionary *ArrayOfImages;
@property (nonatomic, strong) NSMutableDictionary *ArrayOfPromotions;
@property (nonatomic, strong) NSMutableDictionary *ArrayOfStores;
@property (strong, nonatomic) IBOutlet UIView *MapContainer;
@property (strong, nonatomic) IBOutlet UIView *MapHelperView;
//@property (strong, nonatomic) IBOutlet UIBarButtonItem *NavLocateButton;

-(void)GetLocation;
-(void)GetStoreMarkers:(float)latitude withLongitude:(float)longitude;
-(void)GenerateMarkersForStoresOnMap:(id)response;
-(BOOL)checkWithLastLocation:(float)latitude withLongitude:(float)longitude;
-(IBAction)NavLocateButtonPressed:(id)sender;
-(NSData*)imageFromUrl:(NSString*)iconURL;
-(void)GenerateFullPromoView;
- (IBAction)CloseButtonPressed:(id)sender;
- (IBAction)FacebookButtonPressed:(id)sender;
- (IBAction)PinterestButtonPressed:(id)sender;

-(void)toggleNavigationButtons;
-(UIColor *)colorFromHexString:(NSString *)hexString;

extern float MyLastLatitude;
extern float MyLastLongitude;
@end
