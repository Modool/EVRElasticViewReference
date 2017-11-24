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

@property (nonatomic, weak) id<EVRElasticViewReferenceDelegate> delegate;

@property (nonatomic, assign) EVRElasticViewReferenceState state;

@property (nonatomic, strong) UIView *referencedView;

@property (nonatomic, strong) UIView *referencedSnapshotView;

@property (nonatomic, strong) CAShapeLayer *dampingLayer;

@property (nonatomic, strong) CAShapeLayer *originLayer;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic, assign, getter=isDragging) BOOL dragging;

@end

@implementation EVRElasticViewReference

+ (instancetype)referenceWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;{
    return [[self alloc] initWithReferencedView:referencedView delegate:delegate];
}

- (instancetype)init{
    return [self initWithReferencedView:nil delegate:nil];
}

- (instancetype)initWithReferencedView:(UIView *)referencedView delegate:(id<EVRElasticViewReferenceDelegate>)delegate;{
    NSParameterAssert(referencedView);
    if (self = [super init]) {
        self.delegate = delegate;
        self.referencedView = referencedView;
        
        self.allowDragging = YES;
        
        [self initialize];
    }
    return self;
}

- (void)initialize;{
    self.canceledDuration = EVRElasticViewReferenceAnimationDuration;
    self.tintColor = [[self referencedView] backgroundColor];
    self.referencedView.userInteractionEnabled = YES;
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapInReferencedView:)];
    self.tapGestureRecognizer.enabled = [self allowTapping];
    
    [[self referencedView] addGestureRecognizer:[self tapGestureRecognizer]];
    
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPanInReferencedView:)];
    self.panGestureRecognizer.enabled = [self allowDragging];
    
    [[self referencedView] addGestureRecognizer:[self panGestureRecognizer]];
}

- (void)dealloc{
    if ([self tapGestureRecognizer]) {
        [[self referencedView] removeGestureRecognizer:[self tapGestureRecognizer]];
    }
    if ([self panGestureRecognizer]) {
        [[self referencedView] removeGestureRecognizer:[self panGestureRecognizer]];
    }
    
    [self _removeSnapView];
    [self _removeDampingLayer];
}

#pragma mark - accessor

- (UIView *)attchedView{
    if (!_attchedView) {
        _attchedView = [[UIApplication sharedApplication] keyWindow];
    }
    return _attchedView;
}

- (void)setAllowTapping:(BOOL)allowTapping{
    _allowTapping = allowTapping;
    
    self.tapGestureRecognizer.enabled = allowTapping;
}

- (void)setAllowDragging:(BOOL)allowDragging{
    _allowDragging = allowDragging;
    
    self.panGestureRecognizer.enabled = allowDragging;
}

- (CGFloat)fromRadius{
    CGSize size = self.referencedView.bounds.size;
    return MIN(size.width, size.height) / 2.0f;
}

- (CGFloat)toRadius{
    CGSize size = self.referencedSnapshotView.bounds.size;
    return MIN(size.width, size.height) / 2.0f;
}

- (CGPoint)referenceViewCenter{
    return (CGPoint){CGRectGetMidX([[self referencedView] bounds]), CGRectGetMidY([[self referencedView] bounds])};
}

- (CGPoint)pointFromConvertPoint:(CGPoint)point{
    return [[self referencedView] convertPoint:point toView:[self attchedView]];
}

- (CGFloat)distanceFromTranslation:(CGPoint)translation{
    return sqrt(pow(translation.x, 2) + pow(translation.y, 2));
}

- (CAShapeLayer *)newLayer{
    CAShapeLayer *dampingLayer = [CAShapeLayer layer];
    dampingLayer.fillColor = [[self tintColor] CGColor];
    
    return dampingLayer;
}

#pragma mark - private

- (void)_willBeginDraggingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    self.dragging = YES;
    
    [self _resumeDampingLayer];
    [self _resumeSnapView];
    [self _updateState:EVRElasticViewReferenceStateBegin];
    
    [self _updateContentWithLocation:location translation:translation velocity:velocity];
}

