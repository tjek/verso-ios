//
//  ETA_VersoPageSpreadCell.m
//  Verso
//
//  Created by Laurie Hufford on 04/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_VersoPageSpreadCell.h"

#import "ETA_VersoSinglePageContentsView.h"


@interface ETA_VersoPageSpreadCell () <UIScrollViewDelegate>

@property (nonatomic, assign) BOOL isPrimaryImageZoom;
@property (nonatomic, assign) NSInteger primaryPageIndex;
@property (nonatomic, assign) BOOL isSecondaryImageZoom;
@property (nonatomic, assign) NSInteger secondaryPageIndex;


@property (nonatomic, strong) UIScrollView* zoomView;

@property (nonatomic, strong) UIView* pageContentsContainer;

@property (nonatomic, strong) ETA_VersoSinglePageContentsView* primaryPageContents;
@property (nonatomic, strong) ETA_VersoSinglePageContentsView* secondaryPageContents;

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
        _singlePageMode = NO;
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
    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.contentView addGestureRecognizer:doubleTap];
    
    UILongPressGestureRecognizer* longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
    [self.contentView addGestureRecognizer:longPress];
    
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    [tap requireGestureRecognizerToFail:doubleTap];
    [self.contentView addGestureRecognizer:tap];
    
    
    
    [self.pageContentsContainer addSubview:self.secondaryPageContents];
    [self.pageContentsContainer addSubview:self.primaryPageContents];
    
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
    
    _showHotspots = NO;
    
    _primaryPageIndex = -1;
    [self.primaryPageContents clearHotspotRects];
    [self setImage:nil isZoomImage:NO forSide:ETA_VersoPageSpreadSide_Primary animated:NO];
    
    _secondaryPageIndex = -1;
    [self.secondaryPageContents clearHotspotRects];
    [self setImage:nil isZoomImage:NO forSide:ETA_VersoPageSpreadSide_Secondary animated:NO];
    
    [self setNeedsLayout];
}






#pragma mark - Layout

- (void) layoutSubviews
{
    [super layoutSubviews];
    
    CGRect readerBounds = self.contentView.bounds;
    
    BOOL singlePageMode = self.singlePageMode;
    BOOL fitToWidth = self.fitToWidth;

    // calculate the max size for a single page image
    CGSize maxPageSize = readerBounds.size;
    if (!singlePageMode)
        maxPageSize.width = ceil(maxPageSize.width / 2);
    
    if (fitToWidth)
        maxPageSize.height = UIViewNoIntrinsicMetric;
    
    
    
    CGRect containerFrame = CGRectZero;
    
    CGRect primaryFrame = (CGRect){
        .origin = CGPointZero,
        .size = [self.primaryPageContents sizeThatFits:maxPageSize]
    };
    CGRect secondaryFrame = CGRectZero;
    
    
    if (singlePageMode)
    {
        // scale the secondary page down a bit, so that when it appears it zooms in
        CGFloat hiddenScaleFactor = 0.5;
        secondaryFrame.size = (CGSize) {
            .width = primaryFrame.size.width * hiddenScaleFactor,
            .height = primaryFrame.size.width * hiddenScaleFactor
        };
    }
    else
    {
        secondaryFrame.size = [self.secondaryPageContents sizeThatFits:maxPageSize];
    }
    
    
    // fit container to the contents
    containerFrame.size = primaryFrame.size;
    
    if (singlePageMode == NO)
    {
        // position secondary to the right of primary (-1 to avoid flickering subpixel spine)
        secondaryFrame.origin.x = floor(CGRectGetMaxX(primaryFrame)-1);
        
        // increase the container size to fit the second page, if visible
        containerFrame.size.height = MAX(containerFrame.size.height, secondaryFrame.size.height);
        containerFrame.size.width = CGRectGetMaxX(secondaryFrame);
        
    }
    
    
    // center both pages vertically
    primaryFrame.origin.y = MAX(0, (containerFrame.size.height / 2) - (primaryFrame.size.height / 2));
    secondaryFrame.origin.y = MAX(0, (containerFrame.size.height / 2) - (secondaryFrame.size.height / 2));
    

    CGFloat zoomScale = self.zoomView.zoomScale;
    
    // scale the container to match the zoomscale
    containerFrame.size.height *= zoomScale;
    containerFrame.size.width *= zoomScale;

    
    self.zoomView.contentSize = containerFrame.size;
 
    self.pageContentsContainer.frame = containerFrame;
    self.primaryPageContents.frame = primaryFrame;
    self.secondaryPageContents.frame = secondaryFrame;
    
    
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

- (void) setSinglePageMode:(BOOL)singlePageMode
{
    [self setSinglePageMode:singlePageMode animated:NO];
}

- (void) setSinglePageMode:(BOOL)singlePageMode animated:(BOOL)animated
{
    if (_singlePageMode == singlePageMode)
        return;
    
    _singlePageMode = singlePageMode;
    
    
    
    BOOL wereAnimationsEnabled = [UIView areAnimationsEnabled];
    
    // zoom out of the view
    [self.zoomView setZoomScale:self.zoomView.minimumZoomScale animated:animated];
    
    
    [self setNeedsLayout];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        [UIView setAnimationsEnabled:animated];
        
        self.secondaryPageContents.alpha = singlePageMode ? 0 : 1;
        
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
    [UIView animateWithDuration:0.3 animations:^{
        
        [UIView setAnimationsEnabled:animated];
        
        [self layoutIfNeeded];
        
        [UIView setAnimationsEnabled:wereAnimationsEnabled];
    }];
}





#pragma mark - Page Side properties

- (void) setPageIndex:(NSInteger)pageIndex forSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Primary:
        {
            self.primaryPageIndex = pageIndex;
            break;
        }
        case ETA_VersoPageSpreadSide_Secondary:
        {
            self.secondaryPageIndex = pageIndex;
            break;
        }
    }
}
- (NSInteger) pageIndexForSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Primary:
            return self.primaryPageIndex;
        case ETA_VersoPageSpreadSide_Secondary:
            return self.secondaryPageIndex;
    }
}

