//
//  DCPlacemark.h
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/13/12.
//  Copyright (c) 2012 Dalmo Cirne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface DCPlacemark : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, unsafe_unretained) CLLocationCoordinate2D coordinate;

@end
