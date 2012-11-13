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

#define ACCELERATION_FILTER 0.2
#define Z_ACCELERATION_THRESHOLD 0.7

@interface DCAugmentedRealityViewController() {
    IBOutlet MKMapView *mapView;
    
    NSOperationQueue *motionQueue;
    UIAccelerationValue zAcceleration;
}

@property (nonatomic, strong) CMMotionManager *motionManager;

@end


@implementation DCAugmentedRealityViewController

@synthesize visualizationMode = _visualizationMode;

- (void)awakeFromNib {
    _visualizationMode = VisualizationModeUnknown;
    zAcceleration = FLT_MAX;

    motionQueue = [[NSOperationQueue alloc] init];
    
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

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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

#pragma mark Private methods
- (void)layoutScreen {
    
}

#pragma mark Notification handlers
- (void)handleApplicationDidEnterBackground:(NSNotification *)notification {
    [self setMotionManager:nil];
}

- (void)handleApplicationWillEnterForeground:(NSNotification *)notification {
}

#pragma mark Device motion methods
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
//                [self.delegate presentAugmentedReality:self.imagePickerController];
//                self.arMapView.showsUserLocation = YES;
                break;
                
            default:
//                self.arMapView.showsUserLocation = NO;
//                [self.arMapView setUserTrackingMode:MKUserTrackingModeNone animated:NO];
                [self.delegate dismissAugmentedReality];
                break;
        }
        
        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, 0.6 * NSEC_PER_SEC);
        dispatch_after(delayTime, dispatch_get_main_queue(), ^{
            [self layoutScreen];
        });
    });
}

@end
