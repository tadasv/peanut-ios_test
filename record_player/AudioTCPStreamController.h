//
//  AudioTCPStreamController.h
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/5/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>





@interface AudioTCPStreamController : NSObject <NSStreamDelegate> {
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSString *host;
    int port;

    id playbackDataSource;
    id microphoneDataSource;
}

@property (readonly) NSString *host;
@property (readonly) int port;
@property (readonly) NSInputStream *inputStream;
@property (readonly) NSOutputStream *outputStream;
@property id playbackDataSource;
@property id microphoneDataSource;


- (id)initWithBrokerHost:(NSString*)theHost andPort:(int)thePort;
- (void)newAudioDataAvailableFromMic;
- (void)open;
- (void)close;

@end
