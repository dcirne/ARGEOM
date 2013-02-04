//
//  DCPlacemark.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/13/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

#import "DCPlacemark.h"

@implementation DCPlacemark

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _title = nil;
    _subtitle = nil;
    _coordinate = CLLocationCoordinate2DMake(0, 0);
    _distanceFromObserver = FLT_MAX;
    
    return self;
}

- (CLLocationDistance)calculateDistanceFromObserver:(CLLocationCoordinate2D)observerCoordinates {
    CLLocation *observerLocation = [[CLLocation alloc] initWithLatitude:observerCoordinates.latitude longitude:observerCoordinates.longitude];
    CLLocation *placemarkLocation = [[CLLocation alloc] initWithLatitude:_coordinate.latitude longitude:_coordinate.longitude];
    _distanceFromObserver = sqrt(pow([placemarkLocation distanceFromLocation:observerLocation], 2));
    
    return _distanceFromObserver;
}

@end
