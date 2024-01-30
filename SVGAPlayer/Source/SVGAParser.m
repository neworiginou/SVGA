//
//  SVGAParser.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 16/6/17.
//  Copyright © 2016年 UED Center. All rights reserved.
//

#import "SVGAParser.h"
#import "SVGAVideoEntity.h"
#import "Svga.pbobjc.h"
#import <zlib.h>
#import <ZipArchive/ZipArchive.h>
#import <CommonCrypto/CommonDigest.h>
#import "SVGAVideoMemoryCache.h"

#define ZIP_MAGIC_NUMBER "PK"
typedef NSMapTable<NSString *, id> SVGASessionTasksDictionary;
NSString * const SVGASessionTaskKey = @"setSessionTaskKey";

@interface SVGAParser ()
@property (nonatomic, strong) SVGASessionTasksDictionary *taskDictionry;
@end

@implementation SVGAParser

static NSOperationQueue *parseQueue;
static NSOperationQueue *unzipQueue;

+ (void)initialize {
    parseQueue = [NSOperationQueue new];
    parseQueue.maxConcurrentOperationCount = 8;
    unzipQueue = [NSOperationQueue new];
    unzipQueue.maxConcurrentOperationCount = 1;
}

- (instancetype)init {
    if (self = [super init]) {
        _enabledMemoryCache = YES;
        _taskDictionry = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
    }
    return self;
}

- (void)parseWithURL:(nonnull NSURL *)URL
     completionBlock:(void ( ^ _Nonnull )(SVGAVideoEntity * _Nullable videoItem))completionBlock
        failureBlock:(void ( ^ _Nullable)(NSError * _Nullable error))failureBlock {
    [self parseWithURLRequest:[NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:20.0]
    completionBlock:completionBlock
       failureBlock:failureBlock];
}

- (void)parseWithURLRequest:(NSURLRequest *)URLRequest completionBlock:(void (^)(SVGAVideoEntity * _Nullable))completionBlock failureBlock:(void (^)(NSError * _Nullable))failureBlock {
    if (URLRequest.URL == nil) {
        if (failureBlock) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                failureBlock([NSError errorWithDomain:@"SVGAParser" code:411 userInfo:@{NSLocalizedDescriptionKey: @"URL cannot be nil."}]);
            }];
        }
        return;
    }
    
    // 查找缓存
    if ([self findCacheWithUrl:URLRequest.URL completionBlock:completionBlock failureBlock:failureBlock]) {
        return;
    }
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:URLRequest
                                                             completionHandler:^(NSData * _Nullable data,
                                                                                 NSURLResponse * _Nullable response,
                                                                                 NSError * _Nullable error) {
        if (error == nil && data != nil) {
            NSString *cacheKey = [[self class] cacheKey:URLRequest.URL];
            [self parseWithData:data cacheKey:cacheKey completionBlock:^(SVGAVideoEntity * _Nonnull videoItem) {
                if (completionBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        completionBlock(videoItem);
                    }];
                }
                
                [self saveToDictionary:data cacheKey:cacheKey]; // 磁盘缓存
            } failureBlock:^(NSError * _Nonnull error) {
                [self clearCache:cacheKey];
                if (failureBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        failureBlock(error);
                    }];
                }
            }];
        }
        else if (failureBlock) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                failureBlock(error);
            }];
        }
    }];
    
    [task resume];
    @synchronized (self) {
        [self svgaCancelLoadWithKey];
        if (task) {
            [self.taskDictionry setObject:task forKey:SVGASessionTaskKey];
        }
    }
}

- (void)svgaCancelLoadWithKey {
    NSURLSessionTask *task = [self.taskDictionry objectForKey:SVGASessionTaskKey];
    if (task) {
        [task cancel];
        [self.taskDictionry removeObjectForKey:SVGASessionTaskKey];
    }
}

