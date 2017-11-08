//
//  EVRElasticViewReference.m
//  EVRElasticViewReference
//
//  Created by Jave on 2017/11/8.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import "EVRElasticViewReference.h"

const CGFloat EVRElasticViewReferenceMaxDistance = 100.f;

const CGFloat EVRElasticViewReferenceAnimationDuration = .5f;

@interface EVRElasticViewReference ()

@property (nonatomic, strong) UIView *referencedView;

@property (nonatomic, strong) UIView *referencedSnapshotView;

@property (nonatomic, strong) CAShapeLayer *dampingLayer;

@property (nonatomic, strong) CAShapeLayer *originLayer;

@property (nonatomic, assign, getter=isDragging) BOOL drag;

@property (nonatomic, assign) BOOL allowTapping;

@property (nonatomic, assign) BOOL allowDragging;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic, weak) id<EVRElasticViewReferenceDelegate> delegate;

@property (nonatomic, strong, readonly) UIWindow *window;

@end

@implementation EVRElasticViewReference

+ (instancetype)referenceWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;{
    return [[self alloc] initWithReferencedView:referencedView delegate:delegate];
}

- (instancetype)initWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;{
    NSParameterAssert(referencedView);
    
    return [self initWithReferencedView:referencedView allowDragging:YES allowTapping:NO delegate:delegate];
}

+ (instancetype)referenceWithReferencedView:(UIView *)referencedView allowDragging:(BOOL)allowDragging allowTapping:(BOOL)allowTapping delegate:(id<EVRElasticViewReferenceDelegate>)delegate;{
    return [[self alloc] initWithReferencedView:referencedView allowDragging:allowTapping allowTapping:allowTapping delegate:delegate];
}

- (instancetype)initWithReferencedView:(UIView *)referencedView allowDragging:(BOOL)allowDragging allowTapping:(BOOL)allowTapping delegate:(id<EVRElasticViewReferenceDelegate>)delegate {
    NSParameterAssert(referencedView);
    if (self = [super init]) {
        self.delegate = delegate;
        self.allowDragging = allowDragging;
        self.allowTapping = allowTapping;
        self.referencedView = referencedView;
        
        [self initialize];
    }
    return self;
}

- (void)initialize;{
    self.tintColor = [[self referencedView] backgroundColor];
    self.referencedView.userInteractionEnabled = YES;
    
    if ([self allowTapping]) {
        self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapInReferencedView:)];
        
        [[self referencedView] addGestureRecognizer:[self tapGestureRecognizer]];
    }
    if ([self allowDragging]) {
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPanInReferencedView:)];
        
        [[self referencedView] addGestureRecognizer:[self panGestureRecognizer]];
    }
}

- (void)dealloc{
    [[self referencedView] removeGestureRecognizer:[self tapGestureRecognizer]];
    [[self referencedView] removeGestureRecognizer:[self panGestureRecognizer]];
    
    [self _removeSnapView];
    [self _removeDampingLayer];
}

#pragma mark - accessor

- (UIWindow *)window{
    return [[[UIApplication sharedApplication] delegate] window];
}

- (CGFloat)fromRadiusWithTranlation:(CGPoint)translation{
    CGSize size = self.referencedView.bounds.size;
    return MIN(size.width, size.height) / 2.0f;
}

- (CGFloat)toRadius{
    CGSize size = self.referencedSnapshotView.bounds.size;
    return MIN(size.width, size.height) / 2.0f;
}

- (CGPoint)pointFromConvertPoint:(CGPoint)point{
    return [[self referencedView] convertPoint:point toView:[self window]];
}

- (CAShapeLayer *)newLayer{
    CAShapeLayer *dampingLayer = [CAShapeLayer layer];
    dampingLayer.fillColor = [[self tintColor] CGColor];
    
    return dampingLayer;
}

#pragma mark - private

- (void)_willBeginDraggingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    self.drag = YES;
    
    [self _resumeDampingLayer];
    [self _resumeSnapView];
    
    [self _updateContentWithLocation:location translation:translation velocity:velocity];
}

- (void)_didEndDraggingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    self.drag = NO;
    
    if ([self _allowCompleteWithLocation:location translation:translation velocity:velocity]) {
        [self _completeWithLocation:location translation:translation velocity:velocity];
    } else {
        [self _cancel];
    }
}

- (void)_didCancelDraggingWithLocation:(CGPoint)location translation:(CGPoint)translation{
    self.drag = NO;
    
    [self _cancel];
}

