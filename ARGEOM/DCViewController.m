//
//  DCViewController.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/9/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

#import "DCViewController.h"
#import "DCAugmentedRealityViewController.h"

@interface DCViewController() <DCAugmentedRealityViewControllerDelegate>

@end

@implementation DCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.arController addAnnotationsToMap];
    [self.arController startMonitoringDeviceMotion];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

#pragma mark DCAugmentedRealityViewControllerDelegate methods
- (void)presentAugmentedRealityController:(UIViewController *)viewController completion:(dispatch_block_t)completionBlock {
    [self presentViewController:viewController
                       animated:YES
                     completion:completionBlock];
}

- (void)dismissAugmentedRealityControllerWithCompletionBlock:(dispatch_block_t)completionBlock {
    [self dismissViewControllerAnimated:YES
                             completion:completionBlock];
}

@end
