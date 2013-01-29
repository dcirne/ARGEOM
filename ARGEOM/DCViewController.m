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

@interface DCViewController()

@end

@implementation DCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.arController start];
    });
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

@end
