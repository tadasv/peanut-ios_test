//
//  AudioController.m
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/5/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import "AudioController.h"

#define kOutputBus 0
#define kInputBus 1

AudioController *iosAudio;

void checkStatus(int status){
	if (status) {
		printf("Status not 0! %d\n", status);
        //		exit(1);
	}
}


/**
 This callback is called when new audio data from the microphone is
 available.
 */
static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
	
	// Because of the way our audio format (setup below) is chosen:
	// we only need 1 buffer, since it is mono
	// Samples are 16 bits = 2 bytes.
	// 1 frame includes only 1 sample
	
	AudioBuffer buffer;
	
	buffer.mNumberChannels = 1;
	buffer.mDataByteSize = inNumberFrames * 2;
	buffer.mData = malloc( inNumberFrames * 2 );
	
	// Put buffer in a AudioBufferList
	AudioBufferList bufferList;
	bufferList.mNumberBuffers = 1;
	bufferList.mBuffers[0] = buffer;
	
    // Then:
    // Obtain recorded samples
	
    OSStatus status;
	
    status = AudioUnitRender([iosAudio audioUnit],
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &bufferList);
	checkStatus(status);
	
    // Now, we have the samples we just read sitting in buffers in bufferList
	// Process the new data
	[iosAudio processAudio:&bufferList];
	
	// release the malloc'ed data in the buffer we created earlier
	free(bufferList.mBuffers[0].mData);
	
    return noErr;
}


/**
 This callback is called when the audioUnit needs new data to play through the
 speakers. If you don't have any, just don't write anything in the buffers
 */
static OSStatus playbackCallback(void *inRefCon,
								 AudioUnitRenderActionFlags *ioActionFlags,
								 const AudioTimeStamp *inTimeStamp,
								 UInt32 inBusNumber,
								 UInt32 inNumberFrames,
								 AudioBufferList *ioData) {
    // Notes: ioData contains buffers (may be more than one!)
    // Fill them up as much as you can. Remember to set the size value in each buffer to match how
    // much data is in the buffer.
	
	for (int i=0; i < ioData->mNumberBuffers; i++) { // in practice we will only ever have 1 buffer, since audio format is mono
		AudioBuffer buffer = ioData->mBuffers[i];
        
        // Copy data from the circular playback buffer into audio unit for playback.
        int32_t bytesAvailable = 0;
        TPCircularBuffer *playbackBuffer = iosAudio.playbackBuffer;
        SInt16 *tail = TPCircularBufferTail(playbackBuffer, &bytesAvailable);
        
        //NSLog(@"  Buffer %d has %d channels and wants %d bytes of data. Available %d", i, (unsigned int)buffer.mNumberChannels, (unsigned int)buffer.mDataByteSize, bytesAvailable);
        
        if (bytesAvailable < buffer.mDataByteSize || tail == NULL) {
            // if we don't have enough data in the circular buffer to provide
            // to the hardware, write out silence.
            memset(buffer.mData, 0, buffer.mDataByteSize);
        } else {
            // Send data to the speakers
            UInt32 size = min(buffer.mDataByteSize, bytesAvailable);
            memcpy(buffer.mData, tail, size);
            buffer.mDataByteSize = size;
            TPCircularBufferConsume(playbackBuffer, size);
        }
	}
	
    return noErr;
}



@implementation AudioController

@synthesize inputUnit;
@synthesize outputUnit;
@synthesize audioUnit;
@synthesize micBuffer;
@synthesize playbackBuffer;
@synthesize tcpStreamController;
@synthesize tcpStreamThread;

/**
 Initialize the audioUnit and allocate our own temporary buffer.
 The temporary buffer will hold the latest data coming in from the microphone,
 and will be copied to the output when this is requested.
 */
