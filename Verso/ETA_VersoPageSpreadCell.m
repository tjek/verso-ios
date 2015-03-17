//
//  ETA_VersoPageSpreadCell.m
//  Verso
//
//  Created by Laurie Hufford on 04/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_VersoPageSpreadCell.h"

#import "ETA_VersoSinglePageContentsView.h"


@interface ETA_VersoPageSpreadCell () <UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, assign) BOOL isVersoImageZoom;
@property (nonatomic, assign) NSInteger versoPageIndex;
@property (nonatomic, assign) BOOL isRectoImageZoom;
@property (nonatomic, assign) NSInteger rectoPageIndex;

@property (nonatomic, strong) UITapGestureRecognizer* tapGesture;
@property (nonatomic, strong) UILongPressGestureRecognizer* touchGesture;
@property (nonatomic, strong) UITapGestureRecognizer* doubleTapGesture;
@property (nonatomic, strong) UILongPressGestureRecognizer* longPressGesture;

@property (nonatomic, strong) UIScrollView* zoomView;

@property (nonatomic, strong) UIView* pageContentsContainer;

@property (nonatomic, strong) ETA_VersoSinglePageContentsView* versoPageContents;
@property (nonatomic, strong) ETA_VersoSinglePageContentsView* rectoPageContents;

@end

@implementation ETA_VersoPageSpreadCell

- (instancetype) init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype) initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        _fitToWidth = NO;
        
        [self addSubviews];
    }
    return self;
}

- (void) dealloc
{
    self.delegate = nil;
}

- (void)addSubviews
{
    // add the gesture recognizers
    self.doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTap:)];
    self.doubleTapGesture.delegate = self;
    self.doubleTapGesture.numberOfTapsRequired = 2;
    [self.contentView addGestureRecognizer:self.doubleTapGesture];
    
    self.longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
    self.longPressGesture.delegate = self;
    [self.contentView addGestureRecognizer:self.longPressGesture];
    
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    [self.tapGesture requireGestureRecognizerToFail:self.zoomView.panGestureRecognizer];
    [self.tapGesture requireGestureRecognizerToFail:self.doubleTapGesture];
    [self.tapGesture requireGestureRecognizerToFail:self.longPressGesture];
    self.tapGesture.delegate = self;
    [self.contentView addGestureRecognizer:self.tapGesture];
    
    
    self.touchGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didTouch:)];
    self.touchGesture.minimumPressDuration = 0.3;
    self.touchGesture.delegate = self;
    self.touchGesture.cancelsTouchesInView = NO;
    self.touchGesture.delaysTouchesEnded = NO;
    self.touchGesture.delaysTouchesBegan = NO;
    [self.contentView addGestureRecognizer:self.touchGesture];
    
    [self.pageContentsContainer addSubview:self.rectoPageContents];
    [self.pageContentsContainer addSubview:self.versoPageContents];
    
    [self.zoomView addSubview:self.pageContentsContainer];
        
    [self.contentView addSubview:self.zoomView];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    
    // reset the zoom state
    [self.zoomView setZoomScale:self.zoomView.minimumZoomScale animated:NO];
    [self.zoomView setContentSize:CGSizeZero];
    [self.zoomView setContentOffset:CGPointZero animated:NO];
    self.zoomView.pinchGestureRecognizer.enabled = YES;
    
    _showHotspots = NO;
    
    _versoPageIndex = NSNotFound;
    [self.versoPageContents clearHotspotRects];
    [self setImage:nil isZoomImage:NO forSide:ETA_VersoPageSpreadSide_Verso animated:NO];
    
    _rectoPageIndex = NSNotFound;
    [self.rectoPageContents clearHotspotRects];
    [self setImage:nil isZoomImage:NO forSide:ETA_VersoPageSpreadSide_Recto animated:NO];
    
    [self setNeedsLayout];
}






#pragma mark - Layout