- (void)_updateLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    self.drag = YES;
    
    if ([self _allowDampingWithLocation:location translation:translation velocity:velocity]) {
        if (![self dampingLayer]) {
            [self _resumeDampingLayer];
        }
    } else {
        [self _destroyDampingLayer];
    }
    
    [self _updateContentWithLocation:location translation:translation velocity:velocity];
    [self _respondDelegateForUpdatingState:EVRElasticViewReferenceStateMoving];
}

- (void)_completeWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    [self _destroyContentWithLocation:location translation:translation velocity:velocity];
    [self _respondDelegateForUpdatingState:EVRElasticViewReferenceStateCompleted];
}

- (void)_cancel;{
    [self _resume];
    [self _respondDelegateForUpdatingState:EVRElasticViewReferenceStateCancel];
}

- (void)_prepareCompletLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    CALayer *layer = [self completedAnimationLayerWithLocation:location translation:translation velocity:velocity];
    CGFloat duration = [self completedAnimationDurationWithLocation:location translation:translation velocity:velocity];
    
    if (!layer) return;
    
    [[[self window] layer] addSublayer:layer];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [layer removeFromSuperlayer];
    });    
}

- (void)_resumeSnapView{
    [[self referencedSnapshotView] removeFromSuperview];
    
    self.referencedSnapshotView = [[self referencedView] snapshotViewAfterScreenUpdates:NO];
    self.referencedView.hidden = YES;
    
    [[self window] addSubview:[self referencedSnapshotView]];
}

- (void)_removeSnapView{
    self.referencedView.hidden = NO;
    
    [[self referencedSnapshotView] removeFromSuperview];
    self.referencedSnapshotView = nil;
}

- (void)_destroyDampingLayer{
    self.originLayer.path = nil;
    self.dampingLayer.path = nil;
    
    [self _removeDampingLayer];
}

- (void)_removeDampingLayer{
    [[self originLayer] removeFromSuperlayer];
    [[self dampingLayer] removeFromSuperlayer];
    
    self.originLayer = nil;
    self.dampingLayer = nil;
}

- (void)_resumeDampingLayer{
    [self _removeDampingLayer];
    
    self.originLayer = [self newLayer];
    self.dampingLayer = [self newLayer];
    
    if ([self referencedSnapshotView]) {
        [[[self window] layer] insertSublayer:[self originLayer] below:[[self referencedSnapshotView] layer]];
        [[[self window] layer] insertSublayer:[self dampingLayer] below:[[self referencedSnapshotView] layer]];
    } else {
        [[[self window] layer] addSublayer:[self originLayer]];
        [[[self window] layer] addSublayer:[self dampingLayer]];
    }
}

- (void)_destroyContentWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    [self _destroyContentWithLocation:location translation:translation velocity:velocity completion:nil];
}

- (void)_destroyContentWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity completion:(void (^)(void))completion{
    [self _destroyDampingLayer];
    [self _removeSnapView];
    [self _prepareCompletLayerWithLocation:location translation:translation velocity:velocity];
}

- (void)_resume{
    [self _resumeWithCompletion:nil];
}

- (void)_resumeWithCompletion:(void (^)(void))completion{
    [self _removeDampingLayer];
    
    CGPoint from = [self pointFromConvertPoint:CGPointMake(CGRectGetWidth([[self referencedView] frame]) / 2., CGRectGetHeight([[self referencedView] frame]) / 2.)];

    [UIView animateWithDuration:EVRElasticViewReferenceAnimationDuration delay:0 usingSpringWithDamping:0.2 initialSpringVelocity:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.referencedSnapshotView.center = from;
    } completion:^(BOOL finished) {
        [self _removeSnapView];
    }];
}

- (void)_updateContentWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    self.referencedSnapshotView.center = location;
    
    [self _updateLayersPathWithLocation:location translation:translation velocity:velocity];
}

