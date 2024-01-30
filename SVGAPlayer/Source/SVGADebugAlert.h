//
//  SVGADebugAlert.h
//  SVGAPlayer
//
//  Created by song.meng on 2020/11/3.
//  Copyright © 2020 UED Center. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SVGAVideoEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SVGADebugAlert : UIView

+ (void)showAlertWithEntity:(SVGAVideoEntity *)entity cost:(NSUInteger)cost;

@end

NS_ASSUME_NONNULL_END