- (void) layoutSubviews
{
    [super layoutSubviews];
    
    CGRect readerBounds = self.contentView.bounds;
    
    BOOL versoVisible = self.versoPageIndex != NSNotFound;
    BOOL rectoVisible = self.rectoPageIndex != NSNotFound;
    
    // which side is front most - defaults to verso
    ETA_VersoPageSpreadSide frontmostSide = ETA_VersoPageSpreadSide_Verso;
    if (versoVisible == NO && rectoVisible)
        frontmostSide = ETA_VersoPageSpreadSide_Recto;
    
    
    BOOL fitToWidth = self.fitToWidth;

    // calculate the max size for a single page image
    CGSize maxPageSize = readerBounds.size;
    if (versoVisible && rectoVisible)
        maxPageSize.width = ceil(maxPageSize.width / 2);
    
    if (fitToWidth)
        maxPageSize.height = UIViewNoIntrinsicMetric;
    
    
    
    CGRect containerFrame = CGRectZero;
    
    CGRect versoFrame = CGRectZero;
    CGRect rectoFrame = CGRectZero;
    
    // size the pages, if they are visible
    if (versoVisible)
    {
        versoFrame.size = [self.versoPageContents sizeThatFits:maxPageSize];
    }
    if (rectoVisible)
    {
        rectoFrame.size = [self.rectoPageContents sizeThatFits:maxPageSize];
    }

    
    // make a hidden page the size of the opposing page, and scale it down a bit, so that when it appears it zooms in
    CGFloat hiddenScaleFactor = 0.5;
    if (versoVisible == NO)
    {
        versoFrame.size = (CGSize) {
            .width = rectoFrame.size.width * hiddenScaleFactor,
            .height = rectoFrame.size.width * hiddenScaleFactor
        };
    }
    if (rectoVisible == NO)
    {
        rectoFrame.size = (CGSize) {
            .width = versoFrame.size.width * hiddenScaleFactor,
            .height = versoFrame.size.width * hiddenScaleFactor
        };
    }
    
    
    
    // fit container to the contents
    if (rectoVisible && !versoVisible)
    {
        containerFrame.size.height = rectoFrame.size.height;
        containerFrame.size.width = CGRectGetMaxX(rectoFrame);
    }
    // only verso visible
    else if (versoVisible && !rectoVisible)
    {
        containerFrame.size.height = versoFrame.size.height;
        containerFrame.size.width = CGRectGetMaxX(versoFrame);
    }
    else if (rectoVisible && versoVisible)
    {
        // position recto to the right of verso (-1 to avoid flickering subpixel spine)
        rectoFrame.origin.x = floor(CGRectGetMaxX(versoFrame)-1);
        
        // increase the container size to fit the second page, if visible
        containerFrame.size.height = MAX(versoFrame.size.height, rectoFrame.size.height);
        containerFrame.size.width = CGRectGetMaxX(rectoFrame);
    }
    
    
    // center both pages vertically
    versoFrame.origin.y = MAX(0, (containerFrame.size.height / 2) - (versoFrame.size.height / 2));
    rectoFrame.origin.y = MAX(0, (containerFrame.size.height / 2) - (rectoFrame.size.height / 2));
    

    CGFloat zoomScale = self.zoomView.zoomScale;
    
    // scale the container to match the zoomscale
    containerFrame.size.height *= zoomScale;
    containerFrame.size.width *= zoomScale;

    
    self.zoomView.contentSize = containerFrame.size;
 
    self.pageContentsContainer.frame = containerFrame;
    self.versoPageContents.frame = versoFrame;
    self.rectoPageContents.frame = rectoFrame;
    
    
    [self _updateZoomContentInsets];
}



- (void) _updateZoomContentInsets
{
    UIView* contentView = self.pageContentsContainer;
    UIScrollView* scrollView = self.zoomView;
    
    CGRect contentFrame = contentView.frame;
    CGRect scrollBounds = scrollView.bounds;
    
    
    UIEdgeInsets edgeInset = { 0, 0, 0, 0};
    
    if (scrollBounds.size.height > contentFrame.size.height)
    {
        edgeInset.top = (CGRectGetMidY(scrollBounds) - scrollView.contentOffset.y) - CGRectGetMidY(contentFrame);
    }
    if (scrollBounds.size.width > contentFrame.size.width)
    {
        edgeInset.left = (CGRectGetMidX(scrollBounds) - scrollView.contentOffset.x) - CGRectGetMidX(contentFrame);
    }
    
    self.zoomView.contentInset = edgeInset;
}




#pragma mark - Display Property Setters

