//
//  ETA_VersoPagedView.m
//  Verso
//
//  Created by Laurie Hufford on 04/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import "ETA_VersoPagedView.h"

// Views
#import "ETA_VersoPageSpreadCell.h"

// Utilities
#import <SDWebImage/SDWebImageManager.h>
#import "ETA_VersoHorizontalLayout.h"

@interface ETA_VersoPagedView () <UICollectionViewDelegate, UICollectionViewDataSource, ETA_VersoPageSpreadCellDelegate>


@property (nonatomic, assign) NSUInteger numberOfPages; // updated from the datasource when the pages are reloaded
@property (nonatomic, assign) NSUInteger numberOfItems; // based on number of pages, and the single page mode

@property (nonatomic, strong) NSIndexPath* currentIndexPath; // the indexPath of the currently visible item

@property (nonatomic, assign) NSRange visiblePageIndexRange; // the visible range, based on currentIndex and singlePageMode
@property (nonatomic, assign) CGFloat pageProgress;

@property (nonatomic, strong) UICollectionView* collectionView;

@property (nonatomic, strong) SDWebImageManager* cachedImageDownloader;

@property (nonatomic, strong) UIView* outroView;

@end

@implementation ETA_VersoPagedView

static NSString* const kVersoPageSpreadCellIdentifier = @"kVersoPageSpreadCellIdentifier";

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self _commonVersoPagedViewInit];
    }
    return self;
}
- (instancetype) initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self _commonVersoPagedViewInit];
    }
    return self;
}

- (void) _commonVersoPagedViewInit
{
    _currentPageIndex = 0;
    _numberOfPages = 0;
    _singlePageMode = YES;
    
    [self addSubviews];
}

- (void)addSubviews
{
    [self addSubview:self.collectionView];
}

- (void) layoutSubviews
{
    // invalidate the layout before re-laying out the collection view (to avoid incorrect item size errors)
    [self.collectionView.collectionViewLayout invalidateLayout];
    
    [super layoutSubviews];
    
    // move back to the visible item
    [self.collectionView scrollToItemAtIndexPath:self.currentIndexPath atScrollPosition:UICollectionViewScrollPositionLeft | UICollectionViewScrollPositionTop animated:NO];
}

- (void) didMoveToSuperview
{
    [super didMoveToSuperview];
    
    [self reloadPages];
}


- (void) dealloc
{
    _collectionView.delegate = nil;
    _collectionView.dataSource = nil;
    _delegate = nil;
    _dataSource = nil;
}




#pragma mark - Page Count



- (void) reloadPages
{
//    NSLog(@"Reload Pages");
    
    [self _updateNumberOfPagesAndItems];
    
    // update the outro view
    [self.outroView removeFromSuperview];
    
    if ([self.delegate respondsToSelector:@selector(outroViewForVersoPagedView:)])
        self.outroView = [self.delegate outroViewForVersoPagedView:self];
    else
        self.outroView = nil;
    
    
    [self.collectionView reloadData];
    
    [self _updateCurrentIndexPathAndScrollThere:YES animated:NO];
    
    self.collectionView.scrollEnabled = YES;
    
    //TODO: animate the single page mode property on the
}


- (void) _updateNumberOfPagesAndItems
{
    NSUInteger numberOfPages = 0;
    if ([self.dataSource respondsToSelector:@selector(numberOfPagesInVersoPagedView:)])
    {
        numberOfPages = [self.dataSource numberOfPagesInVersoPagedView:self];
    }
    
    self.numberOfPages = numberOfPages;
    
    
    // update number of items
    NSUInteger numberOfItems = numberOfPages;
    if (!self.singlePageMode && numberOfPages != 0)
    {
        // round down to the even page count, and subtract 1
        numberOfItems = (numberOfPages-(numberOfPages%2) + 2) / 2;
    }
    self.numberOfItems = numberOfItems;
}


- (void) goToPageIndex:(NSInteger)pageIndex animated:(BOOL)animated
{
    // clamp pageIndex
    pageIndex = MAX(0, pageIndex);
    pageIndex = MIN(pageIndex, MAX(0, (NSInteger)self.numberOfPages-1));

    _currentPageIndex = pageIndex;
    
    [self _updateCurrentIndexPathAndScrollThere:YES animated:animated];
}


