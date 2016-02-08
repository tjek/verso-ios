
#import <UIKit/UIKit.h>

#import "ETA_VersoPageImageURLFetcher.h"

// An implementation of the VersoPageImageFetcher that uses SDWebImage
@interface ETA_VersoPageImageURLFetcher_SDWebImage : NSObject <ETA_VersoPageImageURLFetcher>

+ (instancetype) sharedImageFetcher;

@end