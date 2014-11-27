//
//  ETA_ShortTapGestureRecognizer.m
//  Verso
//
//  Created by Laurie Hufford on 17/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_ShortTapGestureRecognizer.h"

@implementation ETA_ShortTapGestureRecognizer

- (instancetype) initWithTarget:(id)target action:(SEL)action
{
    if (self = [super initWithTarget:target action:action])
    {
        _maxTapDelay = 0.3f;
    }
    return self;
}
- (instancetype) init
{
    if (self = [super init])
    {
        _maxTapDelay = 0.3f;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.maxTapDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
                   {
                       // Enough time has passed and the gesture was not recognized -> It has failed.
                       if  (self.state != UIGestureRecognizerStateRecognized)
                       {
                           self.state = UIGestureRecognizerStateFailed;
                       }
                   });
}

@end
