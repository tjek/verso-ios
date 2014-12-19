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
@property (nonatomic, assign) NSUInteger numberOfPageSpreads; // based on number of pages, and the single page mode

@property (nonatomic, assign) NSUInteger currentPageIndex; // the last viewed page index


@property (nonatomic, assign) NSRange previousVisiblePageRange;
@property (nonatomic, assign) NSRange pageRangeAtCenter;


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
    _numberOfPageSpreads = 0;
    _singlePageMode = YES;
    _previousVisiblePageRange = NSMakeRange(NSNotFound, 0);
    
    [self addSubviews];
}

- (void)addSubviews
{
    [self addSubview:self.collectionView];
}

-(void) setBounds:(CGRect)bounds
{
    // in order to avoid item size warnings, invalidate the layout before the bounds change
    [self.collectionView.collectionViewLayout invalidateLayout];
    
    [super setBounds:bounds];
}

- (void) layoutSubviews
{
    // in order to avoid item size warnings, invalidate the layout before the collection view is layed out
    [self.collectionView.collectionViewLayout invalidateLayout];
    
    [super layoutSubviews];
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









#pragma mark - Public Methods

- (void) setSinglePageMode:(BOOL)singlePageMode
{
    [self setSinglePageMode:singlePageMode animated:NO];
}
- (void) setSinglePageMode:(BOOL)singlePageMode animated:(BOOL)animated
{
    BOOL prevSinglePageMode = _singlePageMode;
    
    if (singlePageMode == prevSinglePageMode)
        return;
        
    _singlePageMode = singlePageMode;
    
    
    
    
    // move the collection view items around to fit the changes
    
    NSUInteger prevSpreadCount = [self _numberOfPageSpreadsForPageCount:self.numberOfPages inSinglePageMode:prevSinglePageMode];
    NSUInteger prevSpreadIndex = [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:prevSinglePageMode];
    
    NSUInteger currSpreadCount = [self _numberOfPageSpreadsForPageCount:self.numberOfPages inSinglePageMode:singlePageMode];
    NSUInteger currSpreadIndex = [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:singlePageMode];
//    NSLog(@"Set singlePageMode %@", @(singlePageMode));
//    NSLog(@"  - spread   cnt: %@->%@  |  idx:%@->%@", @(prevSpreadCount), @(currSpreadCount), @(prevSpreadIndex), @(currSpreadIndex));
    
    self.numberOfPageSpreads = currSpreadCount;
    
    
    // first update the currently visible spread cell
    [CATransaction begin]; {
        
        ETA_VersoPageSpreadCell* spreadView = [self _cellForPageSpreadIndex:prevSpreadIndex];
        [self _preparePageView:spreadView atSpreadIndex:currSpreadIndex animated:animated];
        
    } [CATransaction commit];
    

    
    // move the cells around - dont animate this
    BOOL animsEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    
    [self.collectionView performBatchUpdates:^{
        
        // insert or remove page spreads, and move the currently visible one
        if (currSpreadCount > prevSpreadCount)
        {
            NSMutableArray* indexPathsToInsert = [NSMutableArray array];
            
            // add indexes to the end
            for (NSUInteger i = prevSpreadCount; i < currSpreadCount; i++)
            {
                [indexPathsToInsert addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
            
            [self.collectionView insertItemsAtIndexPaths:indexPathsToInsert];
            [self.collectionView moveItemAtIndexPath:[NSIndexPath indexPathForItem:prevSpreadIndex inSection:0]
                                         toIndexPath:[NSIndexPath indexPathForItem:currSpreadIndex inSection:0]];
        }
        else if (currSpreadCount < prevSpreadCount)
        {
            NSMutableArray* indexPathsToDelete = [NSMutableArray array];
            for (NSUInteger i = currSpreadCount; i < prevSpreadCount; i++)
            {
                [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
            
            [self.collectionView moveItemAtIndexPath:[NSIndexPath indexPathForItem:prevSpreadIndex inSection:0]
                                         toIndexPath:[NSIndexPath indexPathForItem:currSpreadIndex inSection:0]];
            
            [self.collectionView deleteItemsAtIndexPaths:indexPathsToDelete];
        }
    } completion:^(BOOL finished) {
        // TODO: fix strange flicker when items spread count get smaller - no cell visible when breaking in completion block
        [self.collectionView flashScrollIndicators];
    }];
    
    [UIView setAnimationsEnabled:animsEnabled];
    
    
    // make sure the current cell is visible
    [self _showPageSpreadAtIndex:currSpreadIndex animated:NO];
    
    // report that page range changed
    [self _finishedPossiblyChangingVisiblePageRange];
}


- (void) reloadPages
{
//    NSUInteger prevPageCount = self.numberOfPages;
    
    // get the number of pages from the datasource
    NSUInteger numberOfPages = 0;
    if ([self.dataSource respondsToSelector:@selector(numberOfPagesInVersoPagedView:)])
    {
        numberOfPages = [self.dataSource numberOfPagesInVersoPagedView:self];
    }
    self.numberOfPages = numberOfPages;
    
    
    // update the spread count, and reload all the spreads
    
//    NSUInteger prevSpreadCount = self.numberOfPageSpreads;
    NSUInteger currSpreadCount = [self _numberOfPageSpreadsForPageCount:self.numberOfPages inSinglePageMode:self.singlePageMode];
    self.numberOfPageSpreads = currSpreadCount;
    
    
    // current page is outside of the new page range - go back to the beginning
    if (self.currentPageIndex >= self.numberOfPages)
        self.currentPageIndex = 0;

//    NSLog(@"Reload Pages");
//    NSLog(@"  - pages: %@->%@  |  spreads: %@->%@", @(prevPageCount), @(self.numberOfPages), @(prevSpreadCount), @(currSpreadCount));
    
    
    [self.collectionView reloadData];
    
    
    
    // go to the current spread
    NSUInteger currSpreadIndex = self.numberOfPageSpreads > 0 ? [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:self.singlePageMode] : NSNotFound;
    [self _showPageSpreadAtIndex:currSpreadIndex animated:NO];
    
    
    
    // report that page range changed
    [self _finishedPossiblyChangingVisiblePageRange];
    
    
    // make sure scrolling is enabled again
    self.collectionView.scrollEnabled = YES;
    
    
    
    // update the outro view
    [self.outroView removeFromSuperview];
    
    if ([self.delegate respondsToSelector:@selector(outroViewForVersoPagedView:)])
        self.outroView = [self.delegate outroViewForVersoPagedView:self];
    else
        self.outroView = nil;
}



- (void) goToPageIndex:(NSInteger)pageIndex animated:(BOOL)animated
{
    // clamp pageIndex
    pageIndex = MAX(0, pageIndex);
    pageIndex = MIN(pageIndex, MAX(0, (NSInteger)self.numberOfPages-1));
    
    _currentPageIndex = pageIndex;
    
    
    // go to the current spread
    NSUInteger currSpreadIndex = [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:self.singlePageMode];
    [self _showPageSpreadAtIndex:currSpreadIndex animated:animated];
    
    
    
    // report that page range changed
    [self _finishedPossiblyChangingVisiblePageRange];
}


- (void) setShowHotspots:(BOOL)showHotspots
{
    [self setShowHotspots:showHotspots animated:NO];
}

- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated
{
    _showHotspots = showHotspots;
    
    ETA_VersoPageSpreadCell* pageSpread = [self _currentPageSpreadCell];
    [pageSpread setShowHotspots:showHotspots animated:animated];
}



- (NSRange) visiblePageIndexRange
{
    return [self _pageIndexRangeAtViewCenter];
}

- (CGFloat) pageProgress
{
    NSRange pageRange = [self visiblePageIndexRange];
    
    // update the pageProgress
    CGFloat percentageComplete = 0;
    CGFloat numberOfPages = self.numberOfPages;
    if (numberOfPages == 1)
    {
        percentageComplete = 1.0;
    }
    else if (numberOfPages > 1 && pageRange.location != NSNotFound)
    {
        NSUInteger lastVisiblePageIndex = pageRange.location + pageRange.length - 1;
        
        percentageComplete = (CGFloat)(lastVisiblePageIndex) / (CGFloat)(numberOfPages - 1);
    }
    return percentageComplete;
}



#pragma mark - Private Methods


#pragma mark Page/Spread conversion utilities (Stateless)

- (NSUInteger) _numberOfPageSpreadsForPageCount:(NSUInteger)pageCount inSinglePageMode:(BOOL)singlePageMode
{
    // update number of items
    NSUInteger spreadCount = pageCount;
    if (!singlePageMode && pageCount != 0)
    {
        // round down to the even page count, and subtract 1
        spreadCount = (pageCount-(pageCount%2) + 2) / 2;
    }
    
    return spreadCount;
}

- (NSUInteger) _pageSpreadIndexForPageIndex:(NSUInteger)pageIndex inSinglePageMode:(BOOL)singlePageMode
{
    if (pageIndex == NSNotFound)
        return NSNotFound;
    
    NSInteger spreadIndex = pageIndex;
    
    if (!singlePageMode)
    {
        // round up to the even page index (0->0, 1->2, 2->2, 3->4 ...), and halve
        spreadIndex = (pageIndex + (pageIndex % 2)) / 2.0;
    }
    return spreadIndex;
}

- (BOOL) _isPageIndexVerso:(NSInteger)pageIndex
{
    // 0 = recto
    return (pageIndex % 2) == 1;
}

- (NSUInteger) _pageIndexForPageSpreadIndex:(NSInteger)spreadIndex versoSide:(BOOL)versoSide inSinglePageMode:(BOOL)singlePageMode withPageCount:(NSUInteger)pageCount
{
    if (spreadIndex == NSNotFound || spreadIndex < 0)
        return NSNotFound;
    
    NSInteger pageIndex = spreadIndex;
    if (!singlePageMode)
    {
        pageIndex *= 2;
        if (versoSide)
            pageIndex--;
    }
    
    if (pageIndex >= 0 && pageIndex < pageCount && [self _isPageIndexVerso:pageIndex] == versoSide)
        return pageIndex;
    else
        return NSNotFound;
}

- (NSRange) _pageIndexRangeForPageSpreadIndex:(NSInteger)spreadIndex inSinglePageMode:(BOOL)singlePageMode withPageCount:(NSUInteger)pageCount
{
    NSUInteger versoPageIndex = [self _pageIndexForPageSpreadIndex:spreadIndex versoSide:YES inSinglePageMode:singlePageMode withPageCount:pageCount];
    NSUInteger rectoPageIndex = [self _pageIndexForPageSpreadIndex:spreadIndex versoSide:NO inSinglePageMode:singlePageMode withPageCount:pageCount];
    
    NSUInteger rangeLength;
    if (versoPageIndex != NSNotFound && rectoPageIndex != NSNotFound)
    {
        rangeLength = (rectoPageIndex - versoPageIndex) + 1;
    }
    else if (versoPageIndex != NSNotFound || rectoPageIndex != NSNotFound)
    {
        rangeLength = 1;
    }
    else
    {
        rangeLength = 0;
    }
    
    
    NSUInteger rangeStart;
    if (versoPageIndex != NSNotFound)
    {
        rangeStart = versoPageIndex;
    }
    else if (rectoPageIndex != NSNotFound)
    {
        rangeStart = rectoPageIndex;
    }
    else
    {
        rangeStart = NSNotFound;
    }
    
    return NSMakeRange(rangeStart, rangeLength);
}





#pragma mark Collection View Methods

// scroll the specified spread into view
- (void) _showPageSpreadAtIndex:(NSUInteger)spreadIndex animated:(BOOL)animated
{
    if (spreadIndex == NSNotFound || spreadIndex >= self.numberOfPageSpreads)
        return;
    
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:spreadIndex inSection:0]
                                atScrollPosition:UICollectionViewScrollPositionCenteredVertically | UICollectionViewScrollPositionCenteredHorizontally
                                        animated:animated];
}

// get the spread cell at the specified index
- (ETA_VersoPageSpreadCell*) _cellForPageSpreadIndex:(NSUInteger)spreadIndex
{
    ETA_VersoPageSpreadCell* pageSpread = (ETA_VersoPageSpreadCell*)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:spreadIndex inSection:0]];
    
    return pageSpread;
}

// get the spread cell for the current page index
- (ETA_VersoPageSpreadCell*) _currentPageSpreadCell
{
    NSUInteger currSpreadIndex = [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:self.singlePageMode];
    return [self _cellForPageSpreadIndex:currSpreadIndex];
}

- (NSRange) _pageIndexRangeAtPoint:(CGPoint)pointToCheck
{
    NSIndexPath* spreadIndexPath = [self.collectionView indexPathForItemAtPoint:pointToCheck];
    NSUInteger spreadIndex = spreadIndexPath ? spreadIndexPath.item : NSNotFound;
    
    NSRange pageRange = [self _pageIndexRangeForPageSpreadIndex:spreadIndex inSinglePageMode:self.singlePageMode withPageCount:self.numberOfPages];
    
    return pageRange;
}

- (NSRange) _pageIndexRangeAtViewCenter
{
    CGPoint centerPoint = [self.collectionView.superview convertPoint:self.collectionView.center toView:self.collectionView];
    
    return [self _pageIndexRangeAtPoint:centerPoint];
}






#pragma mark - Property Updaters

- (void) _beganPossiblyChangingVisiblePageRange
{
    NSRange newPageRange = [self visiblePageIndexRange];
    NSRange prevPageRange = self.pageRangeAtCenter;
    
    if (newPageRange.location != prevPageRange.location || newPageRange.length != newPageRange.length)
    {
        [self beganScrollingIntoNewPageIndexRange:newPageRange from:prevPageRange];
        
        // update the page range under the center of the screen
        self.pageRangeAtCenter = newPageRange;
    }
}
- (void) _finishedPossiblyChangingVisiblePageRange
{
    NSRange newPageRange = [self visiblePageIndexRange];
    NSRange prevPageRange = self.previousVisiblePageRange;
    
    if (newPageRange.location != prevPageRange.location || newPageRange.length != newPageRange.length)
    {
        [self finishedScrollingIntoNewPageIndexRange:newPageRange from:prevPageRange];
        
        self.previousVisiblePageRange = newPageRange;
    }
}





// get the page range that is at the center if the screen.
// If the currentPageIndex is not in that range then update & notify
- (void) _updateCurrentPageIndexIfChanged
{
    NSRange pageRange = [self _pageIndexRangeAtViewCenter];
    
    // no valid visible pages - in outro?
    if (pageRange.location == NSNotFound || pageRange.length == 0)
    {
        return;
    }
    
    // the current visible page isnt in the new visible page - something changed!
    if (NSLocationInRange(self.currentPageIndex, pageRange) == NO)
    {
        self.currentPageIndex = pageRange.location;
        
        // update the visiblePageRange & pageProgress, and notify
        [self _finishedPossiblyChangingVisiblePageRange];
    }
}





#pragma mark - Delegate methods
- (void) beganScrollingFrom:(NSRange)currentPageIndexRange
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:beganScrollingFrom:)])
    {
        [self.delegate versoPagedView:self beganScrollingFrom:currentPageIndexRange];
    }
}