- (BOOL)findCacheWithUrl:(NSURL *)url
         completionBlock:(void (^)(SVGAVideoEntity * _Nullable))completionBlock
            failureBlock:(void (^)(NSError * _Nullable))failureBlock{
    if ([self readMemoryWithURL:url completeBlock:completionBlock]) {
        return YES;
    }

    NSString *cacheKey = [[self class] cacheKey:url];
    NSString *path = [[self class] cacheDirectory:cacheKey];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSData *data = [NSData dataWithContentsOfFile:[[self class] cacheDirectory:cacheKey] options:NSDataReadingMapped error:NULL];
        [self parseWithData:data cacheKey:cacheKey completionBlock:^(SVGAVideoEntity * _Nonnull videoItem) {
            if (completionBlock) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionBlock(videoItem);
                }];
            }
        } failureBlock:^(NSError * _Nonnull error) {
            [self clearCache:cacheKey];
            if (failureBlock) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    failureBlock(error);
                }];
            }
        }];
        return YES;
    }
    return NO;
}

- (void)parseWithNamed:(NSString *)named
              inBundle:(NSBundle *)inBundle
       completionBlock:(void (^)(SVGAVideoEntity * _Nonnull))completionBlock
          failureBlock:(void (^)(NSError * _Nonnull))failureBlock {
    NSString *filePath = [(inBundle ?: [NSBundle mainBundle]) pathForResource:named ofType:@"svga"];
    if (filePath != nil) {
        NSString *cacheKey = [[self class] cacheKey:[NSURL fileURLWithPath:filePath]];
        if ([self readMemoryCacheWithKey:cacheKey completeBlock:completionBlock]) {
            return;
        }
        
        [self parseWithData:[NSData dataWithContentsOfFile:filePath]
                   cacheKey:cacheKey
            completionBlock:completionBlock
               failureBlock:failureBlock];
    } else {
        if (failureBlock) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                failureBlock([NSError errorWithDomain:@"SVGAParser" code:404 userInfo:@{NSLocalizedDescriptionKey: @"File not exist."}]);
            }];
        }
        return;
    }
    [self parseWithData:[NSData dataWithContentsOfFile:filePath]
               cacheKey:[[self class] cacheKey:[NSURL fileURLWithPath:filePath]]
        completionBlock:completionBlock
           failureBlock:failureBlock];
}

- (void)parseWithCacheKey:(nonnull NSString *)cacheKey
          completionBlock:(void ( ^ _Nullable)(SVGAVideoEntity * _Nonnull videoItem))completionBlock
             failureBlock:(void ( ^ _Nullable)(NSError * _Nonnull error))failureBlock {
    if (!completionBlock) {
        return;
    }
    
    if ([self readMemoryCacheWithKey:cacheKey completeBlock:completionBlock]) {
        return;
    }
    
    [parseQueue addOperationWithBlock:^{
        NSString *cacheDir = [[self class] cacheDirectory:cacheKey];
        if ([[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
            NSError *err;
            NSData *protoData = [NSData dataWithContentsOfFile:cacheDir options:NSDataReadingMapped error:NULL];
            SVGAProtoMovieEntity *protoObject = [SVGAProtoMovieEntity parseFromData:protoData error:&err];
            if (!err && [protoObject isKindOfClass:[SVGAProtoMovieEntity class]]) {
                SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithProtoObject:protoObject cacheDir:cacheDir];
                [videoItem resetImagesWithProtoObject:protoObject];
                [videoItem resetSpritesWithProtoObject:protoObject];
                [videoItem resetAudiosWithProtoObject:protoObject];
                if (self.enabledMemoryCache) {
                    [videoItem saveCache:cacheKey];
                }
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionBlock(videoItem);
                }];
            }
            else {
                if (failureBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                    }];
                }
            }
        }
        else {
            NSError *err;
            NSData *JSONData = [NSData dataWithContentsOfFile:[cacheDir stringByAppendingString:@"/movie.spec"]];
            if (JSONData != nil) {
                NSDictionary *JSONObject = [NSJSONSerialization JSONObjectWithData:JSONData options:kNilOptions error:&err];
                if ([JSONObject isKindOfClass:[NSDictionary class]]) {
                    SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithJSONObject:JSONObject cacheDir:cacheDir];
                    [videoItem resetImagesWithJSONObject:JSONObject];
                    [videoItem resetSpritesWithJSONObject:JSONObject];
                    if (self.enabledMemoryCache) {
                        [videoItem saveCache:cacheKey];
                    }

                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        completionBlock(videoItem);
                    }];
                }
            }
            else {
                if (failureBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                    }];
                }
            }
        }
    }];
}

