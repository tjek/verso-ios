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
@property (nonatomic, strong) NSMutableSet* fetchingURLs;

@property (nonatomic, strong) UIView* outroView;
@property (nonatomic, assign) BOOL isShowingOutroView;
@property (nonatomic, strong) UITapGestureRecognizer* outsideOutroTap;


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
    _isShowingOutroView = NO;
    
    [self addSubviews];
}

- (void)addSubviews
{
    [self addSubview:self.collectionView];
}

-(void) setBounds:(CGRect)bounds
{
    // make sure the current cell is visible (specifically to close the outro view)
    NSUInteger currSpreadIndex = [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:self.singlePageMode];
    [self _showPageSpreadAtIndex:currSpreadIndex animated:NO];

    [self _zoomOutCurrentPageSpread];
    
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
    
    
    // We dont check for equality here, as we need to trigger the maybe Finished changing page calls even if single page stays the same
    // TODO: In a much nicer, less fragile, way
//    if (singlePageMode == prevSinglePageMode)
//        return;
    
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
    
    
    if (currSpreadCount != prevSpreadCount)
    {        
        // move the cells around - dont animate this
        BOOL animsEnabled = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        
        __weak __typeof(self)weakSelf = self;
        [self.collectionView performBatchUpdates:^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            
            // insert or remove page spreads, and move the currently visible one
            if (currSpreadCount > prevSpreadCount)
            {
                NSMutableArray* indexPathsToInsert = [NSMutableArray array];
                
                // add indexes to the end
                for (NSUInteger i = prevSpreadCount; i < currSpreadCount; i++)
                {
                    [indexPathsToInsert addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                
                [strongSelf.collectionView insertItemsAtIndexPaths:indexPathsToInsert];
                [strongSelf.collectionView moveItemAtIndexPath:[NSIndexPath indexPathForItem:prevSpreadIndex inSection:0]
                                                   toIndexPath:[NSIndexPath indexPathForItem:currSpreadIndex inSection:0]];
            }
            else if (currSpreadCount < prevSpreadCount)
            {
                NSMutableArray* indexPathsToDelete = [NSMutableArray array];
                for (NSUInteger i = currSpreadCount; i < prevSpreadCount; i++)
                {
                    [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                
                [strongSelf.collectionView moveItemAtIndexPath:[NSIndexPath indexPathForItem:prevSpreadIndex inSection:0]
                                                   toIndexPath:[NSIndexPath indexPathForItem:currSpreadIndex inSection:0]];
                
                [strongSelf.collectionView deleteItemsAtIndexPaths:indexPathsToDelete];
            }
        } completion:^(BOOL finished) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            // TODO: fix strange flicker when items spread count get smaller - no cell visible when breaking in completion block
            [strongSelf.collectionView flashScrollIndicators];
        }];
        
        [UIView setAnimationsEnabled:animsEnabled];
    }
    
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

- (UIPanGestureRecognizer*) pagePanGestureRecognizer
{
    return self.collectionView.panGestureRecognizer;
}



- (NSArray*) getHotspotViewsAtLocation:(CGPoint)location
{
    ETA_VersoPageSpreadCell* pageSpread = [self _currentPageSpreadCell];
    return [pageSpread hotspotViewsAtPoint:location];
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

- (void) _closeOutro
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // turn off paging, so that we dont automatically scroll back to the outro
        self.collectionView.pagingEnabled = NO;
        
        [CATransaction begin]; {
            // turn paging back on
            __weak __typeof(self) weakSelf = self;
            [CATransaction setCompletionBlock:^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    weakSelf.collectionView.pagingEnabled = YES;
                });
            }];
            
            [CATransaction setAnimationDuration:0.15];
            
            [self goToPageIndex:self.currentPageIndex animated:YES];
            
        } [CATransaction commit];
        
    });
}

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
    if (spreadIndex == NSNotFound)
        return nil;
    
    ETA_VersoPageSpreadCell* pageSpread = (ETA_VersoPageSpreadCell*)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:spreadIndex inSection:0]];
    
    return pageSpread;
}

// get the spread cell for the current page index
- (ETA_VersoPageSpreadCell*) _currentPageSpreadCell
{
    NSUInteger currSpreadIndex = [self _pageSpreadIndexForPageIndex:[self visiblePageIndexRange].location inSinglePageMode:self.singlePageMode];
    return [self _cellForPageSpreadIndex:currSpreadIndex];
}

- (NSRange) _pageIndexRangeAtPoint:(CGPoint)pointToCheck
{
    CGFloat collectionWidth = self.collectionView.bounds.size.width;
   
    NSUInteger spreadIndex = collectionWidth ? (NSUInteger)floor(pointToCheck.x/collectionWidth) : NSNotFound;

    NSRange pageRange = [self _pageIndexRangeForPageSpreadIndex:spreadIndex inSinglePageMode:self.singlePageMode withPageCount:self.numberOfPages];
    
    return pageRange;
}

