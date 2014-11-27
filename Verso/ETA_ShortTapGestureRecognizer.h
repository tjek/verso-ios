//
//  ETA_ShortTapGestureRecognizer.h
//  Verso
//
//  Created by Laurie Hufford on 17/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

@interface ETA_ShortTapGestureRecognizer : UITapGestureRecognizer

@property (nonatomic, assign) NSTimeInterval maxTapDelay; // default 0.3 secss

@end