- (void) setVersoPageIndex:(NSUInteger)versoPageIndex rectoPageIndex:(NSUInteger)rectoPageIndex animated:(BOOL)animated
{
    BOOL wasVersoVisible = self.versoPageIndex != NSNotFound;
    BOOL wasRectoVisible = self.rectoPageIndex != NSNotFound;
    
    self.versoPageIndex = versoPageIndex;
    self.rectoPageIndex = rectoPageIndex;

    BOOL isVersoVisible = self.versoPageIndex != NSNotFound;
    BOOL isRectoVisible = self.rectoPageIndex != NSNotFound;
    
    // verso hiding - put recto in front
    if (wasVersoVisible && isVersoVisible == NO)
    {
        [self.rectoPageContents.superview insertSubview:self.rectoPageContents aboveSubview:self.versoPageContents];
    }
    // recto hiding - put verso in front
    else if (wasRectoVisible && isRectoVisible == NO)
    {
        [self.versoPageContents.superview insertSubview:self.versoPageContents aboveSubview:self.rectoPageContents];
    }
    
    
    BOOL wereAnimationsEnabled = [UIView areAnimationsEnabled];
    
    // zoom out of the view
    [self.zoomView setZoomScale:self.zoomView.minimumZoomScale animated:animated];

    [self setNeedsLayout];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        [UIView setAnimationsEnabled:animated];
        
        self.versoPageContents.alpha = (self.versoPageIndex == NSNotFound) ? 0 : 1;
        self.rectoPageContents.alpha = (self.rectoPageIndex == NSNotFound) ? 0 : 1;
        
        [self layoutIfNeeded];
        
        [UIView setAnimationsEnabled:wereAnimationsEnabled];
    } completion:nil];
}

- (void) setFitToWidth:(BOOL)fitToWidth
{
    [self setFitToWidth:fitToWidth animated:NO];
}

- (void) setFitToWidth:(BOOL)fitToWidth animated:(BOOL)animated
{
    if (_fitToWidth == fitToWidth)
        return;
    
    _fitToWidth = fitToWidth;
    
    
    
    BOOL wereAnimationsEnabled = [UIView areAnimationsEnabled];
    
    // zoom out of the view
    [self.zoomView setZoomScale:self.zoomView.minimumZoomScale animated:animated];
    
    [self setNeedsLayout];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        [UIView setAnimationsEnabled:animated];
        
        [self layoutIfNeeded];
        
        [UIView setAnimationsEnabled:wereAnimationsEnabled];
    } completion:nil];
}





#pragma mark - Page Side properties

- (NSInteger) pageIndexForSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            return self.versoPageIndex;
        case ETA_VersoPageSpreadSide_Recto:
            return self.rectoPageIndex;
    }
}

- (BOOL) isShowingZoomImageForSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            return self.isVersoImageZoom;
        case ETA_VersoPageSpreadSide_Recto:
            return self.isRectoImageZoom;
    }
}

- (void) setIsShowingZoomImage:(BOOL)isShowingZoomImage forSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            self.isVersoImageZoom = isShowingZoomImage;
            break;
        case ETA_VersoPageSpreadSide_Recto:
            self.isRectoImageZoom = isShowingZoomImage;
            break;
    }
}

- (void) setPageNumberLabelText:(NSAttributedString*)text color:(UIColor*)color forSide:(ETA_VersoPageSpreadSide)pageSide
{
    ETA_VersoSinglePageContentsView* pageContentsView = nil;
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            pageContentsView = self.versoPageContents;
            break;
        case ETA_VersoPageSpreadSide_Recto:
            pageContentsView = self.rectoPageContents;
            break;
    }
    pageContentsView.pageNumberLabel.textColor = color;
    pageContentsView.pageNumberLabel.attributedText = text;
}

- (void) setImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage forSide:(ETA_VersoPageSpreadSide)pageSide animated:(BOOL)animated
{
    // dont set an empty zoom image
    if (!image && isZoomImage)
    {
        return;
    }
    
    [self setIsShowingZoomImage:isZoomImage forSide:pageSide];
    
    ETA_VersoSinglePageContentsView* pageContentsView = nil;
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            pageContentsView = self.versoPageContents;
            break;
        case ETA_VersoPageSpreadSide_Recto:
            pageContentsView = self.rectoPageContents;
            break;
    }
    
    [self setImage:image forPageContentsView:pageContentsView animated:animated];
}
- (void) setImage:(UIImage *)image forPageContentsView:(ETA_VersoSinglePageContentsView*)pageContentsView animated:(BOOL)animated
{
    
    if (pageContentsView.imageView.image == image)
        return;
    
    pageContentsView.imageView.image = image;
    
    // update the hotspot visibility
    [pageContentsView setShowHotspots:(self.showHotspots && image) animated:animated];
    
    // enable/disable zooming depending on the images being loaded
    self.zoomView.pinchGestureRecognizer.enabled = [self allImagesLoaded];
    
    // TODO: fade in if animated
    // FIXME: The little anim jump glitch when the image is set just after the layout has started animating
    // it causes a conflict with the contentInset, causing a little jump
    [self setNeedsLayout];
}

