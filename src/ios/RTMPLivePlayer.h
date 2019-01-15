//
//  RTMPLivePlayer.h
//  
//
//  Created by John Weaver on 08/25/2018.
//
//

#import <Cordova/CDVPlugin.h>

@interface RTMPLivePlayer : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>

@property (copy)   NSString* callbackId;

- (void) start:(CDVInvokedUrlCommand *)command;

@property (copy) NSString* rtmpServerURL;
@property (copy) NSString* alertSuccess;
@property (copy) NSString* alertOK;
@property (copy) NSString* alertQuestionSubmitted;
@property (copy) NSString* labelCharactersRemaining;
@property (nonatomic, assign) NSInteger maxCharacters;
@property (nonatomic, assign) NSInteger audienceQuestionsEnabled;

@end