- (void)_didEndDraggingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    self.dragging = NO;
    
    if ([self _allowCompleteWithLocation:location translation:translation velocity:velocity]) {
        [self _completeWithLocation:location translation:translation velocity:velocity];
    } else {
        [self _cancel];
    }
}

- (void)_didCancelDraggingWithLocation:(CGPoint)location translation:(CGPoint)translation{
    self.dragging = NO;
    
    [self _cancel];
}

- (void)_updateLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([self _allowDampingWithLocation:location translation:translation velocity:velocity]) {
        if (![self dampingLayer]) [self _resumeDampingLayer];
    } else {
        [self _destroyDampingLayer];
    }
    
    [self _updateContentWithLocation:location translation:translation velocity:velocity];
    [self _updateState:EVRElasticViewReferenceStateMoving];
}

- (void)_completeWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    [self _destroyContentWithLocation:location translation:translation velocity:velocity];
    [self _updateState:EVRElasticViewReferenceStateCompleted];
    [self _updateState:EVRElasticViewReferenceStateNone];
}

- (void)_cancel;{
    [self _resume];
    [self _updateState:EVRElasticViewReferenceStateCancel];
    [self _updateState:EVRElasticViewReferenceStateNone];
}

- (void)_prepareCompletLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity{
    CALayer *layer = [self _completedAnimationLayerWithLocation:location translation:translation velocity:velocity];
    CGFloat duration = [self _completedAnimationDurationWithLocation:location translation:translation velocity:velocity];
    
    if (!layer) return;
    
    [[[self attchedView] layer] addSublayer:layer];
    [layer performSelector:@selector(removeFromSuperlayer) withObject:nil afterDelay:duration];
}

- (void)_resumeSnapView{
    [[self referencedSnapshotView] removeFromSuperview];
    
    self.referencedSnapshotView = [[self referencedView] snapshotViewAfterScreenUpdates:NO];
    self.referencedView.hidden = YES;
    
    [[self attchedView] addSubview:[self referencedSnapshotView]];
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
        [[[self attchedView] layer] insertSublayer:[self originLayer] below:[[self referencedSnapshotView] layer]];
        [[[self attchedView] layer] insertSublayer:[self dampingLayer] below:[[self referencedSnapshotView] layer]];
    } else {
        [[[self attchedView] layer] addSublayer:[self originLayer]];
        [[[self attchedView] layer] addSublayer:[self dampingLayer]];
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
    
    CGPoint from = [self pointFromConvertPoint:[self referenceViewCenter]];
    CGFloat duration = [self canceledDuration];
    
    [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:0.2 initialSpringVelocity:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.referencedSnapshotView.center = from;
    } completion:^(BOOL finished) {
        [self _removeSnapView];
        
        if (completion) completion();
    }];
}

- (void)_updateContentWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    self.referencedSnapshotView.center = location;
    
    [self _updateLayersPathWithLocation:location translation:translation velocity:velocity];
}

