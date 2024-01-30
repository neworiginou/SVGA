//
//  SVGAImageView.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/10/17.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGAImageView.h"
#import "SVGAParser.h"


@implementation SVGAImageView

+ (SVGAParser *)sharedParser {
    static SVGAParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [SVGAParser new];
    });
    return parser;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _autoPlay = YES;
    }
    return self;
}

- (void)setImageName:(NSString *)imageName {
    _imageName = imageName;
    if ([imageName hasPrefix:@"http://"] || [imageName hasPrefix:@"https://"]) {
        [[SVGAImageView sharedParser] parseWithURL:[NSURL URLWithString:imageName] completionBlock:^(SVGAVideoEntity * _Nullable videoItem) {
            [self setVideoItem:videoItem];
            if (self.autoPlay) {
                [self startAnimation];
            }
        } failureBlock:nil];
    } else {
        [[SVGAImageView sharedParser] parseWithNamed:imageName inBundle:nil completionBlock:^(SVGAVideoEntity * _Nonnull videoItem) {
            [self setVideoItem:videoItem];
            if (self.autoPlay) {
                [self startAnimation];
            }
        } failureBlock:nil];
    }
}

@end