- (NSRange) _pageIndexRangeAtViewCenter
{
    return [self _pageIndexRangeAtPoint:(CGPoint){
        .x = CGRectGetMidX(self.collectionView.bounds),
        .y = CGRectGetMidY(self.collectionView.bounds)
    }];
}






#pragma mark - Property Updaters

- (void) _beganPossiblyChangingVisiblePageRange
{
    NSRange newPageRange = [self visiblePageIndexRange];
    NSRange prevPageRange = self.pageRangeAtCenter;
    
    // update the page range under the center of the screen
    self.pageRangeAtCenter = newPageRange;
    
    [self beganScrollingIntoNewPageIndexRange:newPageRange from:prevPageRange];
}
- (void) _finishedPossiblyChangingVisiblePageRange
{
    NSRange newPageRange = [self visiblePageIndexRange];
    NSRange prevPageRange = self.previousVisiblePageRange;
    
    self.previousVisiblePageRange = newPageRange;
    
    [self finishedScrollingIntoNewPageIndexRange:newPageRange from:prevPageRange];
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
    }
}



- (void) _zoomOutCurrentPageSpread
{
    ETA_VersoPageSpreadCell* currSpreadCell = [self _currentPageSpreadCell];
    UIScrollView* currZoomView = currSpreadCell.zoomView;
    
    CGFloat currZoom = currZoomView.zoomScale;
    if (currZoom == currZoomView.minimumZoomScale)
        return;
    
    [self versoPageSpreadWillBeginZooming:currSpreadCell];
    
    [currZoomView setZoomScale:currZoomView.minimumZoomScale animated:NO];
    
    [self versoPageSpreadDidEndZooming:currSpreadCell];
    
}





#pragma mark - Delegate methods
- (void) beganScrollingFrom:(NSRange)currentPageIndexRange
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:beganScrollingFrom:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self beganScrollingFrom:currentPageIndexRange];
        });
    }
}

- (void) beganScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    // nothing changed
    if (newPageIndexRange.location == previousPageIndexRange.location && newPageIndexRange.length == previousPageIndexRange.length)
    {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(versoPagedView:beganScrollingIntoNewPageIndexRange:from:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self beganScrollingIntoNewPageIndexRange:newPageIndexRange from:previousPageIndexRange];
        });
    }
}

- (void) finishedScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange
{
    // nothing changed
    if (newPageIndexRange.location == previousPageIndexRange.location && newPageIndexRange.length == previousPageIndexRange.length)
    {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if ([self.delegate respondsToSelector:@selector(versoPagedView:finishedScrollingIntoNewPageIndexRange:from:)])
        {
            [self.delegate versoPagedView:self finishedScrollingIntoNewPageIndexRange:newPageIndexRange from:previousPageIndexRange];
        }
        
        // do the prefetching around the newly visible page
        
        NSUInteger pagesBehindToPrefetch = 3;
        NSUInteger startPrefetchBeforeIndex = self.visiblePageIndexRange.location;
        if ([self.delegate respondsToSelector:@selector(versoPagedView:numberOfPagesAheadToPrefetch:)])
        {
            pagesBehindToPrefetch = [self.delegate versoPagedView:self numberOfPagesBehindToPrefetch:startPrefetchBeforeIndex];
        }
        
        if (pagesBehindToPrefetch > 0)
        {
            [self _prefetchViewImagesFromIndex:startPrefetchBeforeIndex-pagesBehindToPrefetch toIndex:startPrefetchBeforeIndex-1];
        }
        
        
    
        NSUInteger pagesAheadToPrefetch = 3;
        NSUInteger startPrefetchAfterIndex = self.visiblePageIndexRange.location + self.visiblePageIndexRange.length - 1;
        if ([self.delegate respondsToSelector:@selector(versoPagedView:numberOfPagesAheadToPrefetch:)])
        {
            pagesAheadToPrefetch = [self.delegate versoPagedView:self numberOfPagesAheadToPrefetch:startPrefetchAfterIndex];
        }
        
        if (pagesAheadToPrefetch > 0)
        {
            [self _prefetchViewImagesFromIndex:startPrefetchAfterIndex+1 toIndex:startPrefetchAfterIndex+pagesAheadToPrefetch];
        }
    });
}

- (void) didTapOutsideOutro:(UITapGestureRecognizer*)tap
{
    if (!self.isShowingOutroView)
        return;

    CGPoint pointInOutro = [tap locationInView:self.outroView];
    if (CGRectContainsPoint(self.outroView.bounds, pointInOutro) == NO)
    {
        [self _closeOutro];
    }
}