- (BOOL) anyImagesLoaded
{
    if (self.versoPageIndex != NSNotFound && self.versoPageContents.imageView.image != nil)
        return YES;
    
    if (self.rectoPageIndex != NSNotFound && self.rectoPageContents.imageView.image != nil)
        return YES;
    
    return NO;
}

- (BOOL) allImagesLoaded
{
    BOOL allLoaded = YES;
    
    if (self.versoPageIndex != NSNotFound)
        allLoaded = self.versoPageContents.imageView.image != nil;
    
    if (allLoaded && self.rectoPageIndex != NSNotFound)
        allLoaded = self.rectoPageContents.imageView.image != nil;

    return allLoaded;
}

- (NSArray*) hotspotViewsAtPoint:(CGPoint)point
{
    ETA_VersoSinglePageContentsView* pageContents = [self _pageContentsViewForSide:[self _pageSideForPoint:point]];
    
    NSArray* hotspotKeys = [pageContents hotspotKeysAtPoint:[self convertPoint:point toView:pageContents]];
    
    return [pageContents hotspotViewsForKeys:hotspotKeys];
}


- (void) setShowHotspots:(BOOL)showHotspots
{
    [self setShowHotspots:showHotspots animated:NO];
}
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated
{
    _showHotspots = showHotspots;
    
    [self.versoPageContents setShowHotspots:(showHotspots && self.versoPageContents.imageView.image) animated:animated];
    [self.rectoPageContents setShowHotspots:(showHotspots && self.rectoPageContents.imageView.image) animated:animated];
}


- (void) setHotspotRects:(NSDictionary *)hotspotRects forSide:(ETA_VersoPageSpreadSide)pageSide normalizedByWidth:(BOOL)normalizedByWidth
{
    ETA_VersoSinglePageContentsView* pageContentsView = nil;
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            pageContentsView = self.versoPageContents;
            break;
        case ETA_VersoPageSpreadSide_Recto:
            pageContentsView = self.rectoPageContents;
            break;
    }
    [self setHotspotRects:hotspotRects forPageContentsView:pageContentsView normalizedByWidth:normalizedByWidth];
}

- (void) setHotspotRects:(NSDictionary *)hotspotRects forPageContentsView:(ETA_VersoSinglePageContentsView*)pageContentsView normalizedByWidth:(BOOL)normalizedByWidth
{
    [pageContentsView clearHotspotRects];
    [pageContentsView addHotspotRects:hotspotRects];
    pageContentsView.hotspotsNormalizedByWidth = normalizedByWidth;
}









- (CGFloat) zoomScale
{
    return self.zoomView.zoomScale;
}

- (CGFloat) maximumZoomScale
{
    return self.zoomView.maximumZoomScale;
}

- (void) setMaximumZoomScale:(CGFloat)maximumZoomScale
{
    if (self.zoomView.zoomScale > maximumZoomScale)
        self.zoomView.zoomScale = maximumZoomScale;
    
    self.zoomView.maximumZoomScale = maximumZoomScale;
}








#pragma mark - Zooming delegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.pageContentsContainer;
}

