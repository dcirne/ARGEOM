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
    
    return self;
}

@end