- (void) willBeginDisplayingOutro
{
    if (!self.outsideOutroTap)
    {
        self.outsideOutroTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapOutsideOutro:)];
        self.outsideOutroTap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:self.outsideOutroTap];
        
        NSUInteger currSpreadIndex = [self _pageSpreadIndexForPageIndex:self.currentPageIndex inSinglePageMode:self.singlePageMode];
        ETA_VersoPageSpreadCell* lastCell = [self _cellForPageSpreadIndex:currSpreadIndex];
        
        [lastCell.tapGesture requireGestureRecognizerToFail:self.outsideOutroTap];
        [lastCell.doubleTapGesture requireGestureRecognizerToFail:self.outsideOutroTap];
        [lastCell.longPressGesture requireGestureRecognizerToFail:self.outsideOutroTap];
    }
    
    if ([self.delegate respondsToSelector:@selector(willBeginDisplayingOutroForVersoPagedView:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate willBeginDisplayingOutroForVersoPagedView:self];
        });
    }
}
- (void) didEndDisplayingOutro
{
    if (self.outsideOutroTap)
    {
        [self removeGestureRecognizer:self.outsideOutroTap];
        self.outsideOutroTap = nil;
    }
    
    if ([self.delegate respondsToSelector:@selector(didEndDisplayingOutroForVersoPagedView:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didEndDisplayingOutroForVersoPagedView:self];
        });
    }
}



- (void) didBeginTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didBeginTouchingLocation:onPageIndex:hittingHotspotsWithKeys:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self didBeginTouchingLocation:tapLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
        });
    }
}
- (void) didFinishTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didFinishTouchingLocation:onPageIndex:hittingHotspotsWithKeys:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self didFinishTouchingLocation:tapLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
        });
    }
}

- (void) didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didTapLocation:onPageIndex:hittingHotspotsWithKeys:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self didTapLocation:tapLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
        });
    }
}

- (void) didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didLongPressLocation:onPageIndex:hittingHotspotsWithKeys:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self didLongPressLocation:longPressLocation onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
        });
    }
}

- (void) didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex
{
    if ([self.delegate respondsToSelector:@selector(versoPagedView:didSetImage:isZoomImage:onPageIndex:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate versoPagedView:self didSetImage:image isZoomImage:isZoomImage onPageIndex:pageIndex];
        });
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


- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didFinishTouchingAtPoint:(CGPoint)locationInPageView onPageSide:(ETA_VersoPageSpreadSide)pageSide hittingHotspotsWithKeys:(NSArray *)hotspotKeys
{
    NSInteger pageIndex = [pageSpreadCell pageIndexForSide:pageSide];
    if (pageIndex < 0)
        return;
    
    CGPoint locationInReader = [self convertPoint:locationInPageView fromView:pageSpreadCell];
    
    [self didFinishTouchingLocation:locationInReader onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
}

- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didBeginTouchingAtPoint:(CGPoint)locationInPageView onPageSide:(ETA_VersoPageSpreadSide)pageSide hittingHotspotsWithKeys:(NSArray *)hotspotKeys
{
    NSInteger pageIndex = [pageSpreadCell pageIndexForSide:pageSide];
    if (pageIndex < 0)
        return;
    
    CGPoint locationInReader = [self convertPoint:locationInPageView fromView:pageSpreadCell];
    
    [self didBeginTouchingLocation:locationInReader onPageIndex:pageIndex hittingHotspotsWithKeys:hotspotKeys];
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
    

    BOOL fitToWidth = NO;
    [pageView setFitToWidth:fitToWidth animated:animated];
    [pageView setVersoPageIndex:versoPageIndex rectoPageIndex:rectoPageIndex animated:animated];
    
    
    
    BOOL showHotspots = self.showHotspots;
    
    
    
    [pageView setShowHotspots:showHotspots animated:animated];
    
    if (versoPageIndex != NSNotFound)
    {
        [pageView setPageNumberLabelText:[self pageNumberLabelStringForPageIndex:versoPageIndex]
                                   color:[self pageNumberLabelColorForPageIndex:versoPageIndex]
                                 forSide:ETA_VersoPageSpreadSide_Verso];
        
        [pageView setHotspotRects:[self hotspotRectsForPageIndex:versoPageIndex]
                          forSide:ETA_VersoPageSpreadSide_Verso
                normalizedByWidth:[self hotspotsNormalizedByWidthForPageIndex:versoPageIndex]];
        
    }
    
    if (rectoPageIndex != NSNotFound)
    {
        [pageView setPageNumberLabelText:[self pageNumberLabelStringForPageIndex:rectoPageIndex]
                                   color:[self pageNumberLabelColorForPageIndex:rectoPageIndex]
                                 forSide:ETA_VersoPageSpreadSide_Recto];
        
        [pageView setHotspotRects:[self hotspotRectsForPageIndex:rectoPageIndex]
                          forSide:ETA_VersoPageSpreadSide_Recto
                normalizedByWidth:[self hotspotsNormalizedByWidthForPageIndex:rectoPageIndex]];
        
    }
    
    

    
//    if (singlePageMode)
//        NSLog(@"Prepare PageView %tu (%@) - item:%tu", firstPageIndex, isVisible?@"Visible":@"Hidden", indexPath.item);
//    else
//        NSLog(@"Prepare PageView %tu-%tu (%@) - item:%tu", firstPageIndex, lastPageIndex, isVisible?@"Visible":@"Hidden", indexPath.item);
    
    // make sure that the zoomview's panning doesnt block the collectionViews panning (we disable the collection view's scrolling when we are zoomed in)
    [pageView.zoomView.panGestureRecognizer requireGestureRecognizerToFail:self.collectionView.panGestureRecognizer];
    [pageView.doubleTapGesture requireGestureRecognizerToFail:self.collectionView.panGestureRecognizer];
    [pageView.tapGesture requireGestureRecognizerToFail:self.collectionView.panGestureRecognizer];
    
    
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
    if ([pageView pageIndexForSide:ETA_VersoPageSpreadSide_Verso] == pageIndex)
    {
        pageSide = ETA_VersoPageSpreadSide_Verso;
    }
    else if ([pageView pageIndexForSide:ETA_VersoPageSpreadSide_Recto] == pageIndex)
    {
        pageSide = ETA_VersoPageSpreadSide_Recto;
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
        
        self.outroView.frame = UIEdgeInsetsInsetRect(reusableview.bounds, UIEdgeInsetsMake(0, 18, 0, 0));
        self.outroView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [reusableview addSubview:self.outroView];
    }
    
    return reusableview;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if (elementKind == UICollectionElementKindSectionFooter)
    {
        if (!self.isShowingOutroView && self.numberOfPages > 0 && collectionView.isDragging)
        {
            self.isShowingOutroView = YES;
            [self willBeginDisplayingOutro];
        }
    }
}
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if (elementKind == UICollectionElementKindSectionFooter)
    {
        if (self.isShowingOutroView)
        {
            self.isShowingOutroView = NO;
            [self didEndDisplayingOutro];
        }
    }
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
    
    [self _finishedPossiblyChangingVisiblePageRange];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    // try to update the current page index, if it has changed
    [self _updateCurrentPageIndexIfChanged];
}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self _finishedPossiblyChangingVisiblePageRange];
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