- (void) _updateCurrentIndexPathAndScrollThere:(BOOL)scroll animated:(BOOL)animated
{
    NSIndexPath* prevIndexPath = self.currentIndexPath;
    self.currentIndexPath = [self _indexPathForPageIndex:self.currentPageIndex];
    
    if (scroll && self.currentIndexPath && (!prevIndexPath || [prevIndexPath compare:self.currentIndexPath] != NSOrderedSame))
    {
//        NSLog(@"Scrolling");
        //TODO: avoid fetching images while animating scroll
        [self.collectionView scrollToItemAtIndexPath:self.currentIndexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically | UICollectionViewScrollPositionCenteredHorizontally animated:animated];
    }
}

- (void) setCurrentIndexPath:(NSIndexPath *)currentIndexPath
{
    _currentIndexPath = currentIndexPath;
    
    
    // update the visible range
    NSRange prevRange = self.visiblePageIndexRange;
    
    self.visiblePageIndexRange = ({
        NSUInteger rangeLength = 0;
        NSUInteger rangeStart = 0;
        if (_currentIndexPath)
        {
            NSUInteger firstPageIndex = [self _firstPageIndexForIndexPath:_currentIndexPath];
            NSUInteger lastPageIndex = [self _lastPageIndexForIndexPath:_currentIndexPath];
            rangeLength = (lastPageIndex - firstPageIndex) + 1;
            rangeStart = firstPageIndex;
        }
        NSMakeRange(rangeStart, rangeLength);
    });
    
    [self _updatePageProgress];
    
    // no change, dont update the page range
    if (prevRange.location == self.visiblePageIndexRange.location && prevRange.length == self.visiblePageIndexRange.length)
        return;
    
    [self didChangeVisiblePageIndexRangeFrom:prevRange];
}

- (void) _updatePageProgress
{
    CGFloat percentageComplete = 0;
    CGFloat numberOfPages = self.numberOfPages;
    if (numberOfPages == 1)
    {
        percentageComplete = 1.0;
    }
    else if (numberOfPages > 1)
    {
        NSUInteger lastVisiblePageIndex = self.visiblePageIndexRange.location + self.visiblePageIndexRange.length - 1;
        
        percentageComplete = (CGFloat)(lastVisiblePageIndex) / (CGFloat)(numberOfPages - 1);
    }

    self.pageProgress = percentageComplete;
}


- (void) setShowHotspots:(BOOL)showHotspots
{
    [self setShowHotspots:showHotspots animated:NO];
}
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated
{
    _showHotspots = showHotspots;
    
    ETA_VersoPageSpreadCell* pageSpread = (ETA_VersoPageSpreadCell*)[self.collectionView cellForItemAtIndexPath:self.currentIndexPath];
    [pageSpread setShowHotspots:showHotspots animated:animated];
}


#pragma mark - Delegate methods

- (void) startedChangingVisiblePageIndexRange
{
    if ([self.delegate respondsToSelector:@selector(versoPagedViewStartedChangingVisiblePageIndexRange:)])
    {
        [self.delegate versoPagedViewStartedChangingVisiblePageIndexRange:self];
    }
}

- (void) didChangeVisiblePageIndexRangeFrom:(NSRange)prevRange
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didChangeVisiblePageIndexRangeFrom:)])
    {
        [self.delegate versoPagedView:self didChangeVisiblePageIndexRangeFrom:prevRange];
    }
    
    
    // do the prefetching around the newly visible page
    NSUInteger pagesAheadToPrefetch = 3;
    NSUInteger startPrefetchAfterIndex = self.visiblePageIndexRange.location + self.visiblePageIndexRange.length - 1;
    if ([self.delegate respondsToSelector:@selector(versoPagedView:numberOfPagesAheadToPrefetch:)])
    {
        pagesAheadToPrefetch = [self.delegate versoPagedView:self numberOfPagesAheadToPrefetch:startPrefetchAfterIndex];
    }
    
    if (pagesAheadToPrefetch > 0)
    {
        [self _prefetchViewImagesAroundIndex:startPrefetchAfterIndex pagesBefore:0 pagesAfter:pagesAheadToPrefetch];
    }
}

