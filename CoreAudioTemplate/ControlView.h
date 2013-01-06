//
//  ControlView.h
//  CoreAudioTemplate
//
//  Created by Maxime Bokobza on 6/1/13.
//  Copyright (c) 2013 Maxime Bokobza. All rights reserved.
//

#import <UIKit/UIKit.h>


@protocol ControlViewDelegate;


@interface ControlView : UIView

@property (nonatomic, strong) IBOutlet id<ControlViewDelegate> delegate;
@property (nonatomic, strong) NSNumber *frequency;
@property (nonatomic, strong) NSNumber *percentage;

@end


@protocol ControlViewDelegate <NSObject>

- (void)playNote:(NSNumber *)frequency percentage:(NSNumber *)percentage;
- (void)moveToNote:(NSNumber *)frequency percentage:(NSNumber *)percentage;
- (void)releaseNote;
- (void)controlViewDidChangePosition:(ControlView *)controlView;

@end