- (void) beganScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:beganScrollingIntoNewPageIndexRange:from:)])
    {
        [self.delegate versoPagedView:self beganScrollingIntoNewPageIndexRange:newPageIndexRange from:previousPageIndexRange];
    }
}

- (void) finishedScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:finishedScrollingIntoNewPageIndexRange:from:)])
    {
        [self.delegate versoPagedView:self finishedScrollingIntoNewPageIndexRange:newPageIndexRange from:previousPageIndexRange];
    }
    
    // TODO: Prefetch behind current page
    
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
- (void) _preparePageView:(ETA_VersoPageSpreadCell*)pageView atSpreadIndex:(NSUInteger)spreadIndex animated:(BOOL)animated
{
    NSUInteger versoPageIndex = [self _pageIndexForPageSpreadIndex:spreadIndex versoSide:YES inSinglePageMode:self.singlePageMode withPageCount:self.numberOfPages];
    NSUInteger rectoPageIndex = [self _pageIndexForPageSpreadIndex:spreadIndex versoSide:NO inSinglePageMode:self.singlePageMode withPageCount:self.numberOfPages];
    
    
    NSUInteger firstPageIndex = versoPageIndex == NSNotFound ? rectoPageIndex : versoPageIndex;
    NSUInteger lastPageIndex = rectoPageIndex == NSNotFound ? versoPageIndex : rectoPageIndex;
 
    
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
    [pageView setHotspotRects:[self hotspotRectsForPageIndex:firstPageIndex]
                      forSide:ETA_VersoPageSpreadSide_Primary
            normalizedByWidth:[self hotspotsNormalizedByWidthForPageIndex:firstPageIndex]];
    
    
    [pageView setPageIndex:firstPageIndex
                   forSide:ETA_VersoPageSpreadSide_Primary];

    [pageView setPageNumberLabelText:[self pageNumberLabelStringForPageIndex:firstPageIndex]
                               color:[self pageNumberLabelColorForPageIndex:firstPageIndex]
                             forSide:ETA_VersoPageSpreadSide_Primary];
    
    if (!singlePageMode)
    {
        [pageView setPageIndex:lastPageIndex forSide:ETA_VersoPageSpreadSide_Secondary];
        [pageView setHotspotRects:[self hotspotRectsForPageIndex:lastPageIndex]
                          forSide: ETA_VersoPageSpreadSide_Secondary
                normalizedByWidth:[self hotspotsNormalizedByWidthForPageIndex:lastPageIndex]];
        
        [pageView setPageNumberLabelText:[self pageNumberLabelStringForPageIndex:lastPageIndex]
                                   color:[self pageNumberLabelColorForPageIndex:lastPageIndex]
                                 forSide:ETA_VersoPageSpreadSide_Secondary];
    }
    
    
    [pageView setSinglePageMode:singlePageMode animated:animated];
    [pageView setFitToWidth:fitToWidth animated:animated];
    
    [self _startFetchingImagesForPageView:pageView atIndexPath:[NSIndexPath indexPathForItem:spreadIndex inSection:0] zoomImage:NO];
    
    pageView.delegate = self;
}