- (void) didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didTapLocation:onPageIndex:hittingHotspotsWithKeys:)])
    {
        [self.delegate versoPagedView:self didTapLocation:tapLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
    }
}

- (void) didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didLongPressLocation:onPageIndex:hittingHotspotsWithKeys:)])
    {
        [self.delegate versoPagedView:self didLongPressLocation:longPressLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
    }
}

- (void) didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didSetImage:isZoomImage:onPageIndex:)])
    {
        [self.delegate versoPagedView:self didSetImage:image isZoomImage:isZoomImage onPageIndex:pageIndex];
    }
}

- (void) willBeginZooming:(CGFloat)zoomScale
{

}
- (void) didZoom:(CGFloat)zoomScale
{

}
- (void) didEndZooming:(CGFloat)zoomScale
{
    
}

- (NSAttributedString*) pageNumberLabelStringForPageIndex:(NSUInteger)pageIndex
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:pageNumberLabelStringForPageIndex:)])
    {
        return [self.delegate versoPagedView:self pageNumberLabelStringForPageIndex:pageIndex];
    }
    else
    {
        return [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", @(pageIndex+1)]];
    }
}

- (UIColor*) pageNumberLabelColorForPageIndex:(NSUInteger)pageIndex
{
    UIColor* color = nil;
    if ([self.delegate respondsToSelector:@selector(versoPagedView:pageNumberLabelColorForPageIndex:)])
    {
        color = [self.delegate versoPagedView:self pageNumberLabelColorForPageIndex:pageIndex];
    }
    if (!color)
        color = [UIColor blackColor];
    
    return color;
}

- (CGFloat) outroWidth
{
    CGFloat width = UIViewNoIntrinsicMetric;
    if ([self.delegate respondsToSelector:@selector(outroWidthForVersoPagedView:)])
    {
        width = [self.delegate outroWidthForVersoPagedView:self];
    }
    return width;
}

#pragma mark - Datasource methods

- (NSURL*) imageURLForPageIndex:(NSUInteger)pageIndex withMaxSize:(CGSize)maxPageSize isZoomImage:(BOOL)zoomImage
{
    NSURL* url = nil;
    
    if ([self.dataSource respondsToSelector:@selector(versoPagedView:imageURLForPageIndex:withMaxSize:isZoomImage:)])
    {
        url = [self.dataSource versoPagedView:self imageURLForPageIndex:pageIndex withMaxSize:maxPageSize isZoomImage:zoomImage];
    }

    return url;
}

- (NSDictionary*) hotspotRectsForPageIndex:(NSUInteger)pageIndex
{
    NSDictionary* hotspotRects = nil;
    if ([self.dataSource respondsToSelector:@selector(versoPagedView:hotspotRectsForPageIndex:)])
    {
        hotspotRects = [self.dataSource versoPagedView:self hotspotRectsForPageIndex:pageIndex];
    }
    
    return hotspotRects;
}

- (BOOL) hotspotsNormalizedByWidthForPageIndex:(NSUInteger)pageIndex
{
    BOOL hotspotsNormalizedByWidth = NO;
    if ([self.dataSource respondsToSelector:@selector(versoPagedView:hotspotRectsNormalizedByWidthForPageIndex:)])
    {
        hotspotsNormalizedByWidth = [self.dataSource versoPagedView:self hotspotRectsNormalizedByWidthForPageIndex:pageIndex];
    }
    return hotspotsNormalizedByWidth;
}



#pragma mark - Page Spread Delegate

- (void) versoPageSpreadWillBeginZooming:(ETA_VersoPageSpreadCell *)pageView
{
    [self willBeginZooming:pageView.zoomScale];
}

// finished zooming - start loading the zoomed-in image
- (void) versoPageSpreadDidEndZooming:(ETA_VersoPageSpreadCell *)pageView
{
    // dont allow page scrolling when zoomed in
    BOOL enablePaging = pageView.zoomScale <= 1.05;
    if (self.collectionView.scrollEnabled != enablePaging)
    {
//        NSLog(@"Paging %@", enablePaging ? @"Enabled" : @"Disabled");
        self.collectionView.scrollEnabled = enablePaging;
    }
    
    [self didEndZooming:pageView.zoomScale];
    
    if (pageView.zoomScale <= 1.0)
        return;
    
    NSIndexPath* indexPath = [self.collectionView indexPathForCell:pageView];
    if (!indexPath)
        return;


    [self _startFetchingImagesForPageView:pageView atIndexPath:indexPath zoomImage:YES];
}

