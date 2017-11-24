//
//  EVRElasticViewReference.h
//  EVRElasticViewReference
//
//  Created by Jave on 2017/11/8.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, EVRElasticViewReferenceState) {
    EVRElasticViewReferenceStateNone = 0,
    EVRElasticViewReferenceStateBegin,
    EVRElasticViewReferenceStateMoving,
    EVRElasticViewReferenceStateCompleted,
    EVRElasticViewReferenceStateCancel,
};

UIKIT_EXTERN const CGFloat EVRElasticViewReferenceMaxDistance;
UIKIT_EXTERN const CGFloat EVRElasticViewReferenceAnimationDuration;

@class EVRElasticViewReference;
@protocol EVRElasticViewReferenceDelegate <NSObject>

@optional
// Default is distance < EVRElasticViewReferenceMaxDistance.
- (BOOL)elasticViewReference:(EVRElasticViewReference *)reference allowDampingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;

// Default is distance > EVRElasticViewReferenceMaxDistance.
- (BOOL)elasticViewReference:(EVRElasticViewReference *)reference allowCompleteWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;

// Default is distance < EVRElasticViewReferenceAnimationDuration.
- (CGFloat)elasticViewReference:(EVRElasticViewReference *)reference completedAnimationDurationWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;

// The referencedView will resume without animation if return nil.
- (CALayer *)elasticViewReference:(EVRElasticViewReference *)reference completedAnimationLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;

- (void)elasticViewReference:(EVRElasticViewReference *)reference didUpdateState:(EVRElasticViewReferenceState)state;

@end

@interface EVRElasticViewReference : NSObject

@property (nonatomic, weak, readonly) id<EVRElasticViewReferenceDelegate> delegate;

@property (nonatomic, assign, readonly) EVRElasticViewReferenceState state;

@property (nonatomic, strong, readonly) UIView *referencedView;

@property (nonatomic, assign, readonly, getter=isDragging) BOOL dragging;

// Default is YES
@property (nonatomic, assign) BOOL allowTapping;

// Default is NO
@property (nonatomic, assign) BOOL allowDragging;

// Default is EVRElasticViewReferenceAnimationDuration.
@property (nonatomic, assign) CGFloat canceledDuration;

// Default is background color of referenced view.
@property (nonatomic, strong) UIColor *tintColor;

// Attached background view, default is the key window.
@property (nonatomic, strong) UIView *attchedView;

+ (instancetype)referenceWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;
- (instancetype)initWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@end
