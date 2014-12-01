//
//  ETA_VersoSinglePageContentsView.m
//  Verso
//
//  Created by Laurie Hufford on 20/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_VersoSinglePageContentsView.h"

@interface ETA_VersoSinglePageContentsView ()

@property (nonatomic, strong) UIView* hotspotContainerView;

@property (nonatomic, strong) NSMutableDictionary* hotspotRectViews;
@property (nonatomic, strong) NSMutableDictionary* hotspotRects;

@end

@implementation ETA_VersoSinglePageContentsView

- (instancetype) init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype) initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        _showHotspots = NO;
        _hotspotRects = [NSMutableDictionary dictionary];
        _hotspotRectViews = [NSMutableDictionary dictionary];
        
        [self addSubviews];
    }
    return self;
}

- (void)addSubviews
{
    [self addSubview:self.imageView];
    
    [self addSubview:self.hotspotContainerView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self layoutHotspots];
}


#pragma mark - Sizing

- (CGSize) intrinsicContentSize
{
    return self.imageView.intrinsicContentSize;
}

- (CGSize) sizeThatFits:(CGSize)maxSize
{
    CGSize contentSize = self.intrinsicContentSize;
    
    CGFloat heightByWidth = 1.0;
    if (contentSize.height != UIViewNoIntrinsicMetric && contentSize.width != UIViewNoIntrinsicMetric && contentSize.width > 0 && contentSize.height > 0)
    {
        heightByWidth = contentSize.height / contentSize.width;
    }
    
    CGSize fitSize = maxSize;
    
    // first scale to fit to max width (the height may be a bit taller than max)
    fitSize.height = heightByWidth * maxSize.width;
    
    // then, if we are not allowing height overrun, and we are overrunning, fit to height and scale width
    if (maxSize.height != UIViewNoIntrinsicMetric && fitSize.height > maxSize.height)
    {
        fitSize.height = maxSize.height;
        fitSize.width = fitSize.height / heightByWidth;
    }
    
    return fitSize;
}




#pragma mark - Hotspots
- (void) setShowHotspots:(BOOL)showHotspots
{
    [self setShowHotspots:showHotspots animated:NO];
}
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated
{
    _showHotspots = showHotspots;
    
    [UIView animateWithDuration:animated ? 0.2 : 0 animations:^{
        self.hotspotContainerView.alpha = showHotspots ? 1.0 : 0.0;
    }];
}

- (void) clearHotspotRects
{
    @synchronized(self.hotspotRects)
    {
        NSArray* subviews = self.hotspotContainerView.subviews;
        [subviews enumerateObjectsUsingBlock:^(UIView* subview, NSUInteger idx, BOOL *stop) {
            [subview removeFromSuperview];
        }];
        
        [self.hotspotRectViews removeAllObjects];
        [self.hotspotRects removeAllObjects];
    }
}

- (void) addHotspotRects:(NSDictionary*)hotspotRects
{
    if (!hotspotRects)
        return;
    
    @synchronized(self.hotspotRects)
    {
        [self.hotspotRects addEntriesFromDictionary:hotspotRects];
        
        [hotspotRects enumerateKeysAndObjectsUsingBlock:^(id key, NSValue* hotspotRect, BOOL *stop) {
            // view already exists
            if (self.hotspotRectViews[key])
            {
                return;
            }
            
            UIView* hotspotView = [UIView new];
            hotspotView.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.1];
            hotspotView.layer.borderColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.2].CGColor;
            hotspotView.layer.borderWidth = 1.0/UIScreen.mainScreen.scale;
            
            hotspotView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            self.hotspotRectViews[key] = hotspotView;

            [self.hotspotContainerView addSubview:hotspotView];
        }];
    }
    
    [self setNeedsLayout];
}

- (void) layoutHotspots
{
    @synchronized(self.hotspotRects)
    {
        CGSize scaledSize = self.hotspotContainerView.bounds.size;
        
        // if the height goes from 0->[aspect ratio], change the scaled size to be normalized so height == width
        if (self.hotspotsNormalizedByWidth)
        {
            CGSize contentSize = self.intrinsicContentSize;
            
            if (contentSize.height != UIViewNoIntrinsicMetric && contentSize.width != UIViewNoIntrinsicMetric && contentSize.width > 0 && contentSize.height > 0)
            {
                CGFloat widthByHeight = contentSize.width / contentSize.height;
                scaledSize.height *= widthByHeight;
            }
        }
        
        
        
        [self.hotspotRectViews enumerateKeysAndObjectsUsingBlock:^(id key, UIView* hotspotView, BOOL *stop) {
            NSValue* hotspotRectValue = self.hotspotRects[key];
            if (!hotspotRectValue)
                return;
            
            CGRect relativeRect = [hotspotRectValue CGRectValue];
            
            relativeRect.origin.x *= scaledSize.width;
            relativeRect.origin.y *= scaledSize.height;
            relativeRect.size.width *= scaledSize.width;
            relativeRect.size.height *= scaledSize.height;
            
            hotspotView.frame = relativeRect;
        }];
    }
}


- (NSArray*) hotspotKeysAtPoint:(CGPoint)point
{
    NSMutableArray* hitKeys = [NSMutableArray array];
    [self.hotspotRectViews enumerateKeysAndObjectsUsingBlock:^(id key, UIView* hotspotView, BOOL *stop) {
        if (CGRectContainsPoint(hotspotView.frame, point))
        {
            [hitKeys addObject:key];
        }
    }];
    return hitKeys;
}


#pragma mark - Views

- (UIImageView*) imageView
{
    if (!_imageView)
    {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _imageView;
}


- (UIView*) hotspotContainerView
{
    if (!_hotspotContainerView)
    {
        _hotspotContainerView = [[UIView alloc] initWithFrame:self.bounds];
        _hotspotContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _hotspotContainerView.alpha = self.showHotspots ? 1.0 : 0.0;
    }
    return _hotspotContainerView;
}

@end