- (void) versoPageSpread:(ETA_VersoPageSpreadCell *)pageView didZoom:(CGFloat)zoomScale
{
    [self didZoom:zoomScale];
}


- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didReceiveTapAtPoint:(CGPoint)locationInPageView onPageSide:(ETA_VersoPageSpreadSide)pageSide hittingHotspotsWithKeys:(NSArray *)hotspotKeys
{
    NSInteger pageIndex = [pageSpreadCell pageIndexForSide:pageSide];
    if (pageIndex < 0)
        return;
    
    CGPoint locationInReader = [self convertPoint:locationInPageView fromView:pageSpreadCell];

    [self didTapLocation:locationInReader onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
}

- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didReceiveLongPressAtPoint:(CGPoint)locationInPageView onPageSide:(ETA_VersoPageSpreadSide)pageSide hittingHotspotsWithKeys:(NSArray *)hotspotKeys
{
    NSInteger pageIndex = [pageSpreadCell pageIndexForSide:pageSide];
    if (pageIndex < 0)
        return;
    
    CGPoint locationInReader = [self convertPoint:locationInPageView fromView:pageSpreadCell];
    
    [self didLongPressLocation:locationInReader onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
}



#pragma mark - Page View initialization

// update a pageView to show the pages at indexPath
- (void) _preparePageView:(ETA_VersoPageSpreadCell*)pageView atIndexPath:(NSIndexPath*)indexPath
{
    NSUInteger firstPageIndex = [self _firstPageIndexForIndexPath:indexPath];
    NSUInteger lastPageIndex = [self _lastPageIndexForIndexPath:indexPath];
 
//    BOOL isVisible = firstPageIndex == self.currentPageIndex || lastPageIndex == self.currentPageIndex;
    
    BOOL animated = NO;
    
    BOOL singlePageMode = firstPageIndex == lastPageIndex;
    BOOL fitToWidth = NO;
    BOOL showHotspots = self.showHotspots;
    
//    if (singlePageMode)
//        NSLog(@"Prepare PageView %tu (%@) - item:%tu", firstPageIndex, isVisible?@"Visible":@"Hidden", indexPath.item);
//    else
//        NSLog(@"Prepare PageView %tu-%tu (%@) - item:%tu", firstPageIndex, lastPageIndex, isVisible?@"Visible":@"Hidden", indexPath.item);
    
    // make sure that the zoomview's panning doesnt block the collectionViews panning (we disable the collection view's scrolling when we are zoomed in)
    [pageView.zoomView.panGestureRecognizer requireGestureRecognizerToFail:self.collectionView.panGestureRecognizer];    
    [pageView.contentView.gestureRecognizers enumerateObjectsUsingBlock:^(UIGestureRecognizer* gesture, NSUInteger idx, BOOL *stop) {
        [gesture requireGestureRecognizerToFail:self.collectionView.panGestureRecognizer];
    }];
    
    [pageView setShowHotspots:showHotspots animated:animated];
    [pageView setHotspotRects:[self hotspotRectsForPageIndex:firstPageIndex] forSide:ETA_VersoPageSpreadSide_Primary normalizedByWidth:[self hotspotsNormalizedByWidthForPageIndex:firstPageIndex]];
    [pageView setPageIndex:firstPageIndex forSide:ETA_VersoPageSpreadSide_Primary];

    [pageView setPageNumberLabelText:[self pageNumberLabelStringForPageIndex:firstPageIndex]
                               color:[self pageNumberLabelColorForPageIndex:firstPageIndex]
                             forSide:ETA_VersoPageSpreadSide_Primary];
    
    if (!singlePageMode)
    {
        [pageView setPageIndex:lastPageIndex forSide:ETA_VersoPageSpreadSide_Secondary];
        [pageView setHotspotRects:[self hotspotRectsForPageIndex:lastPageIndex] forSide: ETA_VersoPageSpreadSide_Secondary normalizedByWidth:[self hotspotsNormalizedByWidthForPageIndex:lastPageIndex]];
        
        [pageView setPageNumberLabelText:[self pageNumberLabelStringForPageIndex:lastPageIndex]
                                   color:[self pageNumberLabelColorForPageIndex:lastPageIndex]
                                 forSide:ETA_VersoPageSpreadSide_Secondary];
    }
    
    
    [pageView setSinglePageMode:singlePageMode animated:animated];
    [pageView setFitToWidth:fitToWidth animated:animated];
    
    [self _startFetchingImagesForPageView:pageView atIndexPath:indexPath zoomImage:NO];
    
    pageView.delegate = self;
}


- (void) _updateImage:(UIImage*)image forPageView:(ETA_VersoPageSpreadCell*)pageView atPageIndex:(NSUInteger)pageIndex isZoomImage:(BOOL)isZoomImage
{
    if (!pageView)
    {
        NSIndexPath* indexPath = [self _indexPathForPageIndex:pageIndex];
        pageView = (ETA_VersoPageSpreadCell*)[self.collectionView cellForItemAtIndexPath:indexPath];
        if (!pageView)
        {
            //            NSLog(@"[ImgDL] Page %tu No Pageview to update", pageIndex);
            return;
        }
    }
    
    // get the page side for the page index
    ETA_VersoPageSpreadSide pageSide;
    if ([pageView pageIndexForSide:ETA_VersoPageSpreadSide_Primary] == pageIndex)
    {
        pageSide = ETA_VersoPageSpreadSide_Primary;
    }
    else if ([pageView pageIndexForSide:ETA_VersoPageSpreadSide_Secondary] == pageIndex)
    {
        pageSide = ETA_VersoPageSpreadSide_Secondary;
    }
    else
    {
        // wasnt on either page - the page indexes of the pageView have changed
        return;
    }
    
    // TODO: only animate if no image, or setting zoom image
    BOOL animated = YES;
    
    // update the image, but dont if the image is the view image and we are already showing the zoom image
    if (isZoomImage || ![pageView isShowingZoomImageForSide:pageSide])
    {
        [pageView setImage:image isZoomImage:isZoomImage forSide:pageSide animated:animated];
        
        [self didSetImage:image isZoomImage:isZoomImage onPageIndex:pageIndex];
    }
}





#pragma mark - Page <-> Collection Conversions

- (void) setSinglePageMode:(BOOL)singlePageMode
{
    [self setSinglePageMode:singlePageMode animated:NO];
}
- (void) setSinglePageMode:(BOOL)singlePageMode animated:(BOOL)animated
{
    if (_singlePageMode == singlePageMode)
        return;
    
    _singlePageMode = singlePageMode;
    
    [self reloadPages];
}


- (BOOL) _showTwoPagesForIndexPath:(NSIndexPath*)indexPath
{
    if (self.singlePageMode)
    {
        return NO;
    }
    
    // first page - always single
    if (indexPath.item == 0)
    {
        return NO;
    }
    
    NSUInteger pageCount = [self numberOfPages];
    // even numbered list of pages
    if (pageCount % 2 == 0)
    {
        // and it's the last item
        NSUInteger itemCount = self.numberOfItems;
        if (indexPath.item == itemCount-1)
            return NO;
    }
        
    return YES;
}



- (NSIndexPath*) _indexPathForPageIndex:(NSUInteger)pageIndex
{
    NSInteger itemIndex = pageIndex;
    NSInteger sectionIndex = 0;
    
    if (!self.singlePageMode)
    {
        // round up to the even page index (0->0, 1->2, 2->2, 3->4 ...), and halve
        itemIndex = (pageIndex + (pageIndex % 2)) / 2.0;
    }

    if (itemIndex >= self.numberOfItems)
        return nil;
    else
        return [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
}

- (NSUInteger) _firstPageIndexForIndexPath:(NSIndexPath*)indexPath
{
    if (!self.singlePageMode)
    {
        NSInteger lastPageIndex = (indexPath.item * 2);
        
        return MAX(lastPageIndex-1, 0);
    }
    else
    {
        return indexPath.item;
    }
}

- (NSUInteger) _lastPageIndexForIndexPath:(NSIndexPath*)indexPath
{
    if (!self.singlePageMode)
    {
        NSInteger lastPageIndex = (indexPath.item * 2);
        NSInteger pageCount = [self numberOfPages];
        
        return MIN(lastPageIndex, MAX(pageCount-1, 0));
    }
    else
    {
        return indexPath.item;
    }
}


#pragma mark - Collection View

- (UICollectionView*) collectionView
{
    if (!_collectionView)
    {
        ETA_VersoHorizontalLayout* layout = [ETA_VersoHorizontalLayout new];
        
        _collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:layout];
        
        _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [_collectionView registerClass:ETA_VersoPageSpreadCell.class forCellWithReuseIdentifier:kVersoPageSpreadCellIdentifier];
        [_collectionView registerClass:UICollectionReusableView.class forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"OutroContainerView"];
        
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        
        _collectionView.pagingEnabled = YES;
        _collectionView.backgroundColor = [UIColor clearColor];
    }
    return _collectionView;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.numberOfItems;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ETA_VersoPageSpreadCell* pageView = [collectionView dequeueReusableCellWithReuseIdentifier:kVersoPageSpreadCellIdentifier forIndexPath:indexPath];
    
    [self _preparePageView:pageView atIndexPath:indexPath];
    
    // Possible fix to locked scrolling after zoom (though doesnt seem to work
//    [self.collectionView addGestureRecognizer:pageView.zoomView.pinchGestureRecognizer];
//    [self.collectionView addGestureRecognizer:pageView.zoomView.panGestureRecognizer];

    return pageView;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
}
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
//    ETA_VersoPageSpreadCell* pageView = (ETA_VersoPageSpreadCell*)cell;
//    [self.collectionView removeGestureRecognizer:pageView.zoomView.pinchGestureRecognizer];
//    [self.collectionView removeGestureRecognizer:pageView.zoomView.panGestureRecognizer];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if (!self.outroView)
        return CGSizeZero;
    
    return CGSizeMake([self outroWidth], UIViewNoIntrinsicMetric);
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *reusableview = nil;
    
    if (kind == UICollectionElementKindSectionFooter)
    {
        reusableview = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"OutroContainerView" forIndexPath:indexPath];
        
        self.outroView.frame = reusableview.bounds;
        self.outroView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [reusableview addSubview:self.outroView];
    }
    
    return reusableview;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    
}
- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self startedChangingVisiblePageIndexRange];
}
- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self _updateCurrentPage];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self _updateCurrentPage];
}
- (void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
}

