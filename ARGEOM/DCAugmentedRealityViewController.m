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
#import <AVFoundation/AVFoundation.h>

#define ACCELERATION_FILTER 0.2
#define Z_ACCELERATION_THRESHOLD 0.7
#define AR_MAP_PERCENTAGE_SCREEN 0.4
#define AR_MAP_HORIZONTAL_INSET 10.0
#define AR_MAP_VERTICAL_INSET 30.0
#define ONE_MILE_IN_METERS 1609.3440006146
#define ONE_METER_IN_MILES 0.000621371192237334
#define NUMBER_DIMENSIONS 2
#define EARTH_RADIUS 3956.547

typedef void(^PlacemarksCalculationComplete)(NSArray *visiblePlacemarks, NSArray *nonVisiblePlacemarks);

@interface DCAugmentedRealityViewController() <MKMapViewDelegate> {
    IBOutlet MKMapView *stdMapView;
    IBOutlet UISlider *distanceSlider;
    IBOutlet UILabel *distanceLabel;
    IBOutlet UIView *previewView;
    
    NSOperationQueue *motionQueue;
    UIAccelerationValue zAcceleration;
    double phi;
    double radius;
    dispatch_queue_t placemarksQueue;
    NSMutableArray *annotations;
    BOOL initialized;
    CLLocationDistance distance;
    UIInterfaceOrientation previousInterfaceOrientation;
    UILabel *annotationLabel;
    double piOver180;
    double milesPerDegreeOfLatitude;
    double milesPerDegreeOfLongigute;
    BOOL isObservingOrientationChange;
}

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSArray *placemarks;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@end


@implementation DCAugmentedRealityViewController

@synthesize visualizationMode = _visualizationMode;

- (void)awakeFromNib {
    _visualizationMode = VisualizationModeUnknown;
    zAcceleration = FLT_MAX;
    phi = M_PI / 3.0;
    radius = 50.0;
    annotations = nil;
    initialized = NO;
    piOver180  = M_PI / 180.0;
    milesPerDegreeOfLatitude = 2 * M_PI * EARTH_RADIUS / 360.0;
    milesPerDegreeOfLongigute = milesPerDegreeOfLatitude; // Initialization only
    isObservingOrientationChange = NO;

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
    if ((_visualizationMode == VisualizationModeAugmentedReality) && _videoPreviewLayer) {
        [UIView animateWithDuration:duration
                         animations:^{
                             _videoPreviewLayer.frame = previewView.bounds;
                         } completion:^(BOOL finished) {
                             if (finished) {
                                 _videoPreviewLayer.connection.videoOrientation = toInterfaceOrientation;
                             }
                         }];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (_visualizationMode == VisualizationModeAugmentedReality && _videoPreviewLayer) {
        _videoPreviewLayer.connection.videoOrientation = [[UIDevice currentDevice] orientation];
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
    CGRect frame = previewView.bounds;
    [_videoPreviewLayer setFrame:frame];
    
    CGFloat rotationAngle;
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationLandscapeLeft:
            rotationAngle = -M_PI_2;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            rotationAngle = M_PI_2;
            break;
            
        default:
            rotationAngle = -M_PI_2;
            break;
    }

    _videoPreviewLayer.connection.videoOrientation = [[UIDevice currentDevice] orientation];
    
    return _videoPreviewLayer;
}

#pragma mark Private methods
- (void)layoutScreen {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    UIDevice *device = [UIDevice currentDevice];
    CGRect mapFrame;

    CGRect arFrame = self.view.bounds;
    
    switch (_visualizationMode) {
        case VisualizationModeAugmentedReality: {
            [device beginGeneratingDeviceOrientationNotifications];
            
            if (!isObservingOrientationChange) {
                isObservingOrientationChange = YES;
                
                [notificationCenter addObserver:self
                                       selector:@selector(handleDeviceDidRotate:)
                                           name:UIDeviceOrientationDidChangeNotification
                                         object:nil];
            }
            
            mapFrame.size = CGSizeMake(arFrame.size.width * AR_MAP_PERCENTAGE_SCREEN,
                                       arFrame.size.height * AR_MAP_PERCENTAGE_SCREEN);
            
            mapFrame.origin = CGPointMake(arFrame.size.width - mapFrame.size.width - AR_MAP_HORIZONTAL_INSET,
                                          arFrame.size.height - mapFrame.size.height - distanceSlider.frame.size.height - AR_MAP_VERTICAL_INSET);
        }
            break;
            
        case VisualizationModeMap: {
            [device endGeneratingDeviceOrientationNotifications];
            
            if (isObservingOrientationChange) {
                isObservingOrientationChange = NO;
                
                [notificationCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
            }
            
            mapFrame = arFrame;
        }
            break;
            
        default:
            return;
            break;
    }
    
    [UIView animateWithDuration:[UIApplication sharedApplication].statusBarOrientationAnimationDuration
                     animations:^{
                         stdMapView.frame = mapFrame;
                     }];
}

- (void)calculateVisiblePlacemarksWithUserLocation:(MKUserLocation *const)userLocation completionBlock:(PlacemarksCalculationComplete)completionBlock {
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
        
        milesPerDegreeOfLongigute = milesPerDegreeOfLatitude * cos(userLocation.location.coordinate.latitude * piOver180);
        
        double alpha = userLocation.heading.trueHeading * piOver180;
        double psi = M_PI / 2.0 - alpha;
        double longitudeRadiusInDegrees = radius / milesPerDegreeOfLongigute;
        double latitudeRadiusInDegrees = radius / milesPerDegreeOfLatitude;
        
        CGPoint pointA = CGPointMake(userLocation.location.coordinate.longitude,
                                     userLocation.location.coordinate.latitude);
        
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
        
        double lambda, sigma, theta, dPrime;
        CGPoint pointP;
        double vectorAP[NUMBER_DIMENSIONS];
        int i = 0;
        double l = [UIScreen mainScreen].bounds.size.height;
        for (DCPlacemark *placemark in self.placemarks) {
            pointP = CGPointMake(placemark.coordinate.longitude, placemark.coordinate.latitude);
            vectorAP[0] = pointP.x - pointA.x;
            vectorAP[1] = pointP.y - pointA.y;

            lambda = dotProduct(vectorAP, vectorAB) / pow(norm(vectorAB), 2);
            sigma = dotProduct(vectorAP, vectorAC) / pow(norm(vectorAC), 2);
            //NSLog(@"lambda: %.4f, sigma: %.4f", lambda, sigma);
            if ((lambda > 0) && (sigma > 0) && (pow(lambda, 2) + pow(sigma, 2) <= 1)) {
                theta = acos(dotProduct(vectorAM, vectorAP) / (norm(vectorAM) * norm(vectorAP)));
                
                dPrime = l * norm(vectorAP) * sin(theta) / norm(vectorBC);
                //NSLog(@"dPrime: %.4f", dPrime);
                NSLog(@"%d - %@", i, @"Visible");
                [visiblePlacemarks addObject:placemark];
            } else {
                [nonVisiblePlacemarks addObject:placemark];
                NSLog(@"%d - %@", i, @"Not Visible");
            }
            
            ++i;
        }
        
        completionBlock([visiblePlacemarks copy], [nonVisiblePlacemarks copy]);
    });
}