- (void)parseWithData:(nonnull NSData *)data
             cacheKey:(nonnull NSString *)cacheKey
      completionBlock:(void ( ^ _Nullable)(SVGAVideoEntity * _Nonnull videoItem))completionBlock
         failureBlock:(void ( ^ _Nullable)(NSError * _Nonnull error))failureBlock {
    
    if ([self readMemoryCacheWithKey:cacheKey completeBlock:completionBlock]) {
        return;
    }
    
    if (!data || data.length < 4) {
        if (failureBlock) {
            failureBlock(nil);
        }
        return;
    }
    
    if (![SVGAParser isZIPData:data]) {
        // Maybe is SVGA 2.0.0
        [parseQueue addOperationWithBlock:^{
            NSData *inflateData = [self zlibInflate:data];
            NSError *err;
            SVGAProtoMovieEntity *protoObject = [SVGAProtoMovieEntity parseFromData:inflateData error:&err];
            if (!err && [protoObject isKindOfClass:[SVGAProtoMovieEntity class]]) {
                SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithProtoObject:protoObject cacheDir:@""];
                [videoItem resetImagesWithProtoObject:protoObject];
                [videoItem resetSpritesWithProtoObject:protoObject];
                [videoItem resetAudiosWithProtoObject:protoObject];
                if (self.enabledMemoryCache) {
                    [videoItem saveCache:cacheKey];
                }
                if (completionBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        completionBlock(videoItem);
                    }];
                }
            }
        }];
        return ;
    }
    [unzipQueue addOperationWithBlock:^{
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingFormat:@"%u.svga", arc4random()];
        if (data != nil) {
            [data writeToFile:tmpPath atomically:YES];
            NSString *cacheDir = [[self class] cacheDirectory:cacheKey];
            if ([cacheDir isKindOfClass:[NSString class]]) {
                ZipArchive *zipArchive = [[ZipArchive alloc] init];
                BOOL isOpened = [zipArchive UnzipOpenFile:tmpPath];
                if (!isOpened) {
                    if (failureBlock) {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            failureBlock(nil);
                        }];
                    }
                } else {
                    BOOL isUnziped = [zipArchive UnzipFileTo:[[self class] cacheDirectory:cacheKey] overWrite:YES];
                    if (!isUnziped) {
                        if (failureBlock) {
                            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                failureBlock(nil);
                            }];
                        }
                    } else {
                        if ([[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
                            NSError *err;
                            NSData *protoData = [NSData dataWithContentsOfFile:cacheDir options:NSDataReadingMapped error:NULL];
                            SVGAProtoMovieEntity *protoObject = [SVGAProtoMovieEntity parseFromData:protoData error:&err];
                            if (!err) {
                                SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithProtoObject:protoObject cacheDir:cacheDir];
                                [videoItem resetImagesWithProtoObject:protoObject];
                                [videoItem resetSpritesWithProtoObject:protoObject];
                                if (self.enabledMemoryCache) {
                                    [videoItem saveCache:cacheKey];
                                }
                                if (completionBlock) {
                                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                        completionBlock(videoItem);
                                    }];
                                }
                            }
                            else {
                                if (failureBlock) {
                                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                                    }];
                                }
                            }
                        }
                        else {
                            NSError *err;
                            NSData *JSONData = [NSData dataWithContentsOfFile:[cacheDir stringByAppendingString:@"/movie.spec"]];
                            if (JSONData != nil) {
                                NSDictionary *JSONObject = [NSJSONSerialization JSONObjectWithData:JSONData options:kNilOptions error:&err];
                                if ([JSONObject isKindOfClass:[NSDictionary class]]) {
                                    SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithJSONObject:JSONObject cacheDir:cacheDir];
                                    [videoItem resetImagesWithJSONObject:JSONObject];
                                    [videoItem resetSpritesWithJSONObject:JSONObject];
                                    if (self.enabledMemoryCache) {
                                        [videoItem saveCache:cacheKey];
                                    }
                                    if (completionBlock) {
                                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                            completionBlock(videoItem);
                                        }];
                                    }
                                }
                            }
                            else {
                                if (failureBlock) {
                                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                                    }];
                                }
                            }
                        }
                    }
                    [zipArchive UnzipCloseFile];
                }
            }
            else {
                if (failureBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                    }];
                }
            }
        }
        else {
            if (failureBlock) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    failureBlock([NSError errorWithDomain:@"Data Error" code:-1 userInfo:nil]);
                }];
            }
        }
    }];
}

