//
//  ViewController.m
//  Verso Example
//
//  Created by Laurie Hufford on 26/11/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ViewController.h"

#import <Verso/ETA_VersoPagedView.h>


@interface ViewController () <ETA_VersoPagedViewDelegate, ETA_VersoPagedViewDataSource>

@property (nonatomic, strong) ETA_VersoPagedView* pagedView;
@property (nonatomic, strong) NSArray* pageImageURLStrings;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:22.0/255.0 green:32.0/255.0 blue:42.0/255.0 alpha:1.0];
    [self.view addSubview:self.pagedView];
    
    self.pagedView.alpha = 0.0;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void) viewDidAppear:(BOOL)animated
{
    [UIView animateWithDuration:0.5 animations:^{
        self.pagedView.alpha = 1.0;
    }];
}

- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Show two images if the view is going landscape
    BOOL isLandscape = self.view.bounds.size.width > self.view.bounds.size.height;
    [self.pagedView setSinglePageMode:!isLandscape];
}




- (ETA_VersoPagedView*) pagedView
{
    if (!_pagedView)
    {
        _pagedView = [[ETA_VersoPagedView alloc] initWithFrame:self.view.bounds];
        _pagedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        _pagedView.delegate = self;
        _pagedView.dataSource = self;
        
        _pagedView.showHotspots = YES;
    }
    return _pagedView;
}




#pragma mark - Page data

// The view and zoom URLs for the pages. Note that the zoom url is optional.
- (NSArray*) pageImageURLStrings
{
    if (!_pageImageURLStrings)
    {
        _pageImageURLStrings = @[
                                 // Overview
                                 @{@"view": @"http://upload.wikimedia.org/wikipedia/commons/a/a9/Planets2013.jpg"},
                                 
                                 // Mercury
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Mercury_in_color_-_Prockter07_centered.jpg/484px-Mercury_in_color_-_Prockter07_centered.jpg",
                                    @"zoom":@"http://upload.wikimedia.org/wikipedia/commons/3/30/Mercury_in_color_-_Prockter07_centered.jpg" },
                                 // Venus
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Venus_globe.jpg/480px-Venus_globe.jpg",
                                    @"zoom":@"http://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Venus_globe.jpg/1024px-Venus_globe.jpg" },
                                 // Earth
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Earth_Eastern_Hemisphere.jpg/480px-Earth_Eastern_Hemisphere.jpg",
                                    @"zoom":@"http://upload.wikimedia.org/wikipedia/commons/6/6f/Earth_Eastern_Hemisphere.jpg" },
                                 // Mars
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Water_ice_clouds_hanging_above_Tharsis_PIA02653_black_background.jpg/480px-Water_ice_clouds_hanging_above_Tharsis_PIA02653_black_background.jpg",
                                    @"zoom":@"http://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Water_ice_clouds_hanging_above_Tharsis_PIA02653_black_background.jpg/1024px-Water_ice_clouds_hanging_above_Tharsis_PIA02653_black_background.jpg" },
                                 // Jupiter (Note: zoom is optional)
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/5/5a/Jupiter_by_Cassini-Huygens.jpg" },
                                 // Saturn
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/thumb/2/25/Saturn_PIA06077.jpg/640px-Saturn_PIA06077.jpg",
                                    @"zoom": @"http://upload.wikimedia.org/wikipedia/commons/2/25/Saturn_PIA06077.jpg"},
                                 // Uranus
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Uranus2.jpg/600px-Uranus2.jpg",
                                    @"zoom": @"http://upload.wikimedia.org/wikipedia/commons/3/3d/Uranus2.jpg"},
                                 // Neptune
                                 @{ @"view": @"http://upload.wikimedia.org/wikipedia/commons/0/06/Neptune.jpg" },
                                 ];
    }
    return _pageImageURLStrings;
}

