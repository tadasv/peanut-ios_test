//
//  main.m
//  record_player
//
//  Created by Tadas Vilkeliskis on 2/4/14.
//  Copyright (c) 2014 Tadas Vilkeliskis. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "AudioController.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        iosAudio = [[AudioController alloc] init];
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
