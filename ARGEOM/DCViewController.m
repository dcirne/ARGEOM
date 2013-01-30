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
        NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *storyboardName = bundleInfoDictionary[@"UIMainStoryboardFile"];
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:storyboardName bundle:[NSBundle bundleForClass:[self class]]];
        [self setArController:[storyBoard instantiateViewControllerWithIdentifier:@"DCAugmentedRealityViewController"]];
        
        [self presentViewController:self.arController
                           animated:NO
                         completion:^{
                             [self.arController start];
                         }];
    });
}

@end
