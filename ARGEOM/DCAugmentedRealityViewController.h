//
//  DCAugmentedRealityViewController.h
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/9/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

typedef enum : NSInteger {
    VisualizationModeUnknown = -1,
    VisualizationModeMap,
    VisualizationModeAugmentedReality
} VisualizationMode;

@protocol DCAugmentedRealityViewControllerDelegate;

@interface DCAugmentedRealityViewController : UIViewController

@property (nonatomic, weak) IBOutlet id<DCAugmentedRealityViewControllerDelegate> delegate;
@property (nonatomic, readonly, getter = visualizationMode) VisualizationMode visualizationMode;

- (void)addAnnotationsToMap;
- (void)startMonitoringDeviceMotion;
- (void)stopMonitoringDeviceMotion;

@end

@protocol DCAugmentedRealityViewControllerDelegate <NSObject>
- (void)presentAugmentedRealityController:(UIViewController *)viewController completion:(dispatch_block_t)completionBlock;
- (void)dismissAugmentedRealityControllerWithCompletionBlock:(dispatch_block_t)completionBlock;
@end