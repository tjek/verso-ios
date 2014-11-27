//
//  ETA_VersoSinglePageContentsView.h
//  Verso
//
//  Created by Laurie Hufford on 20/11/2014.
//  Copyright (c) 2014 Laurie Hufford. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ETA_VersoSinglePageContentsView : UIView

@property (nonatomic, strong) UIImageView* imageView;

@property (nonatomic, assign) BOOL showHotspots;
- (void) setShowHotspots:(BOOL)showHotspots animated:(BOOL)animated;

- (void) addHotspotRects:(NSDictionary*)hotspotRects; //relative to the imageView
- (void) clearHotspotRects;

@end
