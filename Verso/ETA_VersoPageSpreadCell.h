//
//  ETA_VersoPageSpreadCell.h
//  Verso
//
//  Created by Laurie Hufford on 04/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ETA_VersoPageSpreadCellDelegate;

typedef enum : NSUInteger {
    ETA_VersoPageSpreadSide_Primary = 0,
    ETA_VersoPageSpreadSide_Secondary = 1
} ETA_VersoPageSpreadSide;



@interface ETA_VersoPageSpreadCell : UICollectionViewCell

@property (nonatomic, weak) id<ETA_VersoPageSpreadCellDelegate> delegate;

@property (nonatomic, strong, readonly) UIScrollView* zoomView;

- (BOOL) anyImagesLoaded;
- (BOOL) allImagesLoaded;

- (void) setPageIndex:(NSInteger)pageIndex forSide:(ETA_VersoPageSpreadSide)pageSide;
- (NSInteger) pageIndexForSide:(ETA_VersoPageSpreadSide)pageSide;


- (void) setImage:(UIImage*)image isZoomImage:(BOOL)isZoomImage forSide:(ETA_VersoPageSpreadSide)pageSide animated:(BOOL)animated;

- (BOOL) isShowingZoomImageForSide:(ETA_VersoPageSpreadSide)pageSide;



@property (nonatomic, assign) BOOL showHotspots;
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated;
- (void) setHotspotRects:(NSDictionary *)hotspotRects forSide:(ETA_VersoPageSpreadSide)pageSide normalizedByWidth:(BOOL)normalizedByWidth;




@property (nonatomic, assign) BOOL singlePageMode;
- (void) setSinglePageMode:(BOOL)singlePageMode animated:(BOOL)animated;


/**
 *  Make the visible page images fit to the width of the page.
 *  If the image is taller than the container page, it will allow scrolling downwards
 *  If false (default), it will fit the images to the height of the container view
 */
@property (nonatomic, assign) BOOL fitToWidth;
- (void) setFitToWidth:(BOOL)fitToWidth animated:(BOOL)animated;



/**
 *  How far zoomed in we are right now
 */
@property (nonatomic, assign, readonly) CGFloat zoomScale;


/**
 *  How far the page will zoom in. Default 4.0x
 */
@property (nonatomic, assign) CGFloat maximumZoomScale;

@end




@protocol ETA_VersoPageSpreadCellDelegate <NSObject>

@optional
- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didZoom:(CGFloat)zoomScale;
- (void) versoPageSpreadWillBeginZooming:(ETA_VersoPageSpreadCell *)pageSpreadCell;
- (void) versoPageSpreadDidEndZooming:(ETA_VersoPageSpreadCell *)pageSpreadCell;

- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didReceiveTapAtPoint:(CGPoint)locationInPageView onPageSide:(ETA_VersoPageSpreadSide)pageSide hittingHotspotsWithKeys:(NSArray*)hotspotKeys;
- (void) versoPageSpread:(ETA_VersoPageSpreadCell*)pageSpreadCell didReceiveLongPressAtPoint:(CGPoint)locationInPageView onPageSide:(ETA_VersoPageSpreadSide)pageSide hittingHotspotsWithKeys:(NSArray*)hotspotKeys;

@end

