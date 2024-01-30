//
//  SVGAVideoSpriteFrameEntity.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGAVideoSpriteFrameEntity.h"
#import "SVGAVectorLayer.h"
#import "SVGABezierPath.h"
#import "Svga.pbobjc.h"

@interface SVGAVideoSpriteFrameEntity ()

@property (nonatomic, assign) float alpha;
@property (nonatomic, assign) float nx;
@property (nonatomic, assign) float ny;
@property (nonatomic, assign) SVGARect layout;
@property (nonatomic, assign) SVGAAffineTransform transform;
@property (nonatomic, strong) NSString *clipPath;
@property (nonatomic, strong) CALayer *maskLayer;
@property (nonatomic, strong) NSArray *shapes;

@end

@implementation SVGAVideoSpriteFrameEntity

- (void)preInit {
    
}

- (instancetype)initWithJSONObject:(NSDictionary *)JSONObject {
    self = [super init];
    if (self) {
        _alpha = 0.0;
        _layout = SVGARectMake(0.f, 0.f,0.f,0.f);
        _transform = SVGAAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        
        if ([JSONObject isKindOfClass:[NSDictionary class]]) {
            NSNumber *alpha = JSONObject[@"alpha"];
            if ([alpha isKindOfClass:[NSNumber class]]) {
                _alpha = [alpha floatValue];
            }
            
            NSDictionary *layout = JSONObject[@"layout"];
            if ([layout isKindOfClass:[NSDictionary class]]) {
                NSNumber *x = layout[@"x"];
                NSNumber *y = layout[@"y"];
                NSNumber *width = layout[@"width"];
                NSNumber *height = layout[@"height"];
                if ([x isKindOfClass:[NSNumber class]] && [y isKindOfClass:[NSNumber class]] &&
                    [width isKindOfClass:[NSNumber class]] && [height isKindOfClass:[NSNumber class]]) {
                    _layout = SVGARectMake(x.floatValue, y.floatValue, width.floatValue, height.floatValue);
                }
            }
            
            NSDictionary *transform = JSONObject[@"transform"];
            if ([transform isKindOfClass:[NSDictionary class]]) {
                NSNumber *a = transform[@"a"];
                NSNumber *b = transform[@"b"];
                NSNumber *c = transform[@"c"];
                NSNumber *d = transform[@"d"];
                NSNumber *tx = transform[@"tx"];
                NSNumber *ty = transform[@"ty"];
                if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]] &&
                    [c isKindOfClass:[NSNumber class]] && [d isKindOfClass:[NSNumber class]] &&
                    [tx isKindOfClass:[NSNumber class]] && [ty isKindOfClass:[NSNumber class]]) {
                    _transform = SVGAAffineTransformMake(a.floatValue, b.floatValue, c.floatValue, d.floatValue, tx.floatValue, ty.floatValue);
                }
            }
            NSString *clipPath = JSONObject[@"clipPath"];
            if ([clipPath isKindOfClass:[NSString class]] && clipPath.length > 0) {
                self.clipPath = clipPath;
            }
            NSArray *shapes = JSONObject[@"shapes"];
            // 增加sapes.count判断，避免大量创建空数组
            if ([shapes isKindOfClass:[NSArray class]] && shapes.count > 0) {
                _shapes = shapes;
            }
        }

        [self configXY];
    }
    return self;
}

- (instancetype)initWithProtoObject:(SVGAProtoFrameEntity *)protoObject {
    self = [super init];
    if (self) {
        _alpha = 0.0;
        _layout = SVGARectMake(0.0, 0.0, 0.0, 0.0);
        _transform = SVGAAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        
        if ([protoObject isKindOfClass:[SVGAProtoFrameEntity class]]) {
            _alpha = protoObject.alpha;
            if (protoObject.hasLayout) {
                _layout = SVGARectMake((CGFloat)protoObject.layout.x,
                                     (CGFloat)protoObject.layout.y,
                                     (CGFloat)protoObject.layout.width,
                                     (CGFloat)protoObject.layout.height);
            }
            
            if (protoObject.hasTransform) {
                _transform = SVGAAffineTransformMake((CGFloat)protoObject.transform.a,
                                                   (CGFloat)protoObject.transform.b,
                                                   (CGFloat)protoObject.transform.c,
                                                   (CGFloat)protoObject.transform.d,
                                                   (CGFloat)protoObject.transform.tx,
                                                   (CGFloat)protoObject.transform.ty);
            }
            
            if ([protoObject.clipPath isKindOfClass:[NSString class]] && protoObject.clipPath.length > 0) {
                self.clipPath = protoObject.clipPath;
            }
            if ([protoObject.shapesArray isKindOfClass:[NSArray class]] && protoObject.shapesArray.count > 0) {
                _shapes = [protoObject.shapesArray copy];
            }
        }
        
        [self configXY];
    }
    return self;
}

- (void)configXY {
    float right = _layout.origin.x + _layout.size.width;
    float bottom = _layout.origin.y + _layout.size.height;
    float ax = _transform.a * _layout.origin.x;
    float bx = _transform.b * _layout.origin.x;
    float cy = _transform.c * _layout.origin.y;
    float dy = _transform.d * _layout.origin.y;
    float ar = _transform.a * right;
    float br = _transform.b * right;
    float cb = _transform.c * bottom;
    float db = _transform.d * bottom;
    
    CGFloat llx = ax + cy + _transform.tx;
    CGFloat lrx = ar + cy + _transform.tx;
    CGFloat lbx = ax + cb + _transform.tx;
    CGFloat rbx = ar + cb + _transform.tx;
    CGFloat lly = bx + dy + _transform.ty;
    CGFloat lry = br + dy + _transform.ty;
    CGFloat lby = bx + db + _transform.ty;
    CGFloat rby = br + db + _transform.ty;
    
    _nx = MIN(MIN(lbx,  rbx), MIN(llx, lrx));
    _ny = MIN(MIN(lby,  rby), MIN(lly, lry));
}


- (CALayer *)maskLayer {
    if (_maskLayer == nil && self.clipPath != nil) {
        SVGABezierPath *bezierPath = [[SVGABezierPath alloc] init];
        [bezierPath setValues:self.clipPath];
        _maskLayer = [bezierPath createLayer];
    }
    return _maskLayer;
}

@end
