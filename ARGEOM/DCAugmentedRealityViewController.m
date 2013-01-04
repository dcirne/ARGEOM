//
//  DCAugmentedRealityViewController.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/9/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

#import "DCAugmentedRealityViewController.h"
#import <MapKit/MapKit.h>
#import <CoreMotion/CoreMotion.h>
#import "DCPlacemark.h"
#import <CoreLocation/CoreLocation.h>

#define ACCELERATION_FILTER 0.2
#define Z_ACCELERATION_THRESHOLD 0.7
#define AR_MAP_PERCENTAGE_SCREEN 0.4
#define AR_MAP_INSET 10.0
#define ONE_MILE_IN_METERS 1609.3440006146
#define ONE_METER_IN_MILES 0.000621371192237334

typedef void(^PlacemarksCalculationComplete)(NSArray *visiblePlacemarks);

@interface UIImagePickerController(Landscape)
- (NSUInteger)supportedInterfaceOrientations;
@end

@implementation UIImagePickerController(Landscape)
- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}
@end

@interface DCAugmentedRealityViewController() <MKMapViewDelegate> {
    IBOutlet MKMapView *stdMapView;
    IBOutlet UISlider *distanceSlider;
    IBOutlet UILabel *distanceLabel;
    
    NSOperationQueue *motionQueue;
    UIAccelerationValue zAcceleration;
    double phi, alpha, psi, theta;
    double radius;
    CGPoint pointA, pointB, pointC, pointP;
    dispatch_queue_t placemarksQueue;
    NSMutableArray *annotations;
    BOOL initialized;
    CLLocationDistance distance;
    UIInterfaceOrientation previousInterfaceOrientation;
}

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) MKMapView *arMapView;
@property (nonatomic, readonly, getter = imagePickerController) UIImagePickerController *imagePickerController;
@property (nonatomic, strong) NSArray *placemarks;

@end


@implementation DCAugmentedRealityViewController

@synthesize visualizationMode = _visualizationMode;
@synthesize imagePickerController = _imagePickerController;

- (void)awakeFromNib {
    _visualizationMode = VisualizationModeUnknown;
    zAcceleration = FLT_MAX;
    phi = M_PI / 3.0;
    radius = 50.0 * ONE_MILE_IN_METERS;
    annotations = nil;
    initialized = NO;

    motionQueue = [[NSOperationQueue alloc] init];
    
    placemarksQueue = dispatch_queue_create("com.dalmocirne.placemarksQueue", DISPATCH_QUEUE_SERIAL);

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(handleApplicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(handleApplicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
}

- (void)dealloc {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:UIApplicationDidEnterBackgroundNotification
                                object:nil];
    
    [notificationCenter removeObserver:self
                                  name:UIApplicationWillEnterForegroundNotification
                                object:nil];
}

#pragma mark Accessors
- (VisualizationMode)visualizationMode {
    return _visualizationMode;
}

- (CMMotionManager *)motionManager {
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    
    return _motionManager;
}

- (MKMapView *)arMapView {
    if (_arMapView) {
        return _arMapView;
    }
    
    _arMapView = [[MKMapView alloc] initWithFrame:CGRectMake(1, 1, 700, 700)];
    _arMapView.delegate = self;
    _arMapView.alpha = 0.6;
    
    return _arMapView;
}

- (UIImagePickerController *)imagePickerController {
    if (_imagePickerController) {
        return _imagePickerController;
    }
    
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        return nil;
    }
    
    _imagePickerController = [[UIImagePickerController alloc] init];
    _imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    _imagePickerController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    _imagePickerController.showsCameraControls = NO;
    _imagePickerController.wantsFullScreenLayout = YES;
    _imagePickerController.navigationBarHidden = YES;
    _imagePickerController.toolbarHidden = YES;
    
    UIView *overlayView = [[UIView alloc] initWithFrame:CGRectZero];
    overlayView.backgroundColor = [UIColor clearColor];
    overlayView.clipsToBounds = NO;
    [overlayView addSubview:self.arMapView];
    _imagePickerController.cameraOverlayView = overlayView;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        CGFloat transformScaleX = [UIScreen mainScreen].scale;
        CGFloat transformScaleY = [UIScreen mainScreen].scale - 0.2;
        
        CGAffineTransform scaleTransform = CGAffineTransformMakeScale(transformScaleX, transformScaleY);
        double rotationAngle = self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft ? M_PI_2 : -M_PI_4;
        CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(rotationAngle);
        
        _imagePickerController.cameraViewTransform = CGAffineTransformConcat(rotationTransform, scaleTransform);
    }
    
    return _imagePickerController;
}

