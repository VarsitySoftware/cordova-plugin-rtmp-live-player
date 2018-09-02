//
//  RTMPLivePlayer.m
//
//  Created by John Weaver on 08/25/18
//
//

#import "RTMPLivePlayer.h"

@implementation RTMPLivePlayer

@synthesize callbackId;

- (void) launch:(CDVInvokedUrlCommand *)command {
    
    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
    self.callbackId = command.callbackId;

    NSLog(@"ALERT: Launching Live Player!");
}

@end