- (void) _updateCurrentPage
{
    CGPoint centerPoint = [self.collectionView.superview convertPoint:self.collectionView.center toView:self.collectionView];
    
    // indexpath of the item in the center of the screen
    NSIndexPath* visibleIndexPath = [self.collectionView indexPathForItemAtPoint:centerPoint];
    
    // index path changed - changed page index
    if (visibleIndexPath && (!self.currentIndexPath  || [visibleIndexPath compare:self.currentIndexPath] != NSOrderedSame))
    {
        self.currentIndexPath = visibleIndexPath;
        [self goToPageIndex:[self _firstPageIndexForIndexPath:visibleIndexPath] animated:NO];
    }
}


#pragma mark - Image Downloader

- (SDWebImageManager*) cachedImageDownloader
{
    if (!_cachedImageDownloader)
    {
        _cachedImageDownloader = [SDWebImageManager new];
    }
    return _cachedImageDownloader;
}

- (CGSize) _maxPageImageSizeForPageView:(ETA_VersoPageSpreadCell *)pageView showingTwoPages:(BOOL)twoPages zoomImage:(BOOL)zoomImage
{
    // figure out how big the image should be
    CGSize maxPageSize = CGSizeZero;
    
    if (pageView)
    {
        maxPageSize = pageView.bounds.size;
        if (zoomImage)
        {
            maxPageSize.height *= pageView.maximumZoomScale;
            maxPageSize.width *= pageView.maximumZoomScale;
        }
        if (twoPages)
            maxPageSize.width *= 0.5;
    }
    return maxPageSize;
}



