//
//  AudioController.m
//  CoreAudioTemplate
//
//  Created by Maxime Bokobza on 6/1/13.
//  Copyright (c) 2013 Maxime Bokobza. All rights reserved.
//

#import "AudioController.h"
#import <AudioToolbox/AudioToolbox.h>


const float kGraphSampleRate = 44100.0f;  // Hz

void CheckError(OSStatus error, const char *operation);

void CheckError(OSStatus error, const char *operation) {
	if (error == noErr) return;
	
	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);
	
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
	
	exit(1);
}

static OSStatus renderInput(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData);

static OSStatus renderInput(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData) {
    
    ToneInfo toneInfo = *(ToneInfo *)inRefCon;
    ToneEvent *tone = toneInfo.tone;
    GlobalInfo *gInfo = toneInfo.info;
    
    AudioSampleType *outA = (AudioSampleType *)ioData->mBuffers[0].mData;
    
    int cutOffFrame;
    switch (tone->state) {
        case STATE_INACTIVE:
            cutOffFrame = 0;
            break;
        case STATE_ACTIVE:
            cutOffFrame = inNumberFrames;
            break;
    }
    
    if (cutOffFrame > inNumberFrames) {
        cutOffFrame = inNumberFrames;
    }
    
    for (int f = 0; f < cutOffFrame; f++) {
		float m = .0f;  // the mixed value for this frame
        
        int a = (int)tone->phase;  // integer part
        float b = tone->phase - a;   // decimal part
        int c = a + 1;
        if (c >= kGraphSampleRate)  // wrap around
            c -= kGraphSampleRate;
        
        float sineValue = (1.f - b)*gInfo->currentWaveTable[a] + b*gInfo->currentWaveTable[c];
        
        float freq = tone->frequency;
        
        if (freq < kGraphSampleRate) {
            tone->phase += freq;
            if ((tone->phase) >= kGraphSampleRate)
                tone->phase -= kGraphSampleRate;
            
            m = sineValue;
        }
        
		// Write the sample mix to the buffer as a 16-bit word.
		outA[f] = (SInt16)(m * 0x7FFF);
	}
    
    if (cutOffFrame < inNumberFrames) {
        tone->state = STATE_INACTIVE;
        bzero(&outA[cutOffFrame], sizeof(AudioSampleType) * (inNumberFrames - cutOffFrame));
    }
    
	return noErr;
}


@interface AudioController()

@property (nonatomic) AUGraph graph;

@end


@implementation AudioController

@synthesize graph;

- (id)init {
    if (self = [super init]) {
        tone.state = STATE_INACTIVE;
        
        // Compute a sine table for a 1 Hz tone at the current sample rate.
        // We can quickly derive the sine wave for any other tone from this
        // table by stepping through it with the wanted pitch value.
        
        sinTable = (float *)malloc((int)kGraphSampleRate * sizeof(float));
        
        for (int i = 0; i < (int)kGraphSampleRate; i++) {
            sinTable[i] = sinf(i * 2.0f * M_PI / kGraphSampleRate);
        }
        
        gInfo.currentWaveTable = sinTable;
    }
    
    return self;
}

- (void)dealloc {
    free(sinTable);
    DisposeAUGraph(self.graph);
}

#pragma mark -

