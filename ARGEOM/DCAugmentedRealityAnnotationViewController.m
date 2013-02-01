//
//  DCAnnotationViewController.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 2/1/13.
//  Copyright (c) 2013 Dalmo Cirne. All rights reserved.
//

#import "DCAugmentedRealityAnnotationViewController.h"
#import "DCPlacemark.h"
#import <dispatch/dispatch.h>

@interface DCAugmentedRealityAnnotationViewController()

@property (nonatomic, strong) IBOutlet UILabel *annotationLabel;
@property (nonatomic, strong) IBOutlet UIView *backgroundView;

@end


@implementation DCAugmentedRealityAnnotationViewController

- (void)setPlacemark:(DCPlacemark *)placemark {
    _placemark = placemark;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.annotationLabel.text = _placemark.title;
    });
}

@end