- (BOOL) isShowingZoomImageForSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Primary:
            return self.isPrimaryImageZoom;
        case ETA_VersoPageSpreadSide_Secondary:
            return self.isSecondaryImageZoom;
    }
}

- (void) setIsShowingZoomImage:(BOOL)isShowingZoomImage forSide:(ETA_VersoPageSpreadSide)pageSide
{
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Primary:
            self.isPrimaryImageZoom = isShowingZoomImage;
            break;
        case ETA_VersoPageSpreadSide_Secondary:
            self.isSecondaryImageZoom = isShowingZoomImage;
            break;
    }
}

- (void) setPageNumberLabelText:(NSAttributedString*)text color:(UIColor*)color forSide:(ETA_VersoPageSpreadSide)pageSide
{
    ETA_VersoSinglePageContentsView* pageContentsView = nil;
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Primary:
            pageContentsView = self.primaryPageContents;
            break;
        case ETA_VersoPageSpreadSide_Secondary:
            pageContentsView = self.secondaryPageContents;
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
        case ETA_VersoPageSpreadSide_Primary:
            pageContentsView = self.primaryPageContents;
            break;
        case ETA_VersoPageSpreadSide_Secondary:
            pageContentsView = self.secondaryPageContents;
            break;
    }
    
    [self setImage:image forPageContentsView:pageContentsView animated:animated];
}
- (void) setImage:(UIImage *)image forPageContentsView:(ETA_VersoSinglePageContentsView*)pageContentsView animated:(BOOL)animated
{
    // TODO: fade in if animated
    //        [UIView transitionWithView:self.primaryPageContents.imageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
    //
    //            self.primaryPageContents.imageView.image = image;
    //
    //        } completion:nil];

    
    pageContentsView.imageView.image = image;
    
    // update the hotspot visibility
    [pageContentsView setShowHotspots:(self.showHotspots && image) animated:animated];
    
    [self setNeedsLayout];
}

- (BOOL) anyImagesLoaded
{
    return self.primaryPageContents.imageView.image != nil || self.secondaryPageContents.imageView.image != nil;
}

- (BOOL) allImagesLoaded
{
    BOOL allLoaded = self.primaryPageContents.imageView.image != nil;
    if (allLoaded && self.singlePageMode == NO)
    {
        allLoaded = allLoaded && self.secondaryPageContents.imageView.image != nil;
    }
    return allLoaded;
}

- (void) setShowHotspots:(BOOL)showHotspots
{
    [self setShowHotspots:showHotspots animated:NO];
}
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated
{
    _showHotspots = showHotspots;
    
    [self.primaryPageContents setShowHotspots:(showHotspots && self.primaryPageContents.imageView.image) animated:animated];
    [self.secondaryPageContents setShowHotspots:(showHotspots && self.secondaryPageContents.imageView.image) animated:animated];
}


