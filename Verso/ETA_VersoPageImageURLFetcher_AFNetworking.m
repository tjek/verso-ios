
#import "ETA_VersoPageImageURLFetcher_AFNetworking.h"

#import <AFNetworking/AFImageDownloader.h>

@interface ETA_VersoPageImageURLFetcher_AFNetworking ()

@property (nonatomic, strong) AFImageDownloader* imageDownloader;

 @property (nonatomic, strong) NSMutableDictionary<NSString*, AFImageDownloadReceipt*>* imageFetchOpsByCacheKey;

@end

@implementation ETA_VersoPageImageURLFetcher_AFNetworking

- (void)dealloc
{
    [self cancelAllImageFetchJobs];
    
    _imageDownloader = nil;
}



- (AFImageDownloader*) imageDownloader
{
    if (!_imageDownloader)
    {
        // use a unique image downloader, so that it doesnt block, and isnt blocked by, any other image fetching that uses the `defaultInstance`
        _imageDownloader = [AFImageDownloader new];
    }
    return _imageDownloader;
}

- (NSString*) cacheKeyForURL:(NSURL*)url
{
    return [url absoluteString];
}


- (NSMutableDictionary*) imageFetchOpsByCacheKey
{
    if (!_imageFetchOpsByCacheKey)
    {
        _imageFetchOpsByCacheKey = [NSMutableDictionary new];
    }
    return _imageFetchOpsByCacheKey;
}


- (void) fetchPageImageWithURL:(NSURL*)url priority:(AFImageDownloadPrioritization)priority completion:(void (^)(UIImage* image, NSError* error, BOOL finished))completion
{
    [self fetchPageImageWithURL:url priority:priority remainingRetries:1 completion:completion];
}
- (void) fetchPageImageWithURL:(NSURL*)url priority:(AFImageDownloadPrioritization)priority remainingRetries:(NSUInteger)remainingRetries completion:(void (^)(UIImage* image, NSError* error, BOOL finished))completion
{
    NSString* cacheKey = [self cacheKeyForURL:url];
    
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    
    self.imageDownloader.downloadPrioritizaton = priority;
    
    __weak __typeof(self) weakSelf = self;
    AFImageDownloadReceipt* receipt = [self.imageDownloader downloadImageForURLRequest:req success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;

        strongSelf.imageFetchOpsByCacheKey[cacheKey] = nil;
        
        if (completion)
            completion(responseObject, nil, YES);
        
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;

        if (remainingRetries > 0 && error.code == NSURLErrorNetworkConnectionLost)
        {
            // There is an issue with NSURLSession and keepAlive, where _sometimes_ there is a network connection lost error.
            // The most sure-fire way to solve this is to just retry the request 1 more time.
            // For more details:
            //  - https://github.com/AFNetworking/AFNetworking/issues/2801
            //  - http://stackoverflow.com/questions/25372318/error-domain-nsurlerrordomain-code-1005-the-network-connection-was-lost/25996971#25996971
            [strongSelf fetchPageImageWithURL:url priority:priority remainingRetries:remainingRetries-1 completion:completion];
        }
        else
        {
            strongSelf.imageFetchOpsByCacheKey[cacheKey] = nil;
            
            if (completion)
                completion(nil, error, YES);
        }
    }];
    
    // save the receipt based on the url
    if (receipt && cacheKey)
    {
        self.imageFetchOpsByCacheKey[cacheKey] = receipt;
    }
}




#pragma mark - URL Fetcher protcol

- (void) fetchPageImageWithURL:(NSURL*)url progressive:(BOOL)progressiveDownload completion:(void (^)(UIImage* image, NSError* error, BOOL finished))completion
{
    [self fetchPageImageWithURL:url priority:AFImageDownloadPrioritizationLIFO completion:completion];
}

- (void) prefetchPageImageURLs:(NSArray<NSURL*>*)urls
{
    if (!urls.count)
        return;
    
    // only prefetch URLs that we arent currently fetching
    for (NSURL* url in urls)
    {
        NSString* cacheKey = [self cacheKeyForURL:url];
        if (!self.imageFetchOpsByCacheKey[cacheKey]) {
            [self fetchPageImageWithURL:url priority:AFImageDownloadPrioritizationFIFO completion:nil];
        }
    }
}


- (void) cancelAllImageFetchJobs
{
    [_imageFetchOpsByCacheKey enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, AFImageDownloadReceipt * _Nonnull obj, BOOL * _Nonnull stop) {
        [_imageDownloader cancelTaskForImageDownloadReceipt:obj];
    }];
    [_imageFetchOpsByCacheKey removeAllObjects];
}
- (void) cancelImageFetchForURL:(NSURL*)url
{
    NSString* cacheKey = [self cacheKeyForURL:url];
    
    AFImageDownloadReceipt* receipt = self.imageFetchOpsByCacheKey[cacheKey];
    
    if (receipt) {
        [_imageDownloader cancelTaskForImageDownloadReceipt:receipt];
        
        _imageFetchOpsByCacheKey[cacheKey] = nil;
    }
}





@end