- (void) _prefetchViewImagesAroundIndex:(NSInteger)aroundIndex pagesBefore:(NSUInteger)pagesBefore pagesAfter:(NSUInteger)pagesAfter
{
    NSInteger prefetchFromIndex = MIN(MAX(aroundIndex - (NSInteger)pagesBefore, 0), (NSInteger)self.numberOfPages - 1);
    NSInteger prefetchUntilIndex = MIN(MAX(aroundIndex + (NSInteger)pagesAfter, 0), (NSInteger)self.numberOfPages - 1);
    
    for (NSUInteger idx=prefetchFromIndex; idx<=prefetchUntilIndex; idx++)
    {
        if (idx == aroundIndex)
            continue;
        
        NSURL* url = [self imageURLForPageIndex:idx withMaxSize:CGSizeZero isZoomImage:NO];
        [self _startFetchingImageAtURL:url forPageView:nil atPageIndex:idx isZoomImage:NO];
    }
}




- (void) _startFetchingImagesForPageView:(ETA_VersoPageSpreadCell *)pageView atIndexPath:(NSIndexPath*)indexPath zoomImage:(BOOL)zoomImage
{
    if (!indexPath)
        return;
    
    NSUInteger firstPageIndex = [self _firstPageIndexForIndexPath:indexPath];
    NSUInteger lastPageIndex = [self _lastPageIndexForIndexPath:indexPath];
    
    BOOL twoPages = firstPageIndex!=lastPageIndex;

    CGSize maxPageSize = [self _maxPageImageSizeForPageView:pageView showingTwoPages:twoPages zoomImage:zoomImage];

    // avoid refetching zoom images
    if (!zoomImage || ![pageView isShowingZoomImageForSide:ETA_VersoPageSpreadSide_Primary])
    {
        NSURL* primaryURL = [self imageURLForPageIndex:firstPageIndex withMaxSize:maxPageSize isZoomImage:zoomImage];
        [self _startFetchingImageAtURL:primaryURL forPageView:pageView atPageIndex:firstPageIndex isZoomImage:zoomImage];
    }
    
    if (twoPages && (!zoomImage || ![pageView isShowingZoomImageForSide:ETA_VersoPageSpreadSide_Secondary]))
    {
        NSURL* secondaryURL = [self imageURLForPageIndex:lastPageIndex withMaxSize:maxPageSize isZoomImage:zoomImage];
        [self _startFetchingImageAtURL:secondaryURL forPageView:pageView atPageIndex:lastPageIndex isZoomImage:zoomImage];
    }
}


