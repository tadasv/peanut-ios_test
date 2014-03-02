//
//  AudioCommunicator.m
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/4/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import "AudioCommunicator.h"

@implementation AudioCommunicator {
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    TPCircularBuffer *micBuffer;
    TPCircularBuffer *outputBuffer;
    NSPort *port;
    NSThread *thread;
}


- (id)initWithMicBuffer:(TPCircularBuffer*)theMicBuffer andOutputBuffer:(TPCircularBuffer*)theOutputBuffer
{
    self = [super init];
    if (self) {
        micBuffer = theMicBuffer;
        outputBuffer = theOutputBuffer;
    }
    
    thread = self;
    return self;
}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    switch (streamEvent) {
        case NSStreamEventEndEncountered:
            //NSLog(@"socket end: %s", theStream == inputStream ? "input" : "output");
            break;
        case NSStreamEventErrorOccurred:
            //NSLog(@"socket error: %s", theStream == inputStream ? "input" : "output");
            break;
        case NSStreamEventHasBytesAvailable:
            //NSLog(@"bytes available: %s", theStream == inputStream ? "input" : "output");
            {
                unsigned char data[1024];
                int bytesRead = [inputStream read:data maxLength:sizeof(data)];
                TPCircularBufferProduceBytes(outputBuffer, data, bytesRead);
            }
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"open complete: %s", theStream == inputStream ? "input" : "output");
            break;
        case NSStreamEventHasSpaceAvailable:
            //NSLog(@"has space available: %s", theStream == inputStream ? "input" : "output");
            [self _sendMicData];
            break;
        default:
            NSLog(@"received stream event: %s, %i", theStream == inputStream ? "input" : "output", streamEvent);
            break;
    }
}


- (void)_sendMicData
{
    if (micBuffer) {
        int32_t bytesAvailable;
        unsigned char *data = TPCircularBufferTail(micBuffer, &bytesAvailable);
        if (data) {
            //bytesAvailable = bytesAvailable > 1024 ? 1024 : bytesAvailable;
            [outputStream write:data maxLength:bytesAvailable];
            TPCircularBufferConsume(micBuffer, bytesAvailable);
        }
    }
}


- (void)notifyAboutNewData
{
    [self _sendMicData];
}


- (void)establishTCPConnection
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"localhost", 3333, &readStream, &writeStream);
    inputStream = (NSInputStream *)CFBridgingRelease(readStream);
    outputStream = (NSOutputStream *)CFBridgingRelease(writeStream);
    
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
}


- (void)main
{
    [self establishTCPConnection];
    
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    
    while (![self isCancelled] && [currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
        // Keep running the thread until we stop it.
    }

    // Clean up
    if (inputStream) {
        [inputStream close];
        inputStream = nil;
    }
    
    if (outputStream) {
        [outputStream close];
        outputStream = nil;
    }
    
    if (port) {
        port = nil;
    }
}

@end
