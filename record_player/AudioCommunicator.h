//
//  AudioCommunicator.h
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/4/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPCircularBuffer.h"

@interface AudioCommunicator : NSThread <NSStreamDelegate>

- (id)initWithMicBuffer:(TPCircularBuffer*)theMicBuffer andOutputBuffer:(TPCircularBuffer*)theOutputBuffer;
- (void)notifyAboutNewData;

@end
