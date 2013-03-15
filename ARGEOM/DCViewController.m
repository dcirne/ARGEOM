//
//  DCViewController.m
//  ARGEOM
//
//  Created by Dalmo Cirne on 11/9/12.
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

#import "DCViewController.h"
#import "DCAugmentedRealityViewController.h"
#import <dispatch/dispatch.h>
#import "DCPlacemark.h"

#define USE_AIRPORT_PLACEMARKS

typedef void(^PlacemarksLoaded)(NSArray *placemarks);

@interface DCViewController()

@end

@implementation DCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
#ifdef USE_AIRPORT_PLACEMARKS
    [self loadPlacemarks:^(NSArray *placemarks) {
        NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *storyboardName = bundleInfoDictionary[@"UIMainStoryboardFile"];
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:storyboardName bundle:[NSBundle bundleForClass:[self class]]];
        [self setArController:[storyBoard instantiateViewControllerWithIdentifier:@"DCAugmentedRealityViewController"]];
        
        [self.arController setPlacemarks:placemarks];
        
        [self presentViewController:self.arController
                           animated:NO
                         completion:^{
                             [self.arController start];
                         }];
    }];
#else
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *storyboardName = bundleInfoDictionary[@"UIMainStoryboardFile"];
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:storyboardName bundle:[NSBundle bundleForClass:[self class]]];
        [self setArController:[storyBoard instantiateViewControllerWithIdentifier:@"DCAugmentedRealityViewController"]];
        
        NSArray *placemarks = [self loadPlacemarks];
        [self.arController setPlacemarks:placemarks];
        
        [self presentViewController:self.arController
                           animated:NO
                         completion:^{
                             [self.arController start];
                         }];
    });
#endif
}

- (NSArray *)loadPlacemarks {
    NSMutableArray *placemarks = [[NSMutableArray alloc] initWithCapacity:5];
    
    DCPlacemark *placemark;
    
    // Placemark 1
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"New York City";
    placemark.subtitle = @"The Big Apple";
    placemark.coordinate = CLLocationCoordinate2DMake(40.7833, -73.9667);
    [placemarks addObject:placemark];
    
    // Placemark 2
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"White Plains";
    placemark.subtitle = @"Large City in Westchester County";
    placemark.coordinate = CLLocationCoordinate2DMake(41.0667, -73.7);
    [placemarks addObject:placemark];
    
    // Placemark 3
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"Albany";
    placemark.subtitle = @"State Capital";
    placemark.coordinate = CLLocationCoordinate2DMake(42.75, -73.8);
    [placemarks addObject:placemark];
    
    // Placemark 4
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"Point 4";
    placemark.subtitle = @"";
    placemark.coordinate = CLLocationCoordinate2DMake(44, -72);
    [placemarks addObject:placemark];
    
    // Placemark 5
    placemark = [[DCPlacemark alloc] init];
    placemark.title = @"Point 5";
    placemark.subtitle = @"";
    placemark.coordinate = CLLocationCoordinate2DMake(42, -74.5);
    [placemarks addObject:placemark];
    
    return [placemarks copy];
}

- (void)loadPlacemarks:(PlacemarksLoaded)completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *placemarksURL = [mainBundle URLForResource:@"GlobalAirportDatabase" withExtension:@"txt"];
        
        NSError *error = nil;
        NSString *airportsString = [NSString stringWithContentsOfURL:placemarksURL encoding:NSUTF8StringEncoding error:&error];
        NSArray *airportsArray = [airportsString componentsSeparatedByString:@"\n"];
        __block NSArray *airportArray;
        __block NSMutableArray *placemarks = [[NSMutableArray alloc] initWithCapacity:airportsArray.count];
        __block CLLocationDegrees latitude, longitude;
        __block double latitudeDirection, longitudeDirection;
        
        [airportsArray enumerateObjectsUsingBlock:^(NSString *airportString, NSUInteger idx, BOOL *stop) {
            airportArray = [airportString componentsSeparatedByString:@":"];
            
            if (airportArray.count < 14) {
                return;
            }
            
            latitudeDirection = [airportArray[8] isEqualToString:@"N"] ? 1.0 : -1.0;
            latitude = ([airportArray[5] doubleValue] + [airportArray[6] doubleValue] / 60.0) * latitudeDirection;
            
            longitudeDirection = [airportArray[12] isEqualToString:@"E"] ? 1.0 : -1.0;
            longitude = ([airportArray[9] doubleValue] + [airportArray[10] doubleValue] / 60.0) * longitudeDirection;
            
            if (latitude == 0 && longitude == 0) {
                return;
            }
            
            DCPlacemark *placemark = [[DCPlacemark alloc] init];
            placemark.title = [NSString stringWithFormat:@"%@ - %@", airportArray[1], airportArray[2]];
            placemark.subtitle = [NSString stringWithFormat:@"%@, %@", airportArray[3], airportArray[4]];
            placemark.coordinate = CLLocationCoordinate2DMake(latitude, longitude);
            [placemarks addObject:placemark];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(placemarks);
        });
    });
}

@end
