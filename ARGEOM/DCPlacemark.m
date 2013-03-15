//
//  DCPlacemark.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/13/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

/*
 Copyright (c) 2013, Dalmo Cirne
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3- Neither the name of Dalmo Cirne nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
    _bounds = CGRectZero;
    _center = CGPointZero;
    
    return self;
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    id copyObject = [[[self class] alloc] init];
    
    if (copyObject) {
        [copyObject setTitle:[_title copyWithZone:zone]];
        [copyObject setSubtitle:[_subtitle copyWithZone:zone]];
        [copyObject setCoordinate:_coordinate];
        [copyObject setDistanceFromObserver:_distanceFromObserver];
        [copyObject setBounds:_bounds];
        [copyObject setCenter:_center];
    }
    
    return copyObject;
}

#pragma mark Accessors
- (void)setDistanceFromObserver:(CLLocationDistance)distanceFromObserver {
    _distanceFromObserver = distanceFromObserver;
}

#pragma mark Public methods
- (CLLocationDistance)calculateDistanceFromObserver:(CLLocationCoordinate2D)observerCoordinates {
    CLLocation *observerLocation = [[CLLocation alloc] initWithLatitude:observerCoordinates.latitude longitude:observerCoordinates.longitude];
    CLLocation *placemarkLocation = [[CLLocation alloc] initWithLatitude:_coordinate.latitude longitude:_coordinate.longitude];
    _distanceFromObserver = sqrt(pow([placemarkLocation distanceFromLocation:observerLocation], 2));
    
    return _distanceFromObserver;
}

@end
