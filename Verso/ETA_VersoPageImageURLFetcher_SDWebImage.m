
#import "ETA_VersoPageImageURLFetcher_SDWebImage.h"

#import <SDWebImage/SDWebImageManager.h>
#import <SDWebImage/SDWebImagePrefetcher.h>

@interface ETA_VersoPageImageURLFetcher_SDWebImage () <SDWebImageManagerDelegate>

@property (nonatomic, strong) SDWebImageManager* imageManager;
@property (nonatomic, strong) SDWebImagePrefetcher* imagePrefetcher;

 @property (nonatomic, strong) NSMutableDictionary<NSString*,id <SDWebImageOperation>>* imageFetchOpsByCacheKey;

@end

@implementation ETA_VersoPageImageURLFetcher_SDWebImage

+ (instancetype) sharedImageFetcher
{
    static id kSharedImageFetcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kSharedImageFetcher = [self new];
    });
    return kSharedImageFetcher;
}

- (void)dealloc
{
    [self cancelAllImageFetchJobs];
    
    _imageManager = nil;
    _imagePrefetcher = nil;
}


- (SDWebImageManager*) imageManager
{
    if (!_imageManager)
    {
        _imageManager = [SDWebImageManager new];
//        [_imageManager.imageCache clearDisk];
//        [_imageManager.imageCache clearMemory];
    }
    return _imageManager;
}


- (SDWebImagePrefetcher*) imagePrefetcher
{
    if (!_imagePrefetcher)
    {
        _imagePrefetcher = [SDWebImagePrefetcher new];
        _imagePrefetcher.manager.delegate = self;
    }
    return _imagePrefetcher;
}

- (NSString*) cacheKeyForURL:(NSURL*)url
{
    return [self.imageManager cacheKeyForURL:url];
}



- (void) cancelImageFetchForURL:(NSURL*)url
{
    NSString* cacheKey = [self cacheKeyForURL:url];
    
    id <SDWebImageOperation> op = self.imageFetchOpsByCacheKey[cacheKey];
    if (op) {
        [op cancel];
        self.imageFetchOpsByCacheKey[cacheKey] = nil;
    }
}


- (void) fetchPageImageWithURL:(NSURL*)url progressive:(BOOL)progressiveDownload completion:(void (^)(UIImage* image, NSError* error, BOOL finished))completion
{
    NSString* cacheKey = [self.imageManager cacheKeyForURL:url];
    
    // we are currently in the process of fetching the image, so no-op
    if (self.imageFetchOpsByCacheKey[cacheKey]) {
//        NSLog(@" (already fetching %@)", url.lastPathComponent);
        return;
    }
    
    
    
    
    
//    NSTimeInterval startTime = CFAbsoluteTimeGetCurrent();
//    NSLog(@"fetchPageImage start %@ (%@)", url.lastPathComponent, @(startTime));
    
    
    SDWebImageOptions options = SDWebImageRetryFailed;
    if (progressiveDownload) {
        options |= SDWebImageProgressiveDownload;
    }
    
    __block BOOL fetchFinished = NO;
    __weak __typeof(self) weakSelf = self;
    id <SDWebImageOperation> fetchOp = [self.imageManager downloadImageWithURL:url options:options progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        
        if (finished) {
            fetchFinished = YES;
            weakSelf.imageFetchOpsByCacheKey[cacheKey] = nil;
        }

//        { // debug
//            NSTimeInterval durationTime = CFAbsoluteTimeGetCurrent() - startTime;
//            NSString* cacheTypeStr = (cacheType == SDImageCacheTypeDisk) ? @"disk" : (cacheType == SDImageCacheTypeMemory) ? @"memory" : @"none";
//            
//            if (!finished)
//            {
//                NSLog(@" ...progress [%.3fs] cache:%@ %@ (%@)", durationTime, cacheTypeStr, url.lastPathComponent, @(startTime));
//            }
//            else {
//                NSLog(@"finished [%.3fs] cache:%@ %@ (%@)", durationTime, cacheTypeStr, url.lastPathComponent, @(startTime));
//            }
//        }
        
        if (completion) {
            completion(image, error, finished);
        }
    }];
    
    // the fetch wasnt performed in the same run loop, so the operation for later
    if (fetchFinished == NO && fetchOp) {
        self.imageFetchOpsByCacheKey[cacheKey] = fetchOp;
    }
}
- (void) prefetchPageImageURLs:(NSArray<NSURL*>*)urls
{
    if (!urls.count)
        return;
    
    // only prefetch URLs that we arent currently fetching
    NSMutableArray<NSURL*>* urlsToFetch = [[NSMutableArray alloc] initWithCapacity:urls.count];
    for (NSURL* url in urls)
    {
        NSString* cacheKey = [self cacheKeyForURL:url];
        if (!self.imageFetchOpsByCacheKey[cacheKey]) {
            [urlsToFetch addObject:url];
        }
//        else {
//            NSLog(@"wont prefetch (already prefetching) %@", url.lastPathComponent);
//        }
    }
    
    // TODO: what happens when you call this and there are already some pending?
    // they get cancelled... shouldnt they be postponed?
    self.imagePrefetcher.options =  SDWebImageLowPriority | SDWebImageRetryFailed;

//    NSLog(@"imagePrefetch start [0/%@]", @(urls.count));
//    NSTimeInterval startTime = CFAbsoluteTimeGetCurrent();
    
    [self.imagePrefetcher prefetchURLs:urls];
}


- (void) cancelAllImageFetchJobs
{
    [_imageManager cancelAll];
    [_imageFetchOpsByCacheKey removeAllObjects];
    [_imagePrefetcher cancelPrefetching];
}





- (NSMutableDictionary*) imageFetchOpsByCacheKey
{
    if (!_imageFetchOpsByCacheKey)
    {
        _imageFetchOpsByCacheKey = [NSMutableDictionary new];
    }
    return _imageFetchOpsByCacheKey;
}


//- (BOOL)imageManager:(SDWebImageManager *)imageManager shouldDownloadImageForURL:(NSURL *)imageURL
//{
//    if (imageManager == self.imagePrefetcher.manager) {
//        NSLog(@"prefetch should download url:%@", imageURL.lastPathComponent);
//    }
//    return YES;
//}

@end
