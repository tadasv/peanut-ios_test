//
//  AudioTCPStreamController.m
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/5/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import "AudioTCPStreamController.h"
#import "AudioController.h"
#import "msgpack.h"

@implementation AudioTCPStreamController {
    msgpack_unpacker *unpacker;
}

@synthesize inputStream;
@synthesize outputStream;
@synthesize host;
@synthesize port;
@synthesize playbackDataSource;
@synthesize microphoneDataSource;

- (id)initWithBrokerHost:(NSString*)theHost andPort:(int)thePort
{
    self = [super init];
    if (self) {
        host = [[NSString alloc] initWithString:theHost];
        port = thePort;
        inputStream = nil;
        outputStream = nil;
        unpacker = msgpack_unpacker_new(40960);
    }
    return self;
}


- (msgpack_sbuffer*)serializeAudioData:(unsigned char *)data ofLength:(int32_t)length
{
    msgpack_sbuffer *buffer = msgpack_sbuffer_new();
    msgpack_packer* pk = msgpack_packer_new(buffer, msgpack_sbuffer_write);
    
    msgpack_pack_array(pk, 2);
    // message type
    msgpack_pack_int32(pk, 0);
    msgpack_pack_raw(pk, length);
    msgpack_pack_raw_body(pk, data, length);
    msgpack_packer_free(pk);
    return buffer;
}


- (void)newAudioDataAvailableFromMic
{
    if (!outputStream.hasSpaceAvailable) {
        NSLog(@"outputStream has no space available");
        return;
        // we should consume data anyway but not send it over the network.
    }
    
    TPCircularBuffer *buffer = iosAudio.micBuffer;
    int32_t bytesAvailable;
    uint8_t *tail = TPCircularBufferTail(buffer, &bytesAvailable);
        
    if (tail == NULL) {
        NSLog(@"can't send audio data over the network since tail is NULL");
    } else {
        msgpack_sbuffer *serialied_data = [self serializeAudioData:tail ofLength:bytesAvailable];
        TPCircularBufferConsume(buffer, bytesAvailable);
        [outputStream write:(unsigned char*)serialied_data->data maxLength:serialied_data->size];
        msgpack_sbuffer_free(serialied_data);
    }
}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    switch (streamEvent) {
        case NSStreamEventEndEncountered:
            NSLog(@"socket end: %s", theStream == inputStream ? "input" : "output");
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"socket error: %s", theStream == inputStream ? "input" : "output");
            break;
        case NSStreamEventHasBytesAvailable:
            //NSLog(@"bytes available: %s", theStream == inputStream ? "input" : "output");
            {
                unsigned char readBuffer[4096];
                long bytesRead = [inputStream read:readBuffer maxLength:sizeof(readBuffer)];
                if (bytesRead == -1) {
                    NSLog(@"IO error on inputStream");
                } else if (bytesRead == 0) {
                    NSLog(@"end of inputStream");
                } else {
                    msgpack_unpacker_reserve_buffer(unpacker, bytesRead);
                    char *msgpack_buffer = msgpack_unpacker_buffer(unpacker);
                    memcpy(msgpack_buffer, readBuffer, bytesRead);
                    msgpack_unpacker_buffer_consumed(unpacker, bytesRead);
                    
                    msgpack_unpacked obj;
                    msgpack_unpacked_init(&obj);
                    while (msgpack_unpacker_next(unpacker, &obj)) {
                        // TODO check that the data is valid etc.
                        //NSLog(@"received object");
                        TPCircularBuffer *playbackBuffer = iosAudio.playbackBuffer;
                        TPCircularBufferProduceBytes(playbackBuffer,
                                                     obj.data.via.array.ptr[1].via.raw.ptr,
                                                     obj.data.via.array.ptr[1].via.raw.size);
                        
                    }
                    msgpack_unpacked_destroy(&obj);
                    
                }
            }
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"open complete: %s", theStream == inputStream ? "input" : "output");
            break;
        case NSStreamEventHasSpaceAvailable:
            //NSLog(@"has space available: %s", theStream == inputStream ? "input" : "output");
            if (theStream != outputStream) {
                NSLog(@"space available not on the outputStream");
                return;
            }
            
            /*
            
            if ([self.microphoneDataSource respondsToSelector:@selector(microphoneDataBuffer)]) {
                //TPCircularBuffer *buffer = [self.microphoneDataSource microphoneDataBuffer];
                TPCircularBuffer *buffer = iosAudio.micBuffer;
                int32_t bytesAvailable;
                uint8_t *tail = TPCircularBufferTail(buffer, &bytesAvailable);

                if (tail == NULL) {
                    NSLog(@"can't send audio data over the network since tail is NULL");
                } else {
                    [outputStream write:tail maxLength:bytesAvailable];
                    TPCircularBufferConsume(buffer, bytesAvailable);
                }
            } else {
                NSLog(@"microphoneDataSource does not respond to @selector(microphoneDataBuffer)");
            }
            */
            break;
        default:
            NSLog(@"received stream event: %s, %i", theStream == inputStream ? "input" : "output", streamEvent);
            break;
    }
}


- (void)open
{
    assert(inputStream == nil);
    assert(outputStream == nil);
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL,
                                       (__bridge CFStringRef)host,
                                       port,
                                       &readStream,
                                       &writeStream);
    inputStream = (NSInputStream *)CFBridgingRelease(readStream);
    outputStream = (NSOutputStream *)CFBridgingRelease(writeStream);
    
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
}


- (void)close
{
    if (inputStream) {
        [inputStream close];
        inputStream = nil;
    }
    
    if (outputStream) {
        [outputStream close];
        outputStream = nil;
    }
    
    if (unpacker) {
        msgpack_unpacker_free(unpacker);
        unpacker = nil;
    }
}


- (void)dealloc
{
    if (inputStream) {
        [inputStream close];
    }
    
    if (outputStream) {
        [outputStream close];
    }
    
    if (unpacker) {
        msgpack_unpacker_free(unpacker);
    }
}

@end