- (NSArray *)placemarks {
    if (_placemarks) {
        return _placemarks;
    }
    
    NSMutableArray *placemarks = [[NSMutableArray alloc] initWithCapacity:5];
    
    DCPlacemark *placemark;
    
    // Placemark 1
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"New York City";
    placemark.subtitle = @"The Big Apple";
    placemark.coordinate = CLLocationCoordinate2DMake(40.7833, -73.9667);
    [placemarks addObject:placemark];
    
    // Placemark 2
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"White Plains";
    placemark.subtitle = @"Large City in Westchester County";
    placemark.coordinate = CLLocationCoordinate2DMake(41.0667, -73.7);
    [placemarks addObject:placemark];
    
    // Placemark 3
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"Albany";
    placemark.subtitle = @"State Capital";
    placemark.coordinate = CLLocationCoordinate2DMake(42.75, -73.8);
    [placemarks addObject:placemark];
    
    // Placemark 4
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"Point 4";
    placemark.subtitle = @"";
    placemark.coordinate = CLLocationCoordinate2DMake(44, -72);
    [placemarks addObject:placemark];
    
    // Placemark 5
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"Point 5";
    placemark.subtitle = @"";
    placemark.coordinate = CLLocationCoordinate2DMake(42, -74.5);
    [placemarks addObject:placemark];
    
    _placemarks = [placemarks copy];
    return _placemarks;
}

#pragma mark Private methods
- (void)layoutScreen {
    switch (_visualizationMode) {
        case VisualizationModeAugmentedReality: {
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleDeviceDidRotate:)
                                                         name:UIDeviceOrientationDidChangeNotification
                                                       object:nil];
            
            CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
            CGRect arFrame = [[UIScreen mainScreen] applicationFrame];
            arFrame.origin = CGPointZero;
            
            arFrame.size.width += statusBarFrame.size.width;
            
            CGRect arMapFrame;
            arMapFrame.size = CGSizeMake(arFrame.size.height * AR_MAP_PERCENTAGE_SCREEN,
                                         arFrame.size.width * AR_MAP_PERCENTAGE_SCREEN);
            
            arMapFrame.origin = CGPointMake(arFrame.size.height - arMapFrame.size.width - AR_MAP_INSET,
                                            arFrame.size.width - arMapFrame.size.height - AR_MAP_INSET);
            
            [UIView animateWithDuration:[UIApplication sharedApplication].statusBarOrientationAnimationDuration
                             animations:^{
                                 self.arMapView.frame = arMapFrame;
                             }
                             completion:^(BOOL finished){
                                 if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                                     CGFloat transformScaleX = [UIScreen mainScreen].scale;
                                     CGFloat transformScaleY = [UIScreen mainScreen].scale - 0.2;
                                     
                                     CGAffineTransform scaleTransform = CGAffineTransformMakeScale(transformScaleX, transformScaleY);
                                     double rotationAngle = self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft ? M_PI_2 : -M_PI_2;
                                     CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(rotationAngle);
                                     
                                     _imagePickerController.cameraViewTransform = CGAffineTransformConcat(rotationTransform, scaleTransform);
                                 }
                             }];
        }
            break;
            
        case VisualizationModeMap:
            [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
            break;
            
        default:
            break;
    }
}

- (void)calculateVisiblePlacemarksWithUserLocation:(MKUserLocation *const)userLocation completionBlock:(PlacemarksCalculationComplete)completionBlock {
    dispatch_async(placemarksQueue, ^{
        alpha = userLocation.heading.trueHeading;
        psi = M_PI / 2.0 - alpha;
        
        pointA = CGPointMake(userLocation.location.coordinate.longitude,
                             userLocation.location.coordinate.latitude);
        
        pointB = CGPointMake(radius * cos(psi + phi / 2.0) + pointA.x,
                             radius * sin(psi + phi / 2.0) + pointA.y);
        
        pointC = CGPointMake(radius * cos(psi - phi / 2.0) + pointA.x,
                             radius * sin(psi - phi / 2.0) + pointA.y);
        
        completionBlock(nil);
    });
}

- (void)overlayAugmentedRealityAnnotations {
    
}

- (void)addAnnotationsToMap {
    if (annotations) {
        [self removeAnnotationsFromMap];
    }
    
    NSInteger numberOfPlacemarks = self.placemarks.count;
    annotations = [[NSMutableArray alloc] initWithCapacity:numberOfPlacemarks];
    
    [self.placemarks enumerateObjectsUsingBlock:^(id<MKAnnotation> annotation, NSUInteger idx, BOOL *stop) {
        [annotations addObject:annotation];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [stdMapView addAnnotations:annotations];
    });
}

- (void)removeAnnotationsFromMap {
    dispatch_async(dispatch_get_main_queue(), ^{
        [stdMapView removeAnnotation:[annotations copy]];
        annotations = nil;
    });
}

