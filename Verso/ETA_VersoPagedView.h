//
//  ETA_VersoPagedView.h
//  Verso
//
//  Created by Laurie Hufford on 04/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ETA_VersoPagedViewDataSource;
@protocol ETA_VersoPagedViewDelegate;
@protocol ETA_VersoPageImageURLFetcher;

@interface ETA_VersoPagedView : UIView


/**
 *  Whether we show only 1 page on the screen at a time.
 *  Will trigger a reload of the data.
 */
@property (nonatomic, assign) BOOL singlePageMode;
- (void) setSinglePageMode:(BOOL)singlePageMode animated:(BOOL)animated;



@property (nonatomic, assign) BOOL showHotspots;
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated;




/**
 *  The index (starts at 0) of the currently visible page. 
 *  If there are two pages visible, this is the index of the first page.
 */
@property (nonatomic, assign, readonly) NSUInteger currentPageIndex;

/**
 *  The total number of pages that the datasource provided
 */
@property (nonatomic, assign, readonly) NSUInteger numberOfPages;




/**
 *  The range of page indexes within the page spread that is currently under the center of the view
 *  `.location` this is the index of the first visible page (e.g `currentPageIndex`).
 *  `.length` is the number of visible pages (e.g. 2 if showing two pages)
 *
 *  @return The range of page indexes in the current page spread
 */
- (NSRange) visiblePageIndexRange;

/**
 *  The percentage position of the last visible page (0.0 = first page, 1.0 = last page)
 */
- (CGFloat) pageProgress;



/**
 *  Scroll the paged view to the specified page index (the first page is index 0).
 *
 *  @param pageIndex The page index to scroll to. Will be clamped to the number of pages.
 *  @param animated  Whether to animate the changing of the page.
 */
- (void) goToPageIndex:(NSInteger)pageIndex animated:(BOOL)animated;



/**
 *  Trigger a re-request of the page data for this VersoPagedView
 *
 *  This is automatically called when it is added to a new superview
 */
- (void) reloadPages;


@property (nonatomic, weak) id<ETA_VersoPagedViewDataSource> dataSource;
@property (nonatomic, weak) id<ETA_VersoPagedViewDelegate> delegate;

// This handles the fetching/caching of the page images. If not set the default AFImageDownloader implementation will be used
@property (nonatomic, strong) id<ETA_VersoPageImageURLFetcher> imageFetcher;

- (UIPanGestureRecognizer*) pagePanGestureRecognizer;


- (BOOL) isShowingOutroView;


- (NSArray*) getHotspotViewsAtLocation:(CGPoint)location;


// This will re-draw the page image every time a new piece of data arrives.
// Only applies to non-zoom image.
// defaults to NO.
@property (nonatomic, assign) BOOL updateImagesProgressively;

@end




#pragma mark - Data Source

@protocol ETA_VersoPagedViewDataSource <NSObject>

@required
- (NSUInteger) numberOfPagesInVersoPagedView:(ETA_VersoPagedView*)versoPagedView;

- (NSURL*) versoPagedView:(ETA_VersoPagedView*)versoPagedView imageURLForPageIndex:(NSUInteger)pageIndex withMaxSize:(CGSize)maxPageSize isZoomImage:(BOOL)isZoomImage;


@optional

- (NSDictionary*) versoPagedView:(ETA_VersoPagedView*)versoPagedView hotspotRectsForPageIndex:(NSUInteger)pageIndex;

// normalizedByWidth means that the width of the hotspot is normalized 0->1, but the height is normalized 0->[image height/width]. Defaults to NO.
// For example, a hotspot with origin [0.5, 0.5] in an image of size 100x150 will have a pixel origin of [50, 66.6] if normalizedByWidth is true. Otherwise, if false, the pixel origin would be [50, 75]
- (BOOL) versoPagedView:(ETA_VersoPagedView*)versoPagedView hotspotRectsNormalizedByWidthForPageIndex:(NSUInteger)pageIndex;

@end



#pragma mark - Delegate

@protocol ETA_VersoPagedViewDelegate <NSObject>

////////////////////////////////////////////////////////////////////////////////
/// @name Callback Events
////////////////////////////////////////////////////////////////////////////////

@optional


- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView beganScrollingFrom:(NSRange)currentPageIndexRange;
- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView beganScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange;
- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView finishedScrollingIntoNewPageIndexRange:(NSRange)newPageIndexRange from:(NSRange)previousPageIndexRange;


- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didBeginTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;
- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didFinishTouchingLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex;

- (void) willBeginDisplayingOutroForVersoPagedView:(ETA_VersoPagedView *)versoPagedView;
- (void) didEndDisplayingOutroForVersoPagedView:(ETA_VersoPagedView *)versoPagedView;


////////////////////////////////////////////////////////////////////////////////
/// @name Styling a page
////////////////////////////////////////////////////////////////////////////////

@optional


// default 3 if not implemented
- (NSUInteger) versoPagedView:(ETA_VersoPagedView*)versoPagedView numberOfPagesAheadToPrefetch:(NSUInteger)afterPageIndex;
- (NSUInteger) versoPagedView:(ETA_VersoPagedView*)versoPagedView numberOfPagesBehindToPrefetch:(NSUInteger)beforePageIndex;

// defaults to the page number (pageIndex+1)
- (NSAttributedString*) versoPagedView:(ETA_VersoPagedView*)versoPagedView pageNumberLabelStringForPageIndex:(NSUInteger)pageIndex;

// defaults to black
- (UIColor*) versoPagedView:(ETA_VersoPagedView*)versoPagedView pageNumberLabelColorForPageIndex:(NSUInteger)pageIndex;

- (UIView*) outroViewForVersoPagedView:(ETA_VersoPagedView*)versoPagedView;
- (CGFloat) outroWidthForVersoPagedView:(ETA_VersoPagedView*)versoPagedView;

@end