- (void)initializeAUGraph {
	CheckError(NewAUGraph(&graph), "NewAUGraph");
    
    AUNode inputMixerNode;
    AUNode delayNode;
    AUNode remoteIONode;
    
    // Create AudioComponentDescriptions for the AUs we want in the graph
	AudioComponentDescription compDesc = {0};
    compDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // input mixer
    compDesc.componentType = kAudioUnitType_Mixer;
	compDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    
    CheckError(AUGraphAddNode(self.graph, &compDesc, &inputMixerNode),
               "AUGraphAddNode inputMixer");
    
    // Delay component
    compDesc.componentType = kAudioUnitType_Effect;
    compDesc.componentSubType = kAudioUnitSubType_Delay;
    CheckError(AUGraphAddNode(self.graph, &compDesc, &delayNode),
               "AUGraphAddNode delay");
    
	// remoteIO component
	compDesc.componentType = kAudioUnitType_Output;
	compDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    CheckError(AUGraphAddNode(self.graph, &compDesc, &remoteIONode),
               "AUGraphAddNode remoteIO");
    
    
	// Now we can manage connections using nodes in the graph.
    CheckError(AUGraphConnectNodeInput(self.graph, inputMixerNode, 0, delayNode, 0),
               "AUGraphConnectNodeInput");
	CheckError(AUGraphConnectNodeInput(self.graph, delayNode, 0, remoteIONode, 0),
               "AUGraphConnectNodeInput");
    
    // open the graph AudioUnits are open but not initialized (no resource allocation occurs here)
	CheckError(AUGraphOpen(self.graph),
               "AUGraphOpen");
    
	// Get a link to the mixer AU so we can talk to it later
    CheckError(AUGraphNodeInfo(self.graph, inputMixerNode, NULL, &gInfo.auInputMixer),
               "AUGraphNodeInfo auInputMixer");
    CheckError(AUGraphNodeInfo(self.graph, delayNode, NULL, &gInfo.auDelay),
               "AUGraphNodeInfo auDelay");
	CheckError(AUGraphNodeInfo(self.graph, remoteIONode, NULL, &gInfo.auRemoteIO),
               "AUGraphNodeInfo auRemoteIO");
    
	// In desc
    AudioStreamBasicDescription inDesc = {0};
    AudioStreamBasicDescription auDesc = {0};
    
    inDesc.mSampleRate = kGraphSampleRate; // set sample rate
    inDesc.mFormatID = kAudioFormatLinearPCM;
    inDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    inDesc.mBytesPerPacket = 2;
    inDesc.mFramesPerPacket = 1;
    inDesc.mBytesPerFrame = 2;
    inDesc.mChannelsPerFrame = 1;
    inDesc.mBitsPerChannel = 16;
    
    // Others desc
    UInt32 auSize = sizeof(auDesc);
    CheckError(AudioUnitGetProperty(gInfo.auDelay, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, 0, &auDesc, &auSize),
               "AudioUnitGetProperty auDelay");
    
    // InputMixer
    uint numbuses = 1;
    CheckError(AudioUnitSetProperty(gInfo.auInputMixer, kAudioUnitProperty_ElementCount,
                                    kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses)),
               "AudioUnitSetProperty auInputMixer ElementCount");
    
    CheckError(AudioUnitSetProperty(gInfo.auInputMixer, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output, 0, &auDesc, auSize),
               "AudioUnitSetProperty auInputMixer StreamFormat output");
    
    // Set a callback for the specified node's specified input
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &renderInput;
    
    toneInfo.tone = &tone;
    toneInfo.info = &gInfo;
    
    renderCallbackStruct.inputProcRefCon = (void *)&toneInfo;
    
    CheckError(AUGraphSetNodeInputCallback(self.graph, inputMixerNode, 0, &renderCallbackStruct),
               "AUGraphSetNodeInputCallback inputMixerNodes");
    
    // Set the StreamFormats
    CheckError(AudioUnitSetProperty(gInfo.auInputMixer, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, 0, &inDesc, sizeof(inDesc)),
               "AudioUnitSetProperty auInputMixer StreamFormat input");
    
    CheckError(AudioUnitSetProperty(gInfo.auDelay, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, 0, &auDesc, auSize),
               "AudioUnitSetProperty auDelay StreamFormat input");
    CheckError(AudioUnitSetProperty(gInfo.auDelay, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output, 0, &auDesc, auSize),
               "AudioUnitSetProperty auDelay StreamFormat output");
    
    CheckError(AudioUnitSetProperty(gInfo.auRemoteIO, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, 0, &auDesc, auSize),
               "AudioUnitSetProperty auRemoteIO StreamFormat input");
    
    // Once everything is set up call initialize to validate connections
    CheckError(AUGraphInitialize(self.graph),
               "AUGraphInitialize");
}

- (void)uninitializeAUGraph {
    CheckError(AUGraphUninitialize(self.graph),
               "AUGraphUninitialize");
}

- (void)startAUGraph {
    Boolean isRunning = NO;
    
    // Check to see if the graph is running.
    CheckError(AUGraphIsRunning(self.graph, &isRunning),
               "start AUGraphIsRunning");
    
    if (isRunning)
        return;
    
    CheckError(AUGraphStart(self.graph), "AUGraphStart");
}

- (void)stopAUGraph {
    Boolean isRunning = NO;
    
    // Check to see if the graph is running.
    CheckError(AUGraphIsRunning(self.graph, &isRunning),
               "stop AUGraphIsRunning");
    
    // If the graph is running, stop it.
    if (isRunning)
        CheckError(AUGraphStop(self.graph), "AUGraphStop");
}

#pragma mark - Delay

- (void)setDelayMix:(float)value {
    CheckError(AudioUnitSetParameter(gInfo.auDelay, kDelayParam_WetDryMix,
                                     kAudioUnitScope_Global, 0, value, 0),
               "AudioUnitSetParameter setDelayParam");
}

@end