- (void)overlayAugmentedRealityAnnotations {
    CGRect frame = CGRectMake(stdMapView.userLocation.heading.trueHeading, 100, 300, 50);

    if (!annotationLabel) {
        annotationLabel = [[UILabel alloc] initWithFrame:frame];
        annotationLabel.backgroundColor = [UIColor yellowColor];
        annotationLabel.textColor = [UIColor whiteColor];
        annotationLabel.shadowColor = [UIColor blackColor];
        annotationLabel.shadowOffset = CGSizeMake(1, 1);
        annotationLabel.alpha = 0.5;
        annotationLabel.text = @"AR Annotation";
        annotationLabel.textAlignment = UITextAlignmentCenter;
        [self.view addSubview:annotationLabel];
    }
    
    annotationLabel.frame = frame;
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
    radius = 100 * sender.value;
    distance = radius * ONE_MILE_IN_METERS;
    
    NSString *milesText = radius > 1.0 ? @"miles" : @"mile";
    
    distanceLabel.text = [NSString stringWithFormat:@"%.1f %@", radius, milesText];
    [self updateMapVisibleRegion];
}

- (void)startAugmentedReality {
	[previewView.layer setBackgroundColor:[UIColor blackColor].CGColor];
	[previewView.layer addSublayer:self.videoPreviewLayer];
	
    [self.captureSession startRunning];
    
    stdMapView.showsUserLocation = YES;
    [stdMapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
    
    [self layoutScreen];
    [self updateMapVisibleRegion];
}

- (void)stopAugmentedReality {
    [self.captureSession stopRunning];
    
    [self.videoPreviewLayer removeFromSuperlayer];
    [self setVideoPreviewLayer:nil];
    
    stdMapView.showsUserLocation = YES;
    [stdMapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];

    [self layoutScreen];
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
    [self stopAugmentedReality];
    [self setCaptureSession:nil];
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
    switch (_visualizationMode) {
        case VisualizationModeAugmentedReality: {
            if (mapView.userTrackingMode != MKUserTrackingModeFollowWithHeading) {
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^{
                    if ([CLLocationManager headingAvailable]) {
                        [mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
                    } else {
                        [mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
                    }
                });
                
                return;
            }
            
            if (![CLLocationManager headingAvailable]) {
                return;
            }
            
            [self calculateVisiblePlacemarksWithUserLocation:userLocation completionBlock:^(NSArray *visiblePlacemarks, NSArray *nonVisiblePlacemarks) {
                if (visiblePlacemarks) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self overlayAugmentedRealityAnnotations];
                    });
                }
            }];
        }
            break;
            
        case VisualizationModeMap:
            [self updateMapVisibleRegion];
            break;
            
        default:
            break;
    }
}

@end
