//
//  ViewController.m
//  CoreAudioTemplate
//
//  Created by Maxime Bokobza on 6/1/13.
//  Copyright (c) 2013 Maxime Bokobza. All rights reserved.
//

#import "ViewController.h"
#import "ControlView.h"
#import "AudioController.h"


@interface ViewController () <ControlViewDelegate>

@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) AudioController *audioController;

- (void)initialize;

@end


@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self initialize];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self initialize];
    }
    
    return self;
}

- (void)initialize {
    self.audioController = [[AudioController alloc] init];
    
    // AUGraph
    [self.audioController initializeAUGraph];
    [self.audioController startAUGraph];
}

- (void)dealloc {
    // AUGraph
    [self.audioController stopAUGraph];
    [self.audioController uninitializeAUGraph];
}

#pragma mark - ControlViewDelegate

- (void)controlViewDidChangePosition:(ControlView *)controlView {
    NSNumber *frequency = [controlView frequency];
    NSNumber *percentage = [controlView percentage];
    if (frequency && percentage) {
        [self.label setHidden:NO];
        self.label.text = [NSString stringWithFormat:@"%.1fHz, %.0f%%", [frequency floatValue], [percentage floatValue]];
    } else {
        [self.label setHidden:YES];
    }
}

- (void)playNote:(NSNumber *)frequency percentage:(NSNumber *)percentage {
    self.audioController->tone.state = STATE_ACTIVE;
    self.audioController->tone.frequency = [frequency floatValue];
    self.audioController->tone.phase = .0f;
    
    [self.audioController setDelayMix:[percentage floatValue] / 100];
}

- (void)moveToNote:(NSNumber *)frequency percentage:(NSNumber *)percentage {
    self.audioController->tone.frequency = [frequency floatValue];

    [self.audioController setDelayMix:[percentage floatValue] / 100];
}

- (void)releaseNote {
    self.audioController->tone.state = STATE_INACTIVE;
}

@end
