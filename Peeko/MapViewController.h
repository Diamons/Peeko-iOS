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

@interface MapViewController : UIViewController <RMMapViewDelegate>


@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSMutableDictionary *ArrayOfImages;
@property (nonatomic, strong) NSMutableArray *ArrayOfAnnotations;
@property (strong, nonatomic) IBOutlet UIView *MapContainer;
@property (strong, nonatomic) IBOutlet UIView *MapHelperView;

-(void)GetLocation;
-(void)GetStoreMarkers:(float)latitude withLongitude:(float)longitude;
-(void)GenerateMarkersForStoresOnMap:(id)response;
-(BOOL)checkWithLastLocation:(float)latitude withLongitude:(float)longitude;

extern float MyLastLatitude;
extern float MyLastLongitude;
@end
