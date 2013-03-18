//
//  DCAugmentedRealityViewController.h
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

#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

typedef enum : NSInteger {
    VisualizationModeUnknown = -1,
    VisualizationModeMap,
    VisualizationModeAugmentedReality
} VisualizationMode;

@interface DCAugmentedRealityViewController : UIViewController

@property (nonatomic, readonly) VisualizationMode visualizationMode;
@property (nonatomic, readonly) NSArray *placemarks;

- (void)startWithPlacemarks:(NSArray *)placemarks;
- (void)stop;

@end
