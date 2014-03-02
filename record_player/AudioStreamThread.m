//
//  AudioStreamThread.m
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/6/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import "AudioStreamThread.h"
#import "AudioTCPStreamController.h"
#import "AudioController.h"

@implementation AudioStreamThread

- (void)stop {
    [self performSelector:@selector(cancel) onThread:self withObject:self waitUntilDone:NO];
}

- (void)main
{
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    
    AudioTCPStreamController *tcpStreamController = [[AudioTCPStreamController alloc] initWithBrokerHost:@"localhost" andPort:3333];
    tcpStreamController.microphoneDataSource = iosAudio;
    [tcpStreamController open];
    
    iosAudio.tcpStreamController = tcpStreamController;
    iosAudio.tcpStreamThread = self;
    
    while (![self isCancelled] && [currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
        // Keep running the thread until we stop it.
    }
    
    NSLog(@"Exiting AudioStreamThread");
    iosAudio.tcpStreamThread = nil;
    iosAudio.tcpStreamController = nil;
    [tcpStreamController close];
    tcpStreamController = nil;
}

@end