-(void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    [self _updateZoomContentInsets];
    if ([self.delegate respondsToSelector:@selector(versoPageSpread:didZoom:)])
    {
        [self.delegate versoPageSpread:self didZoom:scrollView.zoomScale];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    
}

- (void) scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view
{
    if ([self.delegate respondsToSelector:@selector(versoPageSpreadWillBeginZooming:)])
    {
        [self.delegate versoPageSpreadWillBeginZooming:self];
    }
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale
{
    if ([self.delegate respondsToSelector:@selector(versoPageSpreadDidEndZooming:)])
    {
        [self.delegate versoPageSpreadDidEndZooming:self];
    }
}





#pragma mark - Tapping Actions

- (ETA_VersoSinglePageContentsView*) _pageContentsViewForSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Verso:
            return self.versoPageContents;
        case ETA_VersoPageSpreadSide_Recto:
            return self.rectoPageContents;
    }
}
- (ETA_VersoPageSpreadSide) _pageSideForPoint:(CGPoint)point
{
    
    BOOL versoVisible = self.versoPageIndex != NSNotFound;
    BOOL rectoVisible = self.rectoPageIndex != NSNotFound;
    
    ETA_VersoPageSpreadSide pageSide = ETA_VersoPageSpreadSide_Verso;
    
    // there is a visible recto side, and either there is no verso, or we are past the center point
    if (rectoVisible && (!versoVisible || (versoVisible && point.x > CGRectGetMidX(self.bounds))))
    {
        pageSide = ETA_VersoPageSpreadSide_Recto;
    }
    
    return pageSide;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // allow double-tap to happen simultaneously with other gestures
    if (gestureRecognizer == self.doubleTapGesture)
    {
        return YES;
    }
    else if (gestureRecognizer == self.tapGesture)
    {
        return YES;
    }
    else if (gestureRecognizer == self.longPressGesture)
    {
        return YES;
    }
    else if (gestureRecognizer == self.touchGesture)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}


- (void) didTouch:(UILongPressGestureRecognizer*)touch
{
    if (touch.state == UIGestureRecognizerStateBegan || touch.state == UIGestureRecognizerStateEnded || touch.state == UIGestureRecognizerStateCancelled)
    {
        
        CGPoint locationInPage = [touch locationInView:self];
        
        ETA_VersoPageSpreadSide pageSide = [self _pageSideForPoint:locationInPage];
        ETA_VersoSinglePageContentsView* pageContentsView = [self _pageContentsViewForSide:pageSide];
        
        // no touch if no image
        if (!pageContentsView.imageView.image)
            return;

        NSArray* hotspotKeys = (pageContentsView.imageView.image) ? [pageContentsView hotspotKeysAtPoint:[touch locationInView:pageContentsView]] : nil;
        
        
        if (touch.state == UIGestureRecognizerStateBegan)
        {
            if ([self.delegate respondsToSelector:@selector(versoPageSpread:didBeginTouchingAtPoint:onPageSide:hittingHotspotsWithKeys:)])
            {
                [self.delegate versoPageSpread:self didBeginTouchingAtPoint:locationInPage onPageSide:pageSide hittingHotspotsWithKeys:hotspotKeys];
            }
        }
        else if (touch.state == UIGestureRecognizerStateCancelled || touch.state == UIGestureRecognizerStateEnded)
        {
            if ([self.delegate respondsToSelector:@selector(versoPageSpread:didFinishTouchingAtPoint:onPageSide:hittingHotspotsWithKeys:)])
            {
                [self.delegate versoPageSpread:self didFinishTouchingAtPoint:locationInPage onPageSide:pageSide hittingHotspotsWithKeys:hotspotKeys];
            }
        }
    }
}

- (void) didTap:(UITapGestureRecognizer*)tap
{
    if (tap.state != UIGestureRecognizerStateEnded)
        return;

    CGPoint locationInPage = [tap locationInView:self];
    
    
    ETA_VersoPageSpreadSide pageSide = [self _pageSideForPoint:locationInPage];
    ETA_VersoSinglePageContentsView* pageContentsView = [self _pageContentsViewForSide:pageSide];
    
    // no tap if no image
    if (!pageContentsView.imageView.image)
        return;
    
    NSArray* hotspotKeys = (pageContentsView.imageView.image) ? [pageContentsView hotspotKeysAtPoint:[tap locationInView:pageContentsView]] : nil;
    
    if ([self.delegate respondsToSelector:@selector(versoPageSpread:didReceiveTapAtPoint:onPageSide:hittingHotspotsWithKeys:)])
    {
        [self.delegate versoPageSpread:self didReceiveTapAtPoint:locationInPage onPageSide:pageSide hittingHotspotsWithKeys:hotspotKeys];
    }
}

- (void) didLongPress:(UILongPressGestureRecognizer*)longPress
{
    if (longPress.state != UIGestureRecognizerStateBegan)
        return;
    
    
    CGPoint locationInPage = [longPress locationInView:self];
    
    
    ETA_VersoPageSpreadSide pageSide = [self _pageSideForPoint:locationInPage];
    ETA_VersoSinglePageContentsView* pageContentsView = [self _pageContentsViewForSide:pageSide];

    // no longpress if no image
    if (!pageContentsView.imageView.image)
        return;
    
    NSArray* hotspotKeys = [pageContentsView hotspotKeysAtPoint:[longPress locationInView:pageContentsView]];
    
    if ([self.delegate respondsToSelector:@selector(versoPageSpread:didReceiveLongPressAtPoint:onPageSide:hittingHotspotsWithKeys:)])
    {
        [self.delegate versoPageSpread:self didReceiveLongPressAtPoint:locationInPage onPageSide:pageSide hittingHotspotsWithKeys:hotspotKeys];
    }

}

