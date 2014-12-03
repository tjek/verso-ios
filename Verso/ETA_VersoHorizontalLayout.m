//
//  ETA_VersoHorizontalLayout.m
//  ETA-SDK
//
//  Created by Laurie Hufford on 03/12/2014.
//  Copyright (c) 2014 eTilbudsavis. All rights reserved.
//

#import "ETA_VersoHorizontalLayout.h"

@implementation ETA_VersoHorizontalLayout

- (instancetype) init
{
    if (self = [super init])
    {
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

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    // To avoid the collection view complaining when the content offset is changed before the content inset.
    // This happens when orientation changes and the containing VC autoamtically adjusts the contentInset
    if (CGSizeEqualToSize(newBounds.size, self.collectionView.bounds.size))
    {
        return NO;
    }
    
    BOOL shouldInvalidate = [super shouldInvalidateLayoutForBoundsChange:newBounds];
    return shouldInvalidate;
}
@end
