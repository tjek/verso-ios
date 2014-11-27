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

@interface ETA_VersoPagedView : UIView


/**
 *  Whether we show only 1 page on the screen at a time.
 *  Will trigger a reload of the data
 */
@property (nonatomic, assign) BOOL singlePageMode;

@property (nonatomic, assign) BOOL showHotspots;
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated;


// pageIndex will be clamped within valid number of pages

// the index of the first visible page
@property (nonatomic, assign, readonly) NSUInteger currentPageIndex;

- (void) goToPageIndex:(NSInteger)pageIndex animated:(BOOL)animated;


@property (nonatomic, assign, readonly) NSRange visiblePageIndexRange;


/**
 *  Trigger a re-request of the page data for this VersoPagedView
 *
 *  This is automatically called when it is added to a new superview
 */
- (void) reloadPages;


@property (nonatomic, weak) id<ETA_VersoPagedViewDataSource> dataSource;
@property (nonatomic, weak) id<ETA_VersoPagedViewDelegate> delegate;

@end








#pragma mark - Data Source

@protocol ETA_VersoPagedViewDataSource <NSObject>

@required
- (NSUInteger) numberOfPagesInVersoPagedView:(ETA_VersoPagedView*)versoPagedView;

- (NSURL*) versoPagedView:(ETA_VersoPagedView*)versoPagedView imageURLForPageIndex:(NSUInteger)pageIndex withMaxSize:(CGSize)maxPageSize isZoomImage:(BOOL)isZoomImage;


@optional
- (NSDictionary*) versoPagedView:(ETA_VersoPagedView*)versoPagedView hotspotRectsForPageIndex:(NSUInteger)pageIndex;

@end



#pragma mark - Delegate

@protocol ETA_VersoPagedViewDelegate <NSObject>

////////////////////////////////////////////////////////////////////////////////
/// @name Callback Events
////////////////////////////////////////////////////////////////////////////////

@optional

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didChangeVisiblePageIndexRangeFrom:(NSRange)previousVisiblePageIndexRange;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didTapLocation:(CGPoint)tapLocation normalizedPoint:(CGPoint)normalizedPoint onPageIndex:(NSUInteger)pageIndex;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didLongPressLocation:(CGPoint)longPressLocation normalizedPoint:(CGPoint)normalizedPoint onPageIndex:(NSUInteger)pageIndex;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex;





////////////////////////////////////////////////////////////////////////////////
/// @name Styling a page
////////////////////////////////////////////////////////////////////////////////

@optional

/**
 *  What background color to place behind the page image for a specific page
 *
 *  If not implemented, or you return `nil`, the default is for the background to be transparent.
 *
 *  @param versoPagedView   The paged view whose pages will be colored
 *  @param pageIndex         The page index that will be colored (starting at 0)
 *
 *  @return The color to be drawn behind the page image.
 *
 *  @since v1.0
 */
- (UIColor*) versoPagedView:(ETA_VersoPagedView*)versoPagedView backgroundColorForPageIndex:(NSUInteger)pageIndex;



// default 3 if not implemented
- (NSUInteger) versoPagedView:(ETA_VersoPagedView*)versoPagedView numberOfPagesAheadToPrefetch:(NSUInteger)afterPageIndex;



@end
