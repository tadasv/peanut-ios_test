//
//  ViewController.m
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/4/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import "ViewController.h"
#import "AudioCommunicator.h"
#import "AudioController.h"
#import "AudioStreamThread.h"

@interface ViewController () {
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    
    TPCircularBuffer _micBuffer;
    TPCircularBuffer _outputBuffer;
    AudioCommunicator *_audioCommunicator;
    
    AudioStreamThread *audioStreamThread;
}

@end

@implementation ViewController

@synthesize microphoneSwitch;
@synthesize playbackSwitch;
@synthesize socketSwitch;


-(IBAction)toggleMicrophone:(id)sender
{
    if (self.microphoneSwitch.on == FALSE) {
        NSLog(@"stopping to fetch audio");
        [self.microphone stopFetchingAudio];
        TPCircularBufferClear(&_micBuffer);
    } else {
        NSLog(@"starting to fetch audio");
        [self.microphone startFetchingAudio];
    }
}

-(IBAction)togglePlayback:(id)sender
{
    EZOutput *output = [EZOutput sharedOutput];
    output.outputDataSource = self;
    
    if (self.playbackSwitch.on == FALSE) {
        NSLog(@"stopping playback");
        [self.speakers stopPlayback];
    } else {
        NSLog(@"starting playback");
        [self.speakers startPlayback];
    }
}


-(IBAction)toggleSocket:(id)sender
{
    if (self.socketSwitch.on == NO) {
        [iosAudio stop];
        //[audioStreamThread cancel];
        [audioStreamThread stop];
        audioStreamThread = nil;

    } else {
        [iosAudio start];
        usleep(1000);
        audioStreamThread = [[AudioStreamThread alloc] init];
        [audioStreamThread start];
    }
    /*
    if (self.socketSwitch.on == FALSE) {
        NSLog(@"closing tcp connection");
        [_audioCommunicator cancel];
        _audioCommunicator = nil;
    } else {
        NSLog(@"opening tcp connection");
        if (!_audioCommunicator || _audioCommunicator.isCancelled) {
            _audioCommunicator = [[AudioCommunicator alloc] initWithMicBuffer:&_micBuffer andOutputBuffer:&_outputBuffer];
        }

        [_audioCommunicator start];
    }*/
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
/*
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mSampleRate = 8000;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mBytesPerPacket = 2;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 2;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 16;
    asbd.mFormatFlags = kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    
    self.microphone = [EZMicrophone microphoneWithDelegate:self withAudioStreamBasicDescription:asbd];
    self.speakers = [[EZOutput alloc] initWithDataSource:self withAudioStreamBasicDescription:asbd];

    _audioCommunicator = nil;
    TPCircularBufferInit(&_micBuffer, 40960);
    TPCircularBufferInit(&_outputBuffer, 40960);
 */
    //audioController = [[AudioController alloc] init];
    audioStreamThread = nil;
    
}


-(TPCircularBuffer *)outputShouldUseCircularBuffer:(EZOutput *)output
{
    return &_outputBuffer;
}


- (void)microphone:(EZMicrophone *)microphone hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
{
    [EZAudio printASBD:audioStreamBasicDescription];
}

- (void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
}

- (void)microphone:(EZMicrophone *)microphone hasBufferList:(AudioBufferList *)bufferList withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
    /*
    for (int i = 0; i < bufferSize; i++) {
        if (i % 64 == 0) {
            printf("\n");
        }
        unsigned char c = *((char*)(bufferList->mBuffers[0].mData) + i);
        printf("%02x ", c);
    }
    */
    [EZAudio appendDataToCircularBuffer:&_outputBuffer fromAudioBufferList:bufferList];
    return;
    int numBytes;
    TPCircularBufferTail(&_micBuffer, &numBytes);
    [_audioCommunicator performSelector:@selector(notifyAboutNewData) onThread:_audioCommunicator withObject:_audioCommunicator waitUntilDone:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
