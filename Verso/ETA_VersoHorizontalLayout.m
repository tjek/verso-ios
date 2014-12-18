//
//  ETA_VersoHorizontalLayout.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 03/12/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA_VersoHorizontalLayout.h"

@interface ETA_VersoHorizontalLayout ()

@property (nonatomic, assign) CGRect oldCollectionViewBounds;

@end

@implementation ETA_VersoHorizontalLayout

- (instancetype) init
{
    if (self = [super init])
    {
        _oldCollectionViewBounds = CGRectNull;
        self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        self.minimumInteritemSpacing = 0.0;
        self.minimumLineSpacing = 0.0;
        self.sectionInset = UIEdgeInsetsZero;
    }
    return self;
}

- (CGSize) itemSize
{
    CGSize maxItemSize = [self _collectionViewSizeMinusInsets];

    return maxItemSize;
}

- (CGSize) _collectionViewSizeMinusInsets
{
    CGSize collectionSize = self.collectionView.bounds.size;
    collectionSize.height -= self.collectionView.contentInset.top + self.collectionView.contentInset.bottom;
    collectionSize.width -= self.collectionView.contentInset.left + self.collectionView.contentInset.right;
    return collectionSize;
}


// invalidate layout if size changed
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    CGRect oldBounds = self.collectionView.bounds;
    if (!CGSizeEqualToSize(oldBounds.size, newBounds.size))
    {
        return YES;
    }
    return NO;
}


// make sure that we always land on the current page spread, based on the bounds we are animating from
-(CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
    CGPoint targetContentOffset = [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
    
    if (!CGRectIsNull(self.oldCollectionViewBounds))
    {
        NSInteger spreadIndex = ceil(proposedContentOffset.x / self.oldCollectionViewBounds.size.width);
        
        targetContentOffset.x = spreadIndex * self.collectionView.bounds.size.width;
    }
    return targetContentOffset;
}

// turn off animations for bounds change, and save the bounds we are animating from
- (void)prepareForAnimatedBoundsChange:(CGRect)oldBounds
{
    self.oldCollectionViewBounds = oldBounds;
    [UIView setAnimationsEnabled:NO];
    [super prepareForAnimatedBoundsChange:oldBounds];
}
// enable animations again, and invalidate the saved bounds
- (void) finalizeAnimatedBoundsChange
{
    [super finalizeAnimatedBoundsChange];
    [UIView setAnimationsEnabled:YES];
    self.oldCollectionViewBounds = CGRectNull;
}

@end
