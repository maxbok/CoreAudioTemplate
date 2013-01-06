//
//  ControlView.m
//  CoreAudioTemplate
//
//  Created by Maxime Bokobza on 6/1/13.
//  Copyright (c) 2013 Maxime Bokobza. All rights reserved.
//

#import "ControlView.h"


static CGFloat const kMaxFreq = 2500.f;
static CGFloat const kMinFreq = 50.f;


@interface ControlView ()

@property (nonatomic, strong) NSValue *position;

@end


@implementation ControlView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.position = nil;
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    self.position = [NSValue valueWithCGPoint:[[touches anyObject] locationInView:self]];
    [self.delegate playNote:self.frequency percentage:self.percentage];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    self.position = [NSValue valueWithCGPoint:[[touches anyObject] locationInView:self]];
    [self.delegate moveToNote:self.frequency percentage:self.percentage];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    self.position = nil;
    [self.delegate releaseNote];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    self.position = nil;
    [self.delegate releaseNote];
}

#pragma mark -

- (void)setPosition:(NSValue *)position {
    _position = position;
    
    if (position) {
        CGPoint point = [position CGPointValue];
        self.frequency = @(((self.bounds.size.height - point.y) * (kMaxFreq - kMinFreq)) / self.bounds.size.height + kMinFreq);
        self.percentage = @(point.x * 100 / self.bounds.size.width);
    } else {
        self.frequency = nil;
        self.percentage = nil;
    }
    
    [self.delegate controlViewDidChangePosition:self];
}

@end