- (void) setHotspotRects:(NSDictionary *)hotspotRects forSide:(ETA_VersoPageSpreadSide)pageSide normalizedByWidth:(BOOL)normalizedByWidth
{
    ETA_VersoSinglePageContentsView* pageContentsView = nil;
    switch (pageSide) {
        case ETA_VersoPageSpreadSide_Primary:
            pageContentsView = self.primaryPageContents;
            break;
        case ETA_VersoPageSpreadSide_Secondary:
            pageContentsView = self.secondaryPageContents;
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
        case ETA_VersoPageSpreadSide_Primary:
            return self.primaryPageContents;
        case ETA_VersoPageSpreadSide_Secondary:
            return self.secondaryPageContents;
    }
}
- (ETA_VersoPageSpreadSide) _pageSideForPoint:(CGPoint)point
{
    ETA_VersoPageSpreadSide pageSide = ETA_VersoPageSpreadSide_Primary;
    if (self.singlePageMode == NO && point.x > CGRectGetMidX(self.bounds))
    {
        pageSide = ETA_VersoPageSpreadSide_Secondary;
    }
    return pageSide;
}

- (void) didTap:(UITapGestureRecognizer*)tap
{
    if (tap.state != UIGestureRecognizerStateEnded)
        return;

    CGPoint locationInPage = [tap locationInView:self];
    
    
    ETA_VersoPageSpreadSide pageSide = [self _pageSideForPoint:locationInPage];
    ETA_VersoSinglePageContentsView* pageContentsView = [self _pageContentsViewForSide:pageSide];
    
    NSArray* hotspotKeys = [pageContentsView hotspotKeysAtPoint:[tap locationInView:pageContentsView]];
    
    if ([self.delegate respondsToSelector:@selector(versoPageSpread:didReceiveTapAtPoint:onPageSide:hittingHotspotsWithKeys:)])
    {
        [self.delegate versoPageSpread:self didReceiveTapAtPoint:locationInPage onPageSide:pageSide hittingHotspotsWithKeys:hotspotKeys];
    }
}

- (void) didLongPress:(UITapGestureRecognizer*)tap
{
    if (tap.state != UIGestureRecognizerStateBegan)
        return;
    
    
    CGPoint locationInPage = [tap locationInView:self];
    
    
    ETA_VersoPageSpreadSide pageSide = [self _pageSideForPoint:locationInPage];
    ETA_VersoSinglePageContentsView* pageContentsView = [self _pageContentsViewForSide:pageSide];
    
    NSArray* hotspotKeys = [pageContentsView hotspotKeysAtPoint:[tap locationInView:pageContentsView]];
    
    if ([self.delegate respondsToSelector:@selector(versoPageSpread:didReceiveLongPressAtPoint:onPageSide:hittingHotspotsWithKeys:)])
    {
        [self.delegate versoPageSpread:self didReceiveLongPressAtPoint:locationInPage onPageSide:pageSide hittingHotspotsWithKeys:hotspotKeys];
    }

}

- (void) didDoubleTap:(UITapGestureRecognizer*)tap
{
    if (tap.state != UIGestureRecognizerStateEnded)
        return;

    // zoomed in - so zoom out again
    if (self.zoomView.zoomScale > self.zoomView.minimumZoomScale)
    {
        [self.zoomView setZoomScale:self.zoomView.minimumZoomScale animated:YES];
    }
    // zoomed out - find the rect we want to zoom to
    else
    {
        CGFloat newScale = self.zoomView.maximumZoomScale;
        
        //TODO: if doubletap is over a hotspot, get the rect of the hotspot.

        // otherwise, just zoom to the rect
        CGRect zoomRect = [self _zoomRectForScale:newScale withCenter:[tap locationInView:self.zoomView]];
        [self.zoomView zoomToRect:zoomRect animated:YES];
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
    }
    return _pageContentsContainer;
}

- (ETA_VersoSinglePageContentsView*) primaryPageContents
{
    if (!_primaryPageContents)
    {
        _primaryPageContents = [ETA_VersoSinglePageContentsView new];
    }
    return _primaryPageContents;
}
- (ETA_VersoSinglePageContentsView*) secondaryPageContents
{
    if (!_secondaryPageContents)
    {
        _secondaryPageContents = [ETA_VersoSinglePageContentsView new];
    }
    return _secondaryPageContents;
}

@end