- (void) didDoubleTap:(UITapGestureRecognizer*)tap
{
    if (tap.state != UIGestureRecognizerStateEnded)
        return;

    // no-op if zoom is disabled
    if (self.zoomView.pinchGestureRecognizer.enabled == NO)
        return;
    
    [self.zoomView.delegate scrollViewWillBeginZooming:self.zoomView withView:[self.zoomView.delegate viewForZoomingInScrollView:self.zoomView]];

    BOOL zoomingOut = (self.zoomView.zoomScale > self.zoomView.minimumZoomScale);
    
    void (^zoomAnimations)() = ^() {
        // zoomed in - so zoom out again
        if (zoomingOut)
        {
            [self.zoomView setZoomScale:self.zoomView.minimumZoomScale animated:NO];
        }
        // zoomed out - find the rect we want to zoom to
        else
        {
            CGFloat newScale = self.zoomView.maximumZoomScale;
            
            //TODO: if doubletap is over a hotspot, get the rect of the hotspot.
            
            // otherwise, just zoom to the rect
            CGRect zoomRect = [self _zoomRectForScale:newScale withCenter:[tap locationInView:self.zoomView]];
            [self.zoomView zoomToRect:zoomRect animated:NO];
        }
    };
    
    void (^zoomCompletion)(BOOL) = ^(BOOL finished) {
        [self.zoomView.delegate scrollViewDidEndZooming:self.zoomView withView:[self.zoomView.delegate viewForZoomingInScrollView:self.zoomView]  atScale:self.zoomView.zoomScale];
    };
    
    //ios 7 bouncy anim, if available
#ifdef NSFoundationVersionNumber_iOS_6_1
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        NSTimeInterval duration = zoomingOut ? 0.30 : 0.40;
        CGFloat damping = zoomingOut ? 0.9 : 0.8;
        CGFloat initialVelocity = zoomingOut ? 0.9 : 0.75;
        [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:damping initialSpringVelocity:initialVelocity options:UIViewAnimationOptionBeginFromCurrentState animations:zoomAnimations completion:zoomCompletion];
    }
    else
#endif
    {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:zoomAnimations completion:zoomCompletion];
    }
    
    
}


- (CGRect) _zoomRectForScale:(CGFloat)scale withCenter:(CGPoint)center
{
    CGRect zoomRect;
    
    UIView* zoomView = [self viewForZoomingInScrollView:self.zoomView];
    
    zoomRect.size.height = zoomView.frame.size.height / scale;
    zoomRect.size.width  = zoomView.frame.size.width / scale;
    
    center = [zoomView convertPoint:center fromView:self.zoomView];
    
    zoomRect.origin.x = center.x - ((zoomRect.size.width / 2.0));
    zoomRect.origin.y =  center.y - ((zoomRect.size.height / 2.0));
    
    return zoomRect;
}








#pragma mark - Views

- (UIScrollView*) zoomView
{
    if (!_zoomView)
    {
        _zoomView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _zoomView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _zoomView.maximumZoomScale = 4.0;
        _zoomView.delegate = self;
//        _zoomView.backgroundColor = [UIColor colorWithRed:1 green:0 blue:1 alpha:0.5];
    }
    return _zoomView;
}


- (UIView*) pageContentsContainer
{
    if (!_pageContentsContainer)
    {
        _pageContentsContainer = [UIView new];
//        _pageContentsContainer.backgroundColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.1];
    }
    return _pageContentsContainer;
}

- (ETA_VersoSinglePageContentsView*) versoPageContents
{
    if (!_versoPageContents)
    {
        _versoPageContents = [ETA_VersoSinglePageContentsView new];
//        _versoPageContents.backgroundColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.1];
    }
    return _versoPageContents;
}
- (ETA_VersoSinglePageContentsView*) rectoPageContents
{
    if (!_rectoPageContents)
    {
        _rectoPageContents = [ETA_VersoSinglePageContentsView new];
//        _rectoPageContents.backgroundColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.1];
    }
    return _rectoPageContents;
}

@end
