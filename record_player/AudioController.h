//
//  AudioController.h
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/5/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer.h"

@protocol PlaybackDataSource

// returns audio buffer that's used as an output to hardware.
- (TPCircularBuffer*)playbackDataBuffer;

@end

@protocol MicrophoneDataSource

// Returns audio buffer that contains data from the microphone
- (TPCircularBuffer*)microphoneDataBuffer;

@end

#ifndef max
#define max( a, b ) ( ((a) > (b)) ? (a) : (b) )
#endif

#ifndef min
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif

@interface AudioController : NSObject <MicrophoneDataSource> {
    AudioComponentInstance outputUnit;  // speakers
    AudioComponentInstance inputUnit;   // mic
    AudioComponentInstance audioUnit;
    
	TPCircularBuffer *playbackBuffer; // this will hold the data we want to play thru speakers.
    TPCircularBuffer *micBuffer; // this will hold the latest data from the mic
    
    id tcpStreamController; // we will notify tcp stream controller when we have data from the mic.
    NSThread *tcpStreamThread;
}

@property (readonly) AudioComponentInstance outputUnit;
@property (readonly) AudioComponentInstance inputUnit;
@property (readonly) AudioComponentInstance audioUnit;
@property TPCircularBuffer *playbackBuffer;
@property TPCircularBuffer *micBuffer;
@property id tcpStreamController;
@property NSThread *tcpStreamThread;

- (void)start;
- (void)stop;
- (void)processAudio:(AudioBufferList*)bufferList;

@end

// setup a global iosAudio variable, accessible everywhere
extern AudioController* iosAudio;