//
//  SVGAVideoSpriteFrameEntity.h
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


//
// 避免使用CGxx系统结构体，因CGFloat占用8字节，float占用4字节，
// 因该类会大量创建对象，以此达到节省内存的目的
//

struct SVGAPoint {
    float x;
    float y;
};
typedef struct CG_BOXABLE SVGAPoint SVGAPoint;
CG_INLINE SVGAPoint __SVGAPointMake(float x, float y) {
    SVGAPoint t;
    t.x = x;
    t.y = y;
    return t;
}
#define SVGAPointmMake __SVGAPointMake


struct SVGASize {
    float width;
    float height;
};
typedef struct CG_BOXABLE SVGASize SVGASize;
CG_INLINE SVGASize __SVGASizeMake(float width, float height) {
    SVGASize t;
    t.width = width;
    t.height = height;
    return t;
}
#define SVGASizeMake __SVGASizeMake


struct SVGARect {
    SVGAPoint origin;
    SVGASize size;
};
typedef struct CG_BOXABLE SVGARect SVGARect;
CG_INLINE SVGARect __SVGARectMake(float x, float y, float width, float height) {
    SVGARect t;
    SVGAPoint p = SVGAPointmMake(x, y);
    SVGASize  s = SVGASizeMake(width, height);
    t.origin = p;
    t.size = s;
    return t;
}
#define SVGARectMake __SVGARectMake


struct SVGAAffineTransform {
    float a, b, c, d;
    float tx, ty;
};
typedef struct CG_BOXABLE SVGAAffineTransform SVGAAffineTransform;

CG_INLINE SVGAAffineTransform
__SVGAAffineTransformMake(float a, float b, float c, float d, float tx, float ty) {
    SVGAAffineTransform t;
    t.a = a; t.b = b; t.c = c; t.d = d; t.tx = tx; t.ty = ty;
  return t;
}
#define SVGAAffineTransformMake __SVGAAffineTransformMake


CG_INLINE CGAffineTransform SVGAAffineTransformToCGTransform(SVGAAffineTransform transform) {
    return CGAffineTransformMake(transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty);
}


CG_INLINE CGRect SVGARectToCGRect(SVGARect rect) {
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

#pragma mark - markSVGAVideoSpriteFrameEntity

@class SVGAVectorLayer;
@class SVGAProtoFrameEntity;

@interface SVGAVideoSpriteFrameEntity : NSObject

@property (nonatomic, readonly) float alpha;
@property (nonatomic, readonly) float nx;
@property (nonatomic, readonly) float ny;
@property (nonatomic, readonly) SVGARect layout;
@property (nonatomic, readonly) SVGAAffineTransform transform;
@property (nonatomic, readonly) CALayer *maskLayer;
@property (nonatomic, readonly) NSArray *shapes;

- (instancetype)initWithJSONObject:(NSDictionary *)JSONObject;
- (instancetype)initWithProtoObject:(SVGAProtoFrameEntity *)protoObject;

@end