- (void)_updateLayersPathWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity {
    CGFloat distance = [self distanceFromTranslation:translation];
    
    CGFloat sine = translation.x / distance;
    CGFloat cosine = translation.y / distance;
    CGFloat angle = asin(sine);
    
    CGFloat fromRadius = [self fromRadius] * MAX(0.3, (1 - distance / EVRElasticViewReferenceMaxDistance));
    CGFloat toRadius = [self toRadius];
    
    CGPoint fromCenter = [self pointFromConvertPoint:[self referenceViewCenter]];
    CGPoint toCenter = location;
    
    // The two points of tangency of referenced view.
    CGPoint fromPoint1 = CGPointMake(fromCenter.x - fromRadius * cosine, fromCenter.y + fromRadius * sine);
    CGPoint fromPoint2 = CGPointMake(fromCenter.x + fromRadius * cosine, fromCenter.y - fromRadius * sine);
    
    // The two points of tangency of referenced snapshot view.
    CGPoint toPoint1 = CGPointMake(toCenter.x - toRadius * cosine, toCenter.y + toRadius * sine);
    CGPoint toPoint2 = CGPointMake(toCenter.x + toRadius * cosine, toCenter.y - toRadius * sine);
    
    // The two points of tangency of curve lines.
    CGPoint controlPoint1 = CGPointMake(fromPoint1.x + (distance / 2) * sine, fromPoint1.y + (distance / 2) * cosine);
    CGPoint controlPoint2 = CGPointMake(fromPoint2.x + (distance / 2) * sine, fromPoint2.y + (distance / 2) * cosine);
    
    UIBezierPath *dampingLayerPath = [UIBezierPath bezierPath];
    // Add two curve lines to align both referenced view and referenced snapshot view.
    [dampingLayerPath moveToPoint:fromPoint1];
    [dampingLayerPath addLineToPoint:fromPoint2];
    [dampingLayerPath addQuadCurveToPoint:toPoint2 controlPoint:controlPoint2];
    [dampingLayerPath addLineToPoint:toPoint1];
    [dampingLayerPath addQuadCurveToPoint:fromPoint1 controlPoint:controlPoint1];
    
    self.dampingLayer.path = [dampingLayerPath CGPath];
    
    UIBezierPath *originLayerPath = [UIBezierPath bezierPath];
    // The origin view replaced by an circle layer, scaled by disitance.
    [originLayerPath addArcWithCenter:fromCenter radius:fromRadius startAngle:angle endAngle:(M_PI * 2 + angle) clockwise:YES];
    
    self.originLayer.path = [originLayerPath CGPath];
}

- (void)_updateState:(EVRElasticViewReferenceState)state{
    self.state = state;
    
    [self _respondDelegateForUpdatingState:state];
}

- (BOOL)_allowDampingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(elasticViewReference:allowDampingWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self allowDampingWithLocation:location translation:translation velocity:velocity];
    }
    return [self distanceFromTranslation:translation] < EVRElasticViewReferenceMaxDistance;
}

- (BOOL)_allowCompleteWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(elasticViewReference:allowCompleteWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self allowCompleteWithLocation:location translation:translation velocity:velocity];
    }
    return [self distanceFromTranslation:translation] > EVRElasticViewReferenceMaxDistance;
}

- (CGFloat)_completedAnimationDurationWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(elasticViewReference:completedAnimationDurationWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self completedAnimationDurationWithLocation:location translation:translation velocity:velocity];
    }
    return EVRElasticViewReferenceAnimationDuration;
}

- (CALayer *)_completedAnimationLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(elasticViewReference:completedAnimationLayerWithLocation:translation:velocity:)]) {
        return [[self delegate] elasticViewReference:self completedAnimationLayerWithLocation:location translation:translation velocity:velocity];
    }
    return nil;
}

- (void)_respondDelegateForUpdatingState:(EVRElasticViewReferenceState)state{
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(elasticViewReference:didUpdateState:)]) {
        [[self delegate] elasticViewReference:self didUpdateState:state];
    }
}

#pragma mark - actions

- (IBAction)didTapInReferencedView:(UITapGestureRecognizer *)tapGestureRecognizer{
    if ([tapGestureRecognizer state] != UIGestureRecognizerStateEnded) return;
    
    CGPoint location = [self pointFromConvertPoint:[self referenceViewCenter]];
    [self _completeWithLocation:location translation:CGPointZero velocity:CGPointZero];
}

- (IBAction)didPanInReferencedView:(UIPanGestureRecognizer *)panGestureRecognizer{
    CGPoint location = [panGestureRecognizer locationInView:[self referencedView]];
    CGPoint translation = [panGestureRecognizer translationInView:[self referencedView]];
    CGPoint velocity = [panGestureRecognizer velocityInView:[self referencedView]];
    
    location = [self pointFromConvertPoint:location];
    
    switch ([panGestureRecognizer state]) {
        case UIGestureRecognizerStateBegan: [self _willBeginDraggingWithLocation:location translation:translation velocity:velocity]; break;
        case UIGestureRecognizerStateChanged: [self _updateLocation:location translation:translation velocity:velocity]; break;
        case UIGestureRecognizerStateEnded: [self _didEndDraggingWithLocation:location translation:translation velocity:velocity]; break;
        default: [self _didCancelDraggingWithLocation:location translation:translation]; break;
    }
}

@end
