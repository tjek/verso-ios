

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ETA_VersoPageImageURLFetcher <NSObject>

- (void) cancelAllImageFetchJobs;
- (void) cancelImageFetchForURL:(NSURL*)url;

- (void) fetchPageImageWithURL:(NSURL*)url progressive:(BOOL)progressiveDownload completion:(void (^)(UIImage* __nullable image, NSError* __nullable error, BOOL finished))completion;

- (void) prefetchPageImageURLs:(NSArray<NSURL*>*)urls;

@end



NS_ASSUME_NONNULL_END
