//
//  SVGAPreDownload.m
//  SVGAPlayer
//
//  Created by song.meng on 2023/1/3.
//

#import "SVGAPreDownload.h"
#import "SVGAParser.h"

@interface SVGAParser (removeCache)
/// 避免外部调用，在SVGAParser.m中实现
+ (void)removeDiskCacheAvoidUrls:(NSSet <NSURL *>*_Nullable)urls;
@end


@interface SVGAPreDownload()

// 记录需要缓存的svga，清理缓存时过滤掉这些资源
@property (nonatomic, strong) NSMutableSet *cacheSet;
@property (nonatomic, strong) dispatch_semaphore_t  lock;
@property (nonatomic, strong) NSOperationQueue  *downloadQueue;

@end

@implementation SVGAPreDownload

+ (instancetype)shareInstance {
    static SVGAPreDownload *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
        _cacheSet = [NSMutableSet set];
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 4;
    }
    return self;
}

- (void)predownloadSVGAWithUrls:(NSArray *)urls {
    if (![urls isKindOfClass:[NSArray class]] || urls.count < 1) {
        return;
    }
    
    NSMutableArray *filterArray = [NSMutableArray array];
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    for (NSString * str in urls) {
        if (![_cacheSet containsObject:str]) {
            [filterArray addObject:str];
        } else {
            [_cacheSet addObject:str];
        }
    }
    dispatch_semaphore_signal(_lock);
    
    for (NSString *str in filterArray) {
        NSURL *url = nil;
        if ([str isKindOfClass:[NSURL class]]) {
            url = (NSURL *)str;
        } else {
            url = [NSURL URLWithString:str];
        }
        
        [[SVGAParser new] parseWithURL:url completionBlock:nil failureBlock:^(NSError * _Nullable error) {
            // 下载失败
            [self tryDownloadAgain:url];
            NSLog(@"songm -- svga下载失败");
        }];
    }
}

// 下载失败，重试一次
- (void)tryDownloadAgain:(NSURL *)url {
    int time = arc4random() % 5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[SVGAParser new] parseWithURL:url completionBlock:nil failureBlock:nil];
    });
}

- (void)clearDiskCache {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    NSSet *set = [_cacheSet copy];
    dispatch_semaphore_signal(_lock);
    
    [SVGAParser removeDiskCacheAvoidUrls:set];
}

@end