- (void) _startFetchingImageAtURL:(NSURL*)url forPageView:(ETA_VersoPageSpreadCell*)pageView atPageIndex:(NSUInteger)pageIndex isZoomImage:(BOOL)isZoomImage
{
    if (!url)
    {
        return;
    }
    
    // dont do prefetch if already cached
    if (!pageView && [self.cachedImageDownloader cachedImageExistsForURL:url])
    {
        return;
    }
    
    
    
    NSString* imageID = [NSString stringWithFormat:@"%tu-%@%@", pageIndex, isZoomImage ? @"zoom":@"view", pageView?@"":@"-prefetch"];
//    NSLog(@"[ImgDL] Page %@ Start%@...", imageID, pageView ? @"" : @" Prefetch");
    
    __weak __typeof(self) weakSelf = self;
    SDWebImageDownloaderProgressBlock progressBlock = nil;
//    SDWebImageDownloaderProgressBlock progressBlock = ^(NSInteger receivedSize, NSInteger expectedSize) {
////        NSLog(@"[ImgDL] %tu Progress %tu/%tu", pageIndex, receivedSize, expectedSize);
//    };
    
    SDWebImageCompletionWithFinishedBlock completionBlock = ^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        if (!image)
        {
            NSLog(@"[ImgDL] Page %@ Error %@", imageID, error);
        }
        [weakSelf _updateImage:image forPageView:pageView atPageIndex:pageIndex isZoomImage:isZoomImage];
    };
    
    
    SDWebImageOptions options = 0;
    
    // start a download operation for this url
    [self.cachedImageDownloader downloadImageWithURL:url options:options progress:progressBlock completed:completionBlock];
}

@end
