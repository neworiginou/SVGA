//
//  SVGADebugAlert.m
//  SVGAPlayer
//
//  Created by song.meng on 2020/11/3.
//  Copyright © 2020 UED Center. All rights reserved.
//

#import "SVGADebugAlert.h"
#import "SVGAPlayer.h"
#import "SVGAVideoMemoryCache.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kText   @"因svga动效可能包含多张图片，不同的图片使用方式有着不同的内存表现。较大的内存占用情况主要为：\n1、资源尺寸较大（本资源size:{%.1f, %.1f}）\n2、多张资源图以序列帧的形式组合，类似gif \n\n *注：具体资源信息可在https://svga.io/网站查看；该弹窗仅在debug模式下生效，当前警告限制为：%.2fMbit，您可通过设置SVGAVideoMemoryCache.videoWarningLimit为0来禁用该弹窗"


@interface SVGADebugAlert()

@property (nonatomic, strong) SVGAVideoEntity *entity;

@property (nonatomic, strong) SVGAPlayer    *player;

@end

@implementation SVGADebugAlert

+ (void)showAlertWithEntity:(SVGAVideoEntity *)entity cost:(NSUInteger)cost {
    if (![entity isKindOfClass:[SVGAVideoEntity class]] || cost <= 0) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        SVGADebugAlert *alert = [[SVGADebugAlert alloc] initWithVideoEntity:entity cost:cost];
        [alert show];
    });
}

- (instancetype)initWithVideoEntity:(SVGAVideoEntity *)entity cost:(NSUInteger)cost {
    if (self = [super initWithFrame:CGRectMake((kWidth - 300)/2, (kHeight - 400)/2, 300, 400)]) {
        _entity = entity;
        [self createSubview:cost];
    }
    return self;
}

- (void)createSubview:(NSUInteger)cost {
    self.backgroundColor = [UIColor colorWithWhite:230.f/255 alpha:1];
    self.layer.cornerRadius = 10;
    
    UILabel *warning = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 280, 40)];
    warning.textAlignment = NSTextAlignmentCenter;
    warning.text = @"SVGA内存使用警告";
    warning.font = [UIFont systemFontOfSize:15 weight:10];
    warning.textColor = [UIColor colorWithWhite:50.f/255 alpha:1];
    [self addSubview:warning];
    
    UIButton * backButton = [[UIButton alloc] initWithFrame:CGRectMake(260, 0, 40, 40)];
    [backButton setTitle:@"关闭" forState:UIControlStateNormal];
    backButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [backButton setTitleColor:[UIColor colorWithWhite:50.f/255 alpha:1] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:backButton];
    
    CGSize size = _entity.videoSize;
    if (size.width >= 280 || size.height >= 200) {
        if (size.width / size.height > 280/200) {
            size = CGSizeMake(280, size.height * 280 / size.width);
        } else {
            size = CGSizeMake(size.width * 200 / size.height, 200);
        }
    }
    
    _player = [[SVGAPlayer alloc] initWithFrame:CGRectMake((300 - size.width)/2, 40, size.width, size.height)];
    _player.contentMode = UIViewContentModeCenter;
    _player.videoItem = _entity;
    [self addSubview:_player];
    
    UILabel * costTip = [[UILabel alloc] initWithFrame:CGRectMake(10, 240, 280, 30)];
    costTip.font = [UIFont boldSystemFontOfSize:15];
    costTip.textColor = [UIColor redColor];
    costTip.textAlignment = NSTextAlignmentCenter;
    costTip.text = [NSString stringWithFormat:@"《 Memory Cost: %.2f Mbit 》", cost / 1024.f / 1024.f];
    [self addSubview:costTip];
    
    UILabel * tips = [[UILabel alloc] initWithFrame:CGRectMake(10, 270, 280, 130)];
    tips.font = [UIFont systemFontOfSize:10];
    tips.textColor = [UIColor colorWithWhite:50.f/255 alpha:1];
    tips.numberOfLines = 10;
    tips.text = [NSString stringWithFormat:kText, _entity.videoSize.width, _entity.videoSize.height, [SVGAVideoMemoryCache sharedCache].videoWarningLimit / 1024.f / 1024.f];
    [self addSubview:tips];
}

- (void)dismiss {
    [_player stopAnimation];
    [self removeFromSuperview];
}

- (void)show {
#if defined(DEBUG) || defined(INHOUSE)
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    [_player startAnimation];
#endif
}

@end