- (void)startMonitoringDeviceMotion {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        self.motionManager.accelerometerUpdateInterval = 0.25f;
        [self.motionManager startAccelerometerUpdatesToQueue:motionQueue
                                                 withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                                     [self handleDeviceAcceleration:accelerometerData error:error];
                                                 }];
    }
}

- (void)stopMonitoringDeviceMotion {
    if (_motionManager && _motionManager.accelerometerActive) {
        [_motionManager stopAccelerometerUpdates];
    }
}

- (void)initialize {
    stdMapView.showsUserLocation = YES;
    [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];

    _visualizationMode = VisualizationModeMap;
    [self distanceSliderValueChanged:distanceSlider];
    initialized = YES;
}

- (void)updateMapVisibleRegion {
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(stdMapView.userLocation.location.coordinate, distance, distance);
    [stdMapView setRegion:[stdMapView regionThatFits:region]
                 animated:YES];
}

- (IBAction)distanceSliderValueChanged:(UISlider *)sender {
    float miles = 100 * sender.value;
    distance = miles * ONE_MILE_IN_METERS;
    
    NSString *milesText = miles > 1.0 ? @"miles" : @"mile";
    
    distanceLabel.text = [NSString stringWithFormat:@"%.1f %@", miles, milesText];
    [self updateMapVisibleRegion];
}

#pragma mark Public methods
- (void)start {
    if (!initialized) {
        [self initialize];
    }
    
    if (!annotations) {
        [self addAnnotationsToMap];
    }
    
    [self startMonitoringDeviceMotion];
}

- (void)stop {
    [self stopMonitoringDeviceMotion];
    [self setMotionManager:nil];
}

#pragma mark Notification handlers
- (void)handleApplicationDidEnterBackground:(NSNotification *)notification {
    [self stop];
}

- (void)handleApplicationWillEnterForeground:(NSNotification *)notification {
    [self start];
}

- (void)handleDeviceAcceleration:(CMAccelerometerData *)accelerometerData error:(NSError *)error {
    VisualizationMode previousVisualizationMode = _visualizationMode;
    zAcceleration = (zAcceleration != FLT_MAX) ? (accelerometerData.acceleration.z * ACCELERATION_FILTER) + (zAcceleration * (1.0 - ACCELERATION_FILTER)) : accelerometerData.acceleration.z;
    _visualizationMode = (zAcceleration > -Z_ACCELERATION_THRESHOLD) && (zAcceleration < Z_ACCELERATION_THRESHOLD) ? VisualizationModeAugmentedReality : VisualizationModeMap;
    
    if (_visualizationMode == previousVisualizationMode) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (_visualizationMode) {
            case VisualizationModeAugmentedReality: {
                stdMapView.showsUserLocation = NO;
                [stdMapView setUserTrackingMode:MKUserTrackingModeNone animated:NO];

                [self.delegate presentAugmentedRealityController:self.imagePickerController
                                                      completion:^{
                                                          self.arMapView.showsUserLocation = YES;
                                                          [self.arMapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
                                                          [self layoutScreen];
                                                      }];
            }
                break;
                
            case VisualizationModeMap: {
                [self setArMapView:nil];
                stdMapView.showsUserLocation = YES;
                [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
                
                if (previousVisualizationMode == VisualizationModeAugmentedReality) {
                    [self.delegate dismissAugmentedRealityControllerWithCompletionBlock:^{
                        [self layoutScreen];
                        [self updateMapVisibleRegion];
                    }];
                } else {
                    [self layoutScreen];
                }
            }
                break;
                
            default:
                stdMapView.showsUserLocation = YES;
                [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
                
                if (previousVisualizationMode == VisualizationModeAugmentedReality) {
                    [self.delegate dismissAugmentedRealityControllerWithCompletionBlock:^{
                        [self layoutScreen];
                    }];
                }
                break;
        }
    });
}

- (void)handleDeviceDidRotate:(NSNotification *)notification {
    [self layoutScreen];
}

#pragma mark MKMapViewDelegate
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
//    if (mapView == self.mapView) {
//        return [self.kmlParser mapView:mapView viewForAnnotation:annotation];
//    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (mapView == _arMapView) {
        if (_arMapView.userTrackingMode != MKUserTrackingModeFollowWithHeading) {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^{
                if ([CLLocationManager headingAvailable]) {
                    [self.arMapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
                } else {
                    [self.arMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
                }
            });
            
            return;
        }
        
        if (![CLLocationManager headingAvailable]) {
            return;
        }
        
        [self calculateVisiblePlacemarksWithUserLocation:userLocation completionBlock:^(NSArray *visiblePlacemarks) {
            if (visiblePlacemarks) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self overlayAugmentedRealityAnnotations];
                });
            }
        }];
    } else if (mapView == stdMapView) {
        [self updateMapVisibleRegion];
    }
}

@end
