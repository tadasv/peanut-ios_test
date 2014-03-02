//
//  ViewController.h
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/4/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EZAudio/EZAudio.h"

@interface ViewController : UIViewController <EZMicrophoneDelegate, NSStreamDelegate, EZOutputDataSource>

// Declare the EZMicrophone as a strong property
@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, strong) EZOutput *speakers;

@property IBOutlet UISwitch *microphoneSwitch;
@property IBOutlet UISwitch *playbackSwitch;
@property IBOutlet UISwitch *socketSwitch;

-(IBAction)toggleMicrophone:(id)sender;
-(IBAction)toggleSocket:(id)sender;
-(IBAction)togglePlayback:(id)sender;

@end
