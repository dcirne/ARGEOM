//
//  DCViewController.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/9/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

#import "DCViewController.h"
#import "DCAugmentedRealityViewController.h"
#import <dispatch/dispatch.h>

@interface DCViewController() <DCAugmentedRealityViewControllerDelegate>

@end

@implementation DCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.arController start];
    });
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