- (void)_updateLayersPathWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity {
    CGFloat distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2));
    
    CGFloat sine = translation.x / distance;
    CGFloat cosine = translation.y / distance;
    CGFloat angle = asin(sine);
    
    CGFloat fromRadius = [self fromRadiusWithTranlation:translation] * MAX(0.3, (1 - distance / EVRElasticViewReferenceMaxDistance));
    CGFloat toRadius = [self toRadius];
    
    CGPoint fromCenter = [self pointFromConvertPoint:CGPointMake(CGRectGetWidth([[self referencedView] frame]) / 2., CGRectGetHeight([[self referencedView] frame]) / 2.)];
    CGPoint toCenter = location;
    
    CGPoint fromPoint1 = CGPointMake(fromCenter.x - fromRadius * cosine, fromCenter.y + fromRadius * sine);
    CGPoint fromPoint2 = CGPointMake(fromCenter.x + fromRadius * cosine, fromCenter.y - fromRadius * sine);
    
    CGPoint toPoint1 = CGPointMake(toCenter.x - toRadius * cosine, toCenter.y + toRadius * sine);
    CGPoint toPoint2 = CGPointMake(toCenter.x + toRadius * cosine, toCenter.y - toRadius * sine);
    
    CGPoint controlPoint1 = CGPointMake(fromPoint1.x + (distance / 2) * sine, fromPoint1.y + (distance / 2) * cosine);
    CGPoint controlPoint2 = CGPointMake(fromPoint2.x + (distance / 2) * sine, fromPoint2.y + (distance / 2) * cosine);
    
    UIBezierPath *dampingLayerPath = [UIBezierPath bezierPath];
    [dampingLayerPath moveToPoint:fromPoint1];
    [dampingLayerPath addLineToPoint:fromPoint2];
    [dampingLayerPath addQuadCurveToPoint:toPoint2 controlPoint:controlPoint2];
    [dampingLayerPath addLineToPoint:toPoint1];
    [dampingLayerPath addQuadCurveToPoint:fromPoint1 controlPoint:controlPoint1];
    
    self.dampingLayer.path = [dampingLayerPath CGPath];
    
    UIBezierPath *originLayerPath = [UIBezierPath bezierPath];
    [originLayerPath addArcWithCenter:fromCenter radius:fromRadius startAngle:angle endAngle:(M_PI * 2 + angle) clockwise:YES];
    
    self.originLayer.path = [originLayerPath CGPath];
}

- (BOOL)_allowDampingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([[self delegate] respondsToSelector:@selector(elasticViewReference:allowDampingWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self allowDampingWithLocation:location translation:translation velocity:velocity];
    }
    return (sqrt(pow(translation.x, 2) + pow(translation.y, 2)) < EVRElasticViewReferenceMaxDistance);
}

- (BOOL)_allowCompleteWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([[self delegate] respondsToSelector:@selector(elasticViewReference:allowCompleteWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self allowCompleteWithLocation:location translation:translation velocity:velocity];
    }
    return (sqrt(pow(translation.x, 2) + pow(translation.y, 2)) > EVRElasticViewReferenceMaxDistance);
}

- (CGFloat)completedAnimationDurationWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([[self delegate] respondsToSelector:@selector(elasticViewReference:completedAnimationDurationWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self completedAnimationDurationWithLocation:location translation:translation velocity:velocity];
    }
    return EVRElasticViewReferenceAnimationDuration;
}

- (CALayer *)completedAnimationLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([[self delegate] respondsToSelector:@selector(elasticViewReference:completedAnimationLayerWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self completedAnimationLayerWithLocation:location translation:translation velocity:velocity];
    }
    return nil;
}

- (void)_respondDelegateForUpdatingState:(EVRElasticViewReferenceState)state{
    if ([[self delegate] respondsToSelector:@selector(elasticViewReference:didUpdateState:)]) {
        [[self delegate] elasticViewReference:self didUpdateState:state];
    }
}

#pragma mark - actions

- (IBAction)didTapInReferencedView:(UITapGestureRecognizer *)sender{
    if ([sender state] == UIGestureRecognizerStateEnded) {
        CGPoint location = [self pointFromConvertPoint:CGPointMake(CGRectGetWidth([[self referencedView] frame]) / 2., CGRectGetHeight([[self referencedView] frame]) / 2.)];
        [self _completeWithLocation:location translation:CGPointZero velocity:CGPointZero];
    }
}

- (IBAction)didPanInReferencedView:(UIPanGestureRecognizer *)sender{
    CGPoint location = [sender locationInView:[self referencedView]];
    CGPoint translation = [sender translationInView:[self referencedView]];
    CGPoint velocity = [sender velocityInView:[self referencedView]];
    
    location = [self pointFromConvertPoint:location];
    
    switch ([sender state]) {
        case UIGestureRecognizerStateBegan: [self _willBeginDraggingWithLocation:location translation:translation velocity:velocity]; break;
        case UIGestureRecognizerStateChanged: [self _updateLocation:location translation:translation velocity:velocity]; break;
        case UIGestureRecognizerStateEnded: [self _didEndDraggingWithLocation:location translation:translation velocity:velocity]; break;
        default: [self _didCancelDraggingWithLocation:location translation:translation]; break;
    }
}

@end
