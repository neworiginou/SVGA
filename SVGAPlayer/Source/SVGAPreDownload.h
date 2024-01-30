//
//  SVGAPreDownload.h
//  SVGAPlayer
//
//  Created by song.meng on 2023/1/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SVGAPreDownload : NSObject

+ (instancetype)shareInstance;


// 预加载svga资源
- (void)predownloadSVGAWithUrls:(NSArray *)urls;

/// 清理磁盘缓存
- (void)clearDiskCache;

@end

NS_ASSUME_NONNULL_END
