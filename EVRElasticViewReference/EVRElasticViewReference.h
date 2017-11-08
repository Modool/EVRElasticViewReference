//
//  EVRElasticViewReference.h
//  EVRElasticViewReference
//
//  Created by Jave on 2017/11/8.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, EVRElasticViewReferenceState) {
    EVRElasticViewReferenceStateBegin = 0,
    EVRElasticViewReferenceStateMoving,
    EVRElasticViewReferenceStateCompleted,
    EVRElasticViewReferenceStateCancel,
};

@class EVRElasticViewReference;

@protocol EVRElasticViewReferenceDelegate <NSObject>

@optional
- (BOOL)elasticViewReference:(EVRElasticViewReference *)reference allowDampingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;
- (BOOL)elasticViewReference:(EVRElasticViewReference *)reference allowCompleteWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;

- (CGFloat)elasticViewReference:(EVRElasticViewReference *)reference completedAnimationDurationWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;
- (CALayer *)elasticViewReference:(EVRElasticViewReference *)reference completedAnimationLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;

- (void)elasticViewReference:(EVRElasticViewReference *)reference didUpdateState:(EVRElasticViewReferenceState)state;

@end

@interface EVRElasticViewReference : NSObject

@property (nonatomic, strong, readonly) UIView *referencedView;

@property (nonatomic, assign, readonly, getter=isDragging) BOOL drag;

// Default is YES
@property (nonatomic, assign, readonly) BOOL allowTapping;

// Default is NO
@property (nonatomic, assign, readonly) BOOL allowDragging;

// Default is background color of referenced view.
@property (nonatomic, strong) UIColor *tintColor;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)referenceWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;
- (instancetype)initWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;

+ (instancetype)referenceWithReferencedView:(UIView *)referencedView allowDragging:(BOOL)allowDragging allowTapping:(BOOL)allowTapping delegate:(id<EVRElasticViewReferenceDelegate>)delegate;
- (instancetype)initWithReferencedView:(UIView *)referencedView allowDragging:(BOOL)allowDragging allowTapping:(BOOL)allowTapping delegate:(id<EVRElasticViewReferenceDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@end