- (id)init
{
    self = [super init];
    if (self) {
        OSStatus status;
        
        // Describe audio component
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        //desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        
        // Get audio units
        //status = AudioComponentInstanceNew(comp, &outputUnit);
        //checkStatus(status);
        //status = AudioComponentInstanceNew(comp, &inputUnit);
        //checkStatus(status);
        status = AudioComponentInstanceNew(comp, &audioUnit);
        checkStatus(status);
        
        UInt32 flagEnabled = 1;
        
        // Enable IO for recording
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      kInputBus,
                                      &flagEnabled,
                                      sizeof(flagEnabled));
        checkStatus(status);
        
        // Enable IO for playback
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      kOutputBus,
                                      &flagEnabled,
                                      sizeof(flagEnabled));
        checkStatus(status);
        
        // Describe format
        AudioStreamBasicDescription audioFormat;
        memset(&audioFormat, 0, sizeof(audioFormat));
        
        audioFormat.mSampleRate			= 32000;//44100.00;
        audioFormat.mFormatID			= kAudioFormatLinearPCM;
        audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket	= 1;
        audioFormat.mChannelsPerFrame	= 1;
        audioFormat.mBitsPerChannel		= 16;
        audioFormat.mBytesPerPacket		= 2;
        audioFormat.mBytesPerFrame		= 2;
        
        /*
        audioFormat.mSampleRate         = 44100.0;
        audioFormat.mFormatID           = kAudioFormatMPEG4AAC;
        audioFormat.mFormatFlags        = kMPEG4Object_AAC_Main;
        audioFormat.mChannelsPerFrame   = 1;
        audioFormat.mFramesPerPacket    = 1024;
        */
        // Apply format
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &audioFormat,
                                      sizeof(audioFormat));
        checkStatus(status);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input, 
                                      kOutputBus, 
                                      &audioFormat, 
                                      sizeof(audioFormat));
        checkStatus(status);
        
        // Set input callback
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = recordingCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      kInputBus,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        checkStatus(status);
        
        // Set output callback
        callbackStruct.inputProc = playbackCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_SetRenderCallback, 
                                      kAudioUnitScope_Global, 
                                      kOutputBus,
                                      &callbackStruct, 
                                      sizeof(callbackStruct));
        checkStatus(status);

        // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
        UInt32 flagDisabled = 0;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_ShouldAllocateBuffer,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &flagDisabled,
                                      sizeof(flagDisabled));
        
        /*
        // Allocate our own buffers (1 channel, 16 bits per sample, thus 16 bits per frame, thus 2 bytes per frame).
        // Practice learns the buffers used contain 512 frames, if this changes it will be fixed in processAudio.
        micBuffer.mNumberChannels = 1;
        micBuffer.mDataByteSize = 512 * 2;
        micBuffer.mData = malloc(512 * 2);
        
        playbackBuffer.mNumberChannels = 1;
        playbackBuffer.mDataByteSize = 512 * 2;
        playbackBuffer.mData = malloc(512 * 2);
        */
        // 4 Pages.
        
        micBuffer = malloc(sizeof(TPCircularBuffer));
        playbackBuffer = malloc(sizeof(TPCircularBuffer));
        
        TPCircularBufferInit(micBuffer, 4096 * 100);
        TPCircularBufferInit(playbackBuffer, 4096 * 100);
        
        // Initialise
        status = AudioUnitInitialize(audioUnit);
        checkStatus(status);
    }
    
    return self;
}

- (TPCircularBuffer*)microphoneDataBuffer
{
    return micBuffer;
}


/**
 Start the audioUnit. This means data will be provided from
 the microphone, and requested for feeding to the speakers, by
 use of the provided callbacks.
 */
- (void) start {
	OSStatus status = AudioOutputUnitStart(audioUnit);
	checkStatus(status);
}

/**
 Stop the audioUnit
 */
- (void) stop {
	OSStatus status = AudioOutputUnitStop(audioUnit);
	checkStatus(status);
}


/**
 Change this funtion to decide what is done with incoming
 audio data from the microphone.
 Right now we copy it to our own temporary buffer.
 */
- (void) processAudio: (AudioBufferList*) bufferList{
	AudioBuffer sourceBuffer = bufferList->mBuffers[0];
	
    /*
	// fix tempBuffer size if it's the wrong size
	if (micBuffer.mDataByteSize != sourceBuffer.mDataByteSize) {
		free(micBuffer.mData);
		micBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
		micBuffer.mData = malloc(sourceBuffer.mDataByteSize);
	}
	
	// copy incoming audio data to temporary buffer
	memcpy(micBuffer.mData, sourceBuffer.mData, sourceBuffer.mDataByteSize);
    memcpy(playbackBuffer.mData, micBuffer.mData, sourceBuffer.mDataByteSize);
     */
    
    // calculate entropy of the audio data
    unsigned int byteCounts[256] = {0,};
    unsigned char *audioData = sourceBuffer.mData;
    for (int i = 0; i < sourceBuffer.mDataByteSize; i++) {
        byteCounts[audioData[i]] += 1;
    }
    
    double entropy = 0.0;
    for (int i = 0; i < 256; i++) {
        if (byteCounts[i] == 0) {
            continue;
        }

        double frequency = (double)byteCounts[i] / sourceBuffer.mDataByteSize;
        entropy -= frequency * (log(frequency) / log(2));
    }

    //printf("entropy: %f\n", entropy);
    
    if (entropy > 3.7) {
    TPCircularBufferProduceBytes(micBuffer, sourceBuffer.mData, sourceBuffer.mDataByteSize);
    //printf("process audio: mic buffer: %p\n", micBuffer);
    //TPCircularBufferProduceBytes(playbackBuffer, sourceBuffer.mData, sourceBuffer.mDataByteSize);
    
    if (tcpStreamThread && tcpStreamController) {
        [tcpStreamController performSelector:@selector(newAudioDataAvailableFromMic) onThread:tcpStreamThread withObject:tcpStreamController waitUntilDone:NO];
    }
    }
}


/**
 Clean up.
 */
- (void) dealloc {
	//[super dealloc];
	AudioUnitUninitialize(audioUnit);
	TPCircularBufferCleanup(micBuffer);
    TPCircularBufferCleanup(playbackBuffer);
    
    free(micBuffer);
    free(playbackBuffer);
}

@end
