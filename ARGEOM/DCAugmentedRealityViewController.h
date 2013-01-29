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

@interface DCAugmentedRealityViewController : UIViewController

@property (nonatomic, readonly, getter = visualizationMode) VisualizationMode visualizationMode;
@property (nonatomic, strong) IBOutlet UIView *augmentedRealityView;

- (void)start;
- (void)stop;

@end