// The normalized rectangles of the planets on the first page
- (NSDictionary*) planetOverviewHotspotRects
{
    return @{
             @"mercury": [NSValue valueWithCGRect:CGRectMake(0.212, 0.444, 0.024, 0.045)],
             @"venus": [NSValue valueWithCGRect:CGRectMake(0.257, 0.444, 0.024, 0.045)],
             @"earth": [NSValue valueWithCGRect:CGRectMake(0.317, 0.444, 0.024, 0.045)],
             @"mars": [NSValue valueWithCGRect:CGRectMake(0.371, 0.444, 0.024, 0.045)],
             @"jupiter": [NSValue valueWithCGRect:CGRectMake(0.424, 0.352, 0.130, 0.238)],
             @"saturn": [NSValue valueWithCGRect:CGRectMake(0.609, 0.352, 0.130, 0.238)],
             @"uranus": [NSValue valueWithCGRect:CGRectMake(0.765, 0.422, 0.057, 0.095)],
             @"neptune": [NSValue valueWithCGRect:CGRectMake(0.846, 0.422, 0.057, 0.095)],
             };
}

// The page index of the hotspot keys
- (NSUInteger) pageIndexForPlanetKey:(NSString*)planetKey
{
    NSArray* planetKeys = @[NSNull.null,
                            @"mercury",
                            @"venus",
                            @"earth",
                            @"mars",
                            @"jupiter",
                            @"saturn",
                            @"uranus",
                            @"neptune"
                            ];
    
    NSUInteger index = [planetKeys indexOfObject:planetKey];
    return index;
}





#pragma mark - Verso DataSource

- (NSUInteger)numberOfPagesInVersoPagedView:(ETA_VersoPagedView *)versoPagedView
{
    return self.pageImageURLStrings.count;
}

- (NSURL*)versoPagedView:(ETA_VersoPagedView *)versoPagedView imageURLForPageIndex:(NSUInteger)pageIndex withMaxSize:(CGSize)maxPageSize isZoomImage:(BOOL)isZoomImage
{
    NSDictionary* imgsForPage = self.pageImageURLStrings[pageIndex];
    
    NSString* imageURLString = nil;
    if (isZoomImage)
        imageURLString = imgsForPage[@"zoom"];
    
    if (!imageURLString)
        imageURLString = imgsForPage[@"view"];
    
    return imageURLString ? [NSURL URLWithString:imageURLString] : nil;
}

- (NSDictionary*) versoPagedView:(ETA_VersoPagedView*)versoPagedView hotspotRectsForPageIndex:(NSUInteger)pageIndex
{
    if (pageIndex == 0)
    {
        return [self planetOverviewHotspotRects];
    }
    return nil;
}


#pragma mark - Verso Delegate

- (void)versoPagedView:(ETA_VersoPagedView *)versoPagedView didTapLocation:(CGPoint)tapLocation onPageIndex:(NSUInteger)pageIndex hittingHotspotsWithKeys:(NSArray*)hotspotKeys
{
    // are we on the first page, and did we tap inside a hotspot rect? Go to that page
    if (pageIndex == 0)
    {
        NSString* planetKey = [hotspotKeys firstObject];
        if (planetKey)
        {
            NSUInteger planetPageIndex = [self pageIndexForPlanetKey:planetKey];
            if (planetPageIndex != NSNotFound)
            {
                [versoPagedView goToPageIndex:planetPageIndex animated:YES];
                return;
            }
        }
    }
    
    // tap on right side - go to next page
    if (tapLocation.x > CGRectGetMidX(versoPagedView.bounds))
    {
        NSInteger nextPageIndex = versoPagedView.visiblePageIndexRange.location + versoPagedView.visiblePageIndexRange.length;
        [versoPagedView goToPageIndex:nextPageIndex animated:YES];
    }
    // tap on left side - go to prev page
    else
    {
        NSInteger prevPageIndex = versoPagedView.visiblePageIndexRange.location - 1;        
        [versoPagedView goToPageIndex:prevPageIndex animated:YES];

    }
}

@end
