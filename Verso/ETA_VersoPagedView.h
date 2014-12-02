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

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didChangeVisiblePageIndexRangeFrom:(NSRange)previousVisiblePageIndexRange;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didLongPressLocation:(CGPoint)longPressLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

- (void) versoPagedView:(ETA_VersoPagedView *)versoPagedView didSetImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage onPageIndex:(NSUInteger)pageIndex;





////////////////////////////////////////////////////////////////////////////////
/// @name Styling a page
////////////////////////////////////////////////////////////////////////////////

@optional


// default 3 if not implemented
- (NSUInteger) versoPagedView:(ETA_VersoPagedView*)versoPagedView numberOfPagesAheadToPrefetch:(NSUInteger)afterPageIndex;

// defaults to the page number (pageIndex+1)
- (NSAttributedString*) versoPagedView:(ETA_VersoPagedView*)versoPagedView pageNumberLabelStringForPageIndex:(NSUInteger)pageIndex;

// defaults to black
- (UIColor*) versoPagedView:(ETA_VersoPagedView*)versoPagedView pageNumberLabelColorForPageIndex:(NSUInteger)pageIndex;


@end
