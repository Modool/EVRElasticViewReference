//
//  TestTableViewCell.m
//  Demo
//
//  Created by Jave on 2017/11/8.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import <EVRElasticViewReference/EVRElasticViewReference.h>

#import "TestTableViewCell.h"

@interface TestTableViewCell ()<EVRElasticViewReferenceDelegate>

@property (nonatomic, strong) UILabel *contentLabel;

@property (nonatomic, strong) EVRElasticViewReference *reference;

@end

@implementation TestTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.contentLabel = [UILabel new];
        
        self.contentLabel.textColor = [UIColor whiteColor];
        self.contentLabel.backgroundColor = [UIColor redColor];
        self.contentLabel.textAlignment = NSTextAlignmentCenter;
        
        self.contentLabel.layer.cornerRadius = 15.f;
        self.contentLabel.layer.masksToBounds = YES;
        
        [[self contentView] addSubview:[self contentLabel]];
        
        self.reference = [EVRElasticViewReference referenceWithReferencedView:[self contentLabel] delegate:self];
        self.reference.allowTapping = YES;
        self.reference.allowDragging = YES;
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.contentLabel.frame = CGRectMake(CGRectGetWidth([[self contentView] bounds]) - 50, (CGRectGetHeight([[self contentView] bounds]) - 30) / 2., 30, 30);
}

- (BOOL)elasticViewReference:(EVRElasticViewReference *)reference allowDampingWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    return sqrt((pow(translation.x, 2) + pow(translation.y, 2))) < 100;
}

- (BOOL)elasticViewReference:(EVRElasticViewReference *)reference allowCompleteWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    return sqrt((pow(translation.x, 2) + pow(translation.y, 2))) > 200;
}

- (CGFloat)elasticViewReference:(EVRElasticViewReference *)reference completedAnimationDurationWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    return .2f;
}

- (CALayer *)elasticViewReference:(EVRElasticViewReference *)reference completedAnimationLayerWithLocation:(CGPoint)location translation:(CGPoint)translation velocity:(CGPoint)velocity;{
    UIImage *image = [UIImage imageNamed:@"bomb"];
    CGSize size = self.contentLabel.bounds.size;
    
    CAEmitterCell *emitterCell = [CAEmitterCell new];
    emitterCell.scale = .5f;
    emitterCell.lifetime = 5.f;
    emitterCell.velocity = 10;
    emitterCell.birthRate = 10;
    emitterCell.alphaSpeed = -0.4;
    emitterCell.emissionRange = M_PI * 2.0;
    emitterCell.color = [[reference tintColor] CGColor];
    emitterCell.contents = (__bridge id)[image CGImage];

    CAEmitterLayer *emitterLayer = [CAEmitterLayer layer];
    emitterLayer.frame = (CGRect){0, 0, size};
    emitterLayer.renderMode = kCAEmitterLayerAdditive;
    
    emitterLayer.emitterPosition = location;
    emitterLayer.emitterSize = CGSizeMake(size.width / 2., size.height / 2.);
    
    emitterLayer.emitterCells = @[emitterCell];
    
    return emitterLayer;
}

- (void)elasticViewReference:(EVRElasticViewReference *)reference didUpdateState:(EVRElasticViewReferenceState)state;{
    switch (state) {
        case EVRElasticViewReferenceStateBegin: NSLog(@"state update: begin"); break;
        case EVRElasticViewReferenceStateMoving: NSLog(@"state update: moving"); break;
        case EVRElasticViewReferenceStateCompleted: NSLog(@"state update: complete"); break;
        case EVRElasticViewReferenceStateCancel: NSLog(@"state update: cancel"); break;
        case EVRElasticViewReferenceStateNone: NSLog(@"state update: none"); break;
        default: break;
    }
    
    if (state == EVRElasticViewReferenceStateCompleted) {
        self.contentLabel.hidden = YES;
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag;{
    
}

@end