- (void) _updateImage:(UIImage*)image forPageView:(ETA_VersoPageSpreadCell*)pageView atPageIndex:(NSUInteger)pageIndex isZoomImage:(BOOL)isZoomImage
{
    if (!pageView)
    {
        NSUInteger spreadIndex = [self _pageSpreadIndexForPageIndex:pageIndex inSinglePageMode:self.singlePageMode];
        
        pageView = [self _cellForPageSpreadIndex:spreadIndex];
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
    return self.numberOfPageSpreads;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ETA_VersoPageSpreadCell* pageView = [collectionView dequeueReusableCellWithReuseIdentifier:kVersoPageSpreadCellIdentifier forIndexPath:indexPath];
    
    [self _preparePageView:pageView atSpreadIndex:indexPath.item animated:NO];
    
    return pageView;
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
    // report that page range change started
    [self _beganPossiblyChangingVisiblePageRange];
}
- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self beganScrollingFrom:[self visiblePageIndexRange]];
}
- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // try to update the current page index, if it has changed
    [self _updateCurrentPageIndexIfChanged];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    // try to update the current page index, if it has changed
    [self _updateCurrentPageIndexIfChanged];
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
    
    NSUInteger spreadIndex = indexPath.item;
    
    NSUInteger versoPageIndex = [self _pageIndexForPageSpreadIndex:spreadIndex versoSide:YES inSinglePageMode:self.singlePageMode withPageCount:self.numberOfPages];
    NSUInteger rectoPageIndex = [self _pageIndexForPageSpreadIndex:spreadIndex versoSide:NO inSinglePageMode:self.singlePageMode withPageCount:self.numberOfPages];
    
    NSUInteger firstPageIndex = versoPageIndex == NSNotFound ? rectoPageIndex : versoPageIndex;
    NSUInteger lastPageIndex = rectoPageIndex == NSNotFound ? versoPageIndex : rectoPageIndex;
    
    
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
