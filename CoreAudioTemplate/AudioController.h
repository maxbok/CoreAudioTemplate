//
//  AudioController.h
//  CoreAudioTemplate
//
//  Created by Maxime Bokobza on 6/1/13.
//  Copyright (c) 2013 Maxime Bokobza. All rights reserved.
//

#import <AudioUnit/AudioUnit.h>

extern const float kGraphSampleRate;


typedef enum {
	STATE_INACTIVE = 0,
    STATE_ACTIVE,
} ToneEventState;

typedef struct {
	ToneEventState state;    ///< the state of the tone
	float frequency;         ///< the frequency of the note for each input bus
	float phase;             ///< current step for the oscillator for each input bus
} ToneEvent;

typedef struct {
    float *currentWaveTable;
    
    AudioUnit auInputMixer;
    AudioUnit auDelay;
    AudioUnit auRemoteIO;
} GlobalInfo;

typedef struct {
    ToneEvent *tone;
    GlobalInfo *info;
} ToneInfo;

@interface AudioController : NSObject {
    float *sinTable;
    
@public
    GlobalInfo gInfo;
    ToneEvent tone;
    ToneInfo toneInfo;
}

@property (nonatomic) NSUInteger toneIndex;

- (void)initializeAUGraph;
- (void)startAUGraph;
- (void)stopAUGraph;
- (void)uninitializeAUGraph;

- (void)setDelayMix:(float)value;

@end