- (void) _prefetchViewImagesFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex
{
    if (fromIndex > toIndex || toIndex < 0)
        return;
    
    fromIndex = MIN(MAX(fromIndex, 0), (NSInteger)self.numberOfPages - 1);
    toIndex = MIN(MAX(toIndex, 0), (NSInteger)self.numberOfPages - 1);
    
    for (NSUInteger idx=fromIndex; idx<=toIndex; idx++)
    {
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
    

    BOOL twoPages = (versoPageIndex != NSNotFound) && (rectoPageIndex != NSNotFound);

    CGSize maxPageSize = [self _maxPageImageSizeForPageView:pageView showingTwoPages:twoPages zoomImage:zoomImage];

    // avoid refetching zoom images
    if (versoPageIndex != NSNotFound && (!zoomImage || ![pageView isShowingZoomImageForSide:ETA_VersoPageSpreadSide_Verso]))
    {
        NSURL* primaryURL = [self imageURLForPageIndex:versoPageIndex withMaxSize:maxPageSize isZoomImage:zoomImage];
        [self _startFetchingImageAtURL:primaryURL forPageView:pageView atPageIndex:versoPageIndex isZoomImage:zoomImage];
    }
    
    if (rectoPageIndex != NSNotFound && (!zoomImage || ![pageView isShowingZoomImageForSide:ETA_VersoPageSpreadSide_Recto]))
    {
        NSURL* secondaryURL = [self imageURLForPageIndex:rectoPageIndex withMaxSize:maxPageSize isZoomImage:zoomImage];
        [self _startFetchingImageAtURL:secondaryURL forPageView:pageView atPageIndex:rectoPageIndex isZoomImage:zoomImage];
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
    
    if ([self.fetchingURLs containsObject:url])
    {
        return;
    }
    
    if (!self.fetchingURLs)
        self.fetchingURLs = [NSMutableSet set];
    
    [self.fetchingURLs addObject:url];
    
    
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
        [weakSelf.fetchingURLs removeObject:url];
        [weakSelf _updateImage:image forPageView:pageView atPageIndex:pageIndex isZoomImage:isZoomImage];
    };
    
    
    SDWebImageOptions options = 0;
    
    // start a download operation for this url
    [self.cachedImageDownloader downloadImageWithURL:url options:options progress:progressBlock completed:completionBlock];
}

@end