- (NSData *)zlibInflate:(NSData *)data
{
    if ([data length] == 0) return data;
    
    unsigned full_length = (unsigned)[data length];
    unsigned half_length = (unsigned)[data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = (unsigned)[data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit (&strm) != Z_OK) return nil;
    
    while (!done)
    {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
    
    // Set real length.
    if (done)
    {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    else return nil;
}

- (BOOL)readMemoryCacheWithKey:(NSString *)cacheKey completeBlock:(void ( ^ _Nonnull )(SVGAVideoEntity * _Nullable videoItem))completionBlock {
    if (cacheKey) {
        SVGAVideoEntity *entiry = [[SVGAVideoMemoryCache sharedCache] objectForKey:cacheKey];
        
        if ([entiry isKindOfClass:[SVGAVideoEntity class]] && completionBlock) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                completionBlock(entiry);
            }];
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)readMemoryWithURL:(NSURL *)url completeBlock:(void ( ^ _Nonnull )(SVGAVideoEntity * _Nullable videoItem))completionBlock {
    if ([url isKindOfClass:[NSURL class]]) {
        NSString * cacheKey = [[self class] cacheKey:url];
        return [self readMemoryCacheWithKey:cacheKey completeBlock:completionBlock];
    }
  
    return NO;
}

- (void)saveToDictionary:(NSData *)data cacheKey:(NSString *)cacheKey {
    if (!data) {
        return;
    }
    
    NSString *cacheDir = [[self class]  cacheDirectory:cacheKey];
    [data writeToFile:cacheDir atomically:YES];
}

- (void)clearCache:(nonnull NSString *)cacheKey {
    NSString *cacheDir = [[self class] cacheDirectory:cacheKey];
    [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:NULL];
}

+ (BOOL)isZIPData:(NSData *)data {
    BOOL result = NO;
    if (!strncmp([data bytes], ZIP_MAGIC_NUMBER, strlen(ZIP_MAGIC_NUMBER))) {
        result = YES;
    }
    return result;
}

+ (NSString *)diskCachePath {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [NSString stringWithFormat:@"%@/svgaCache", cacheDir];
}

+ (NSString *)cacheDirectory:(NSString *)cacheKey {
    NSString *cacheDir = [self diskCachePath];
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:NULL error:NULL];
    }
    return [cacheDir stringByAppendingFormat:@"/%@", cacheKey];
}

+ (nonnull NSString *)cacheKey:(NSURL *)URL {
    return [self MD5String:URL.absoluteString];
}

+ (NSString *)MD5String:(NSString *)str {
    const char *cstr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

+ (void)removeDiskCacheAvoidUrls:(NSSet <NSURL *>*_Nullable)urls {
    if (![urls isKindOfClass:[NSArray class]] || urls.count < 1) {
        return;
    }
    
    NSMutableSet *filter = [NSMutableSet set];
    for (NSURL *url in urls) {
        NSString *key = nil;
        if ([url isKindOfClass:[NSString class]] && [(NSString *)url length] > 0) {
            key = [self cacheKey:[NSURL URLWithString:(NSString *)url]];
        } else if ([url isKindOfClass:[NSURL class]]) {
            key = [self cacheKey:url];
        }
        
        if (key) {
            [filter addObject:key];
        }
    }
    
    SVGAParser *p = [SVGAParser new];
    NSString *path = [self diskCachePath];
    NSArray *subs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    
    [unzipQueue addOperationWithBlock:^{
        for (NSString *path in subs) {
            if (![filter containsObject:path]) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            }
        }
    }];
}

@end
