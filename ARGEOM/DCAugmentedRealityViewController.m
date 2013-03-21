//
//  DCAugmentedRealityViewController.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/9/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

/*
 Copyright (c) 2013, Dalmo Cirne
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3- Neither the name of Dalmo Cirne nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DCAugmentedRealityViewController.h"
#import <MapKit/MapKit.h>
#import <CoreMotion/CoreMotion.h>
#import "DCPlacemark.h"
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import "DCAugmentedRealityAnnotationViewController.h"

#define ACCELERATION_FILTER 0.2
#define Z_ACCELERATION_THRESHOLD 0.7
#define AR_MAP_PERCENTAGE_SCREEN 0.4
#define AR_MAP_HORIZONTAL_INSET 10.0
#define AR_MAP_VERTICAL_INSET 30.0
#define ONE_MILE_IN_METERS 1609.3440006146
#define HALF_MILE_IN_METERS 804.6720003073
#define ONE_METER_IN_MILES 0.000621371192237334
#define NUMBER_DIMENSIONS 2
#define EARTH_RADIUS 3956.547
#define MAXIMUM_DISTANCE 500.0

typedef void(^PlacemarksCalculationComplete)(NSArray *visiblePlacemarks, NSArray *nonVisiblePlacemarks);

static CGSize defaultAugmentedRealityAnnotationSize;
static double piOver180;

@interface DCAugmentedRealityViewController() <MKMapViewDelegate, CLLocationManagerDelegate> {
    IBOutlet MKMapView *stdMapView;
    IBOutlet UISlider *distanceSlider;
    IBOutlet UILabel *distanceLabel;
    IBOutlet UIView *previewView;
    
    NSOperationQueue *motionQueue;
    dispatch_queue_t placemarksQueue;
    UIAccelerationValue zAcceleration;
    double radius;
    double milesPerDegreeOfLatitude;
    double milesPerDegreeOfLongigute;
    NSMutableArray *annotations;
    NSMutableArray *augmentedRealityAnnotations;
    CLLocationDistance distance;
    CGFloat maxHeight;
    CGFloat maxY;
    CGFloat minY;
}

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) CLLocationManager *locationManager;

@end


@implementation DCAugmentedRealityViewController

@synthesize visualizationMode = _visualizationMode;

+ (void)initialize {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        defaultAugmentedRealityAnnotationSize = CGSizeMake(400.0f, 80.0f);
    } else {
        defaultAugmentedRealityAnnotationSize = CGSizeMake(200.0f, 40.0f);
    }
    
    piOver180  = M_PI / 180.0;
}

- (void)awakeFromNib {
    _visualizationMode = VisualizationModeUnknown;
    zAcceleration = FLT_MAX;
    radius = 150.0; // miles
    annotations = nil;
    augmentedRealityAnnotations = nil;
    milesPerDegreeOfLatitude = 2 * M_PI * EARTH_RADIUS / 360.0;
    milesPerDegreeOfLongigute = milesPerDegreeOfLatitude; // Initialization value only

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

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self layoutScreen];
    
    if ((_visualizationMode == VisualizationModeAugmentedReality) && _videoPreviewLayer) {
        [UIView animateWithDuration:duration
                         animations:^{
                             _videoPreviewLayer.frame = previewView.bounds;
                         } completion:^(BOOL finished) {
                             if (finished) {
                                 [_videoPreviewLayer.connection setVideoOrientation:toInterfaceOrientation];
                             }
                         }];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (_visualizationMode == VisualizationModeAugmentedReality && _videoPreviewLayer) {
        [_videoPreviewLayer.connection setVideoOrientation:[UIDevice currentDevice].orientation];
        [self updateLocationManagerHeadingOrientation];
    }
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

- (AVCaptureSession *)captureSession {
    if (_captureSession) {
        return _captureSession;
    }
    
	_captureSession = [AVCaptureSession new];
	[_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    
	NSError *error = nil;
	AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
    
	if (error || ![_captureSession canAddInput:captureDeviceInput]) {
		return nil;
    }
    
    [_captureSession addInput:captureDeviceInput];

    return _captureSession;
}

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer {
    if (_videoPreviewLayer) {
        return _videoPreviewLayer;
    }

    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreviewLayer setFrame:previewView.bounds];
    [_videoPreviewLayer.connection setVideoOrientation:[UIDevice currentDevice].orientation];
    
    return _videoPreviewLayer;
}

- (CLLocationManager *)locationManager {
    if (_locationManager) {
        return _locationManager;
    }
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.headingFilter = kCLHeadingFilterNone;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    
    double delayInSeconds = [UIApplication sharedApplication].statusBarOrientationAnimationDuration + 0.1;;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self updateLocationManagerHeadingOrientation];
    });

    return _locationManager;
}

- (void)setPlacemarks:(NSArray *)placemarks {
    _placemarks = placemarks;
}

#pragma mark Private methods
- (void)layoutScreen {
    UIDevice *device = [UIDevice currentDevice];
    CGRect arFrame = self.view.bounds;
    CGRect mapFrame;
    CGFloat mapAlpha;
    
    switch (_visualizationMode) {
        case VisualizationModeAugmentedReality: {
            [device beginGeneratingDeviceOrientationNotifications];
            
            mapFrame.size = CGSizeMake(arFrame.size.width * AR_MAP_PERCENTAGE_SCREEN,
                                       arFrame.size.height * AR_MAP_PERCENTAGE_SCREEN);
            
            mapFrame.origin = CGPointMake(arFrame.size.width - mapFrame.size.width - AR_MAP_HORIZONTAL_INSET,
                                          arFrame.size.height - mapFrame.size.height - distanceSlider.frame.size.height - AR_MAP_VERTICAL_INSET);
            
            maxHeight = mapFrame.origin.y;
            minY = defaultAugmentedRealityAnnotationSize.height / 2.0;
            maxY = maxHeight - minY;
            
            mapAlpha = 0.6;
        }
            break;
            
        case VisualizationModeMap: {
            [device endGeneratingDeviceOrientationNotifications];
            
            mapFrame = arFrame;
            mapAlpha = 1.0;
        }
            break;
            
        default:
            return;
            break;
    }
    
    [UIView animateWithDuration:[UIApplication sharedApplication].statusBarOrientationAnimationDuration
                     animations:^{
                         stdMapView.frame = mapFrame;
                         stdMapView.alpha = mapAlpha;
                     }];
}

- (void)calculateVisiblePlacemarksWithUserLocation:(CLLocation *const)location heading:(CLHeading *const)heading completionBlock:(PlacemarksCalculationComplete)completionBlock {
    if (!location || !heading) {
        return;
    }
    
    dispatch_async(placemarksQueue, ^{
        double(^dotProduct)(double *, double *) = ^(double *vector1, double *vector2) {
            double dotProduct = 0;
            
            for (int i = 0; i < NUMBER_DIMENSIONS; ++i) {
                dotProduct += vector1[i] * vector2[i];
            }
            
            return dotProduct;
        };
        
        double(^norm)(double *) = ^(double *vector) {
            double norm = 0;
            
            for (int i = 0; i < NUMBER_DIMENSIONS; ++i) {
                norm += pow(vector[i], 2);
            }
            
            norm = sqrt(norm);
            
            return norm;
        };
        
        void(^makeVector)(double **, CGPoint, CGPoint) = ^(double **vector, CGPoint point1, CGPoint point2) {
            *vector = malloc(sizeof(double) * NUMBER_DIMENSIONS);
            
            double *vectorEntry = *vector;
            
            *vectorEntry = point2.x - point1.x;
            ++vectorEntry;
            *vectorEntry = point2.y - point1.y;
        };
        
        CLLocationDistance(^calculateDistanceBetweenPoints)(CGPoint, CGPoint) = ^(CGPoint point1, CGPoint point2) {
            CLLocation *point1Location = [[CLLocation alloc] initWithLatitude:point1.y longitude:point1.x];
            CLLocation *point2Location = [[CLLocation alloc] initWithLatitude:point2.y longitude:point2.x];
            CLLocationDistance distanceBetweenPoints = sqrt(pow([point1Location distanceFromLocation:point2Location], 2));
            
            return distanceBetweenPoints;
        };
        
        milesPerDegreeOfLongigute = milesPerDegreeOfLatitude * cos(location.coordinate.latitude * piOver180);
        
        CLLocationDirection trueHeading = heading.trueHeading;
        if (trueHeading < 0) {
            return;
        }
        
        double alpha = trueHeading * piOver180;
        double psi = M_PI / 2.0 - alpha;
        double phi = UIInterfaceOrientationIsLandscape([UIDevice currentDevice].orientation) ? M_PI / 3.0 : M_PI / 4.0;
        double longitudeRadiusInDegrees = radius / milesPerDegreeOfLongigute;
        double latitudeRadiusInDegrees = radius / milesPerDegreeOfLatitude;
        
        CGPoint pointA = CGPointMake(location.coordinate.longitude,
                                     location.coordinate.latitude);
        
        CGPoint pointB = CGPointMake(longitudeRadiusInDegrees * cos(psi + phi / 2.0) + pointA.x,
                                     latitudeRadiusInDegrees * sin(psi + phi / 2.0) + pointA.y);
        
        CGPoint pointC = CGPointMake(longitudeRadiusInDegrees * cos(psi - phi / 2.0) + pointA.x,
                                     latitudeRadiusInDegrees * sin(psi - phi / 2.0) + pointA.y);
        
        CGPoint pointM = CGPointMake(longitudeRadiusInDegrees * cos(psi) + pointA.x,
                                     latitudeRadiusInDegrees * sin(psi) + pointA.y);
        
        double vectorAB[NUMBER_DIMENSIONS] = {pointB.x - pointA.x, pointB.y - pointA.y};
        
        double vectorAC[NUMBER_DIMENSIONS] = {pointC.x - pointA.x, pointC.y - pointA.y};
        
        double vectorAM[NUMBER_DIMENSIONS] = {pointM.x - pointA.x, pointM.y - pointA.y};
        
        double vectorBC[NUMBER_DIMENSIONS] = {pointC.x - pointB.x, pointC.y - pointB.y};
        
        NSMutableArray *visiblePlacemarks = [[NSMutableArray alloc] initWithCapacity:1];
        NSMutableArray *nonVisiblePlacemarks = [[NSMutableArray alloc] initWithCapacity:1];
        
        double lambda, sigma, theta, dPrime, scale, thetaDirection;
        CGPoint pointP;
        double *vectorAP;
        CLLocationDistance distanceFromObserver;
        double l = previewView.bounds.size.width;
        double lOver2 = l / 2.0;
        for (DCPlacemark *placemark in self.placemarks) {
            pointP = CGPointMake(placemark.coordinate.longitude, placemark.coordinate.latitude);
            makeVector(&vectorAP, pointA, pointP);
            
            lambda = dotProduct(vectorAP, vectorAB) / pow(norm(vectorAB), 2);
            sigma = dotProduct(vectorAP, vectorAC) / pow(norm(vectorAC), 2);
            if ((lambda > 0) && (sigma > 0) && (pow(lambda, 2) + pow(sigma, 2) <= 1)) {
                thetaDirection = calculateDistanceBetweenPoints(pointB, pointP) <= calculateDistanceBetweenPoints(pointC, pointP) ? -1.0 : 1.0;
                theta = acos(dotProduct(vectorAM, vectorAP) / (norm(vectorAM) * norm(vectorAP))) * thetaDirection;
                dPrime = l * norm(vectorAP) * sin(theta) / norm(vectorBC);
                distanceFromObserver = [placemark calculateDistanceFromObserver:location.coordinate];
                scale = 1.0 - distanceFromObserver / distance;
                
                placemark.bounds = CGRectMake(0, 0, defaultAugmentedRealityAnnotationSize.width * scale, defaultAugmentedRealityAnnotationSize.height * scale);
                placemark.center = CGPointMake(lOver2 + dPrime, maxY * scale);
                
                [visiblePlacemarks addObject:placemark];
            } else {
                [nonVisiblePlacemarks addObject:placemark];
            }
            
            free(vectorAP);
        }
        
        if (visiblePlacemarks.count > 0) {
            [visiblePlacemarks sortUsingComparator:^NSComparisonResult(DCPlacemark *placemark1, DCPlacemark *placemark2) {
                if (placemark1.distanceFromObserver > placemark2.distanceFromObserver) {
                    return (NSComparisonResult)NSOrderedAscending;
                }
                
                if (placemark1.distanceFromObserver < placemark2.distanceFromObserver) {
                    return (NSComparisonResult)NSOrderedDescending;
                }
                
                return (NSComparisonResult)NSOrderedSame;
            }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock([visiblePlacemarks copy], [nonVisiblePlacemarks copy]);
        });
    });
}

- (void)overlayAugmentedRealityPlacemarks:(NSArray *const)visiblePlacemarks nonVisiblePlacemarks:(NSArray *const)nonVisiblePlacemarks {
    DCPlacemark *placemark;
    NSString *predicateFormat = @"placemark == %@";
    NSPredicate *predicate;
    DCAugmentedRealityAnnotationViewController *augmentedRealityAnnotationController;
    
    if (!augmentedRealityAnnotations) {
        augmentedRealityAnnotations = [[NSMutableArray alloc] initWithCapacity:1];
    }
    
    for (placemark in nonVisiblePlacemarks) {
        predicate = [NSPredicate predicateWithFormat:predicateFormat, placemark];
        augmentedRealityAnnotationController = [[augmentedRealityAnnotations filteredArrayUsingPredicate:predicate] lastObject];
        
        if (augmentedRealityAnnotationController) {
            [augmentedRealityAnnotations removeObject:augmentedRealityAnnotationController];
            [augmentedRealityAnnotationController.view removeFromSuperview];
            augmentedRealityAnnotationController = nil;
        }
    }
    
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *storyboardName = bundleInfoDictionary[@"UIMainStoryboardFile"];
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:storyboardName bundle:[NSBundle bundleForClass:[self class]]];
    for (placemark in visiblePlacemarks) {
        predicate = [NSPredicate predicateWithFormat:predicateFormat, placemark];
        augmentedRealityAnnotationController = [[augmentedRealityAnnotations filteredArrayUsingPredicate:predicate] lastObject];
        
        if (!augmentedRealityAnnotationController) {
            augmentedRealityAnnotationController = [storyBoard instantiateViewControllerWithIdentifier:@"DCAugmentedRealityAnnotationViewController"];
            [augmentedRealityAnnotations addObject:augmentedRealityAnnotationController];
            [previewView addSubview:augmentedRealityAnnotationController.view];
            augmentedRealityAnnotationController.placemark = placemark;
        }
        
        augmentedRealityAnnotationController.view.bounds = placemark.bounds;
        augmentedRealityAnnotationController.view.center = placemark.center;
    }
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

- (void)updateMapVisibleRegion {
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(stdMapView.userLocation.location.coordinate, distance, distance);
    
    [stdMapView setRegion:[stdMapView regionThatFits:region]
                 animated:YES];
}

- (IBAction)distanceSliderValueChanged:(UISlider *)sender {
    radius = MAXIMUM_DISTANCE * sender.value;
    distance = radius * ONE_MILE_IN_METERS;
    
    NSString *milesText = radius > 1.0 ? @"miles" : @"mile";
    
    distanceLabel.text = [NSString stringWithFormat:@"%.1f %@", radius, milesText];
    [self updateMapVisibleRegion];
}

- (IBAction)distanceSliderTouchUp:(UISlider *)sender {
    if (_visualizationMode != VisualizationModeAugmentedReality) {
        return;
    }
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [stdMapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:NO];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self calculateVisiblePlacemarksWithUserLocation:self.locationManager.location heading:self.locationManager.heading completionBlock:^(NSArray *visiblePlacemarks, NSArray *nonVisiblePlacemarks) {
                [self overlayAugmentedRealityPlacemarks:visiblePlacemarks nonVisiblePlacemarks:nonVisiblePlacemarks];
            }];
        });
    });
}

- (void)startAugmentedReality {
	[previewView.layer setBackgroundColor:[UIColor blackColor].CGColor];
	[previewView.layer addSublayer:self.videoPreviewLayer];
	
    [self.captureSession startRunning];
    
    stdMapView.showsUserLocation = YES;
    [stdMapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
    
    [self.locationManager startUpdatingLocation];
    [self.locationManager startUpdatingHeading];
    
    [self layoutScreen];
    [self updateMapVisibleRegion];
}

- (void)stopAugmentedReality {
    [self.captureSession stopRunning];
    
    [augmentedRealityAnnotations removeAllObjects];
    augmentedRealityAnnotations = nil;
    
    [self.videoPreviewLayer removeFromSuperlayer];
    [self setVideoPreviewLayer:nil];
    
    stdMapView.showsUserLocation = YES;
    [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];

    [self.locationManager stopUpdatingHeading];
    [self.locationManager stopUpdatingLocation];
    [self setLocationManager:nil];

    [self layoutScreen];
    [self updateMapVisibleRegion];
}

- (void)updateLocationManagerHeadingOrientation {
    if (!_locationManager) {
        return;
    }
    
    CLDeviceOrientation clDeviceOrientation;
    
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            clDeviceOrientation = CLDeviceOrientationPortrait;
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            clDeviceOrientation = CLDeviceOrientationPortraitUpsideDown;
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            clDeviceOrientation = CLDeviceOrientationLandscapeLeft;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            clDeviceOrientation = CLDeviceOrientationLandscapeRight;
            break;
            
        default:
            clDeviceOrientation = CLDeviceOrientationUnknown;
            break;
    }
    
    _locationManager.headingOrientation = clDeviceOrientation;
}

#pragma mark Public methods
- (void)startWithPlacemarks:(NSArray *)placemarks {
    self.placemarks = placemarks;
    
    stdMapView.showsUserLocation = YES;
    [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
    
    _visualizationMode = VisualizationModeMap;
    [self distanceSliderValueChanged:distanceSlider];
    
    if (annotations == nil) {
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
    [self stopAugmentedReality];
    [self setCaptureSession:nil];
    [self stopMonitoringDeviceMotion];
    [self setMotionManager:nil];
}

- (void)handleApplicationWillEnterForeground:(NSNotification *)notification {
    [self startMonitoringDeviceMotion];
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
            case VisualizationModeAugmentedReality:
                [self startAugmentedReality];
                break;
                
            case VisualizationModeMap:
                [self stopAugmentedReality];
                break;
                
            default:
                stdMapView.showsUserLocation = YES;
                [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
                [self layoutScreen];
                break;
        }
    });
}

#pragma mark MKMapViewDelegate methods
- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (_visualizationMode == VisualizationModeAugmentedReality) {
        if (mapView.userTrackingMode != MKUserTrackingModeFollowWithHeading) {
            [mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
            return;
        }
    }
    
    [self updateMapVisibleRegion];
}

#pragma mark CLLocationManagerDelegate methods
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (_visualizationMode != VisualizationModeAugmentedReality) {
        return;
    }
    
    [self calculateVisiblePlacemarksWithUserLocation:manager.location heading:newHeading completionBlock:^(NSArray *visiblePlacemarks, NSArray *nonVisiblePlacemarks) {
        [self overlayAugmentedRealityPlacemarks:visiblePlacemarks nonVisiblePlacemarks:nonVisiblePlacemarks];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if (_visualizationMode != VisualizationModeAugmentedReality) {
        return;
    }
    
    CLLocation *location = [locations lastObject];
    
    [self calculateVisiblePlacemarksWithUserLocation:location heading:manager.heading completionBlock:^(NSArray *visiblePlacemarks, NSArray *nonVisiblePlacemarks) {
        [self overlayAugmentedRealityPlacemarks:visiblePlacemarks nonVisiblePlacemarks:nonVisiblePlacemarks];
    }];
}

@end
