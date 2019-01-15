//
//  RTMPLivePlayer.m
//
//  Created by John Weaver on 09/01/18
//  BASED ON https://github.com/nchutchind/cordova-plugin-streaming-media/blob/master/src/ios/StreamingMedia.m
//  http://brettschumann.com/blog/2010/01/15/iphone-multiline-textbox-for-sms-style-chat
// 

#import "RTMPLivePlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>
#import "UIControl+YYAdd.h"
#import "UIView+YYAdd.h"

#define MAX_CHARACTERS 100
#define LABEL_CHARACTERS_REMAINING @"characters remaining"

NSTimer *doneButtonClickedTimer;

@interface RTMPLivePlayer()
{
	//IBOutlet UITextView *chatBox;
	//IBOutlet UIButton   *chatButton;
}

- (void)parseOptions:(NSDictionary *) options type:(NSString *) type;
- (void)play:(CDVInvokedUrlCommand *) command type:(NSString *) type;
- (void)setBackgroundColor:(NSString *)color;
- (void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType;
- (UIImage*)getImage: (NSString *)imageName;
- (void)startPlayer:(NSString*)uri;
- (void)moviePlayBackDidFinish:(NSNotification*)notification;
//- (void)moviePlayerDismissed:(NSNotification*)notification;
- (void)cleanup;

@property (nonatomic, strong) UIButton *questionButton;

//@property (nonatomic, strong) UITextView *chatBox;
@property (nonatomic, retain) UIButton *submitButton;
@property (nonatomic, strong) UITextView *questionBox;
@property (nonatomic, strong) UIView *questionBoxView;
@property (nonatomic, strong) UIView *questionTextContainerView;
@property (nonatomic, strong) UIView *questionTextDismissView;
@property (nonatomic, strong) UILabel *charactersRemainingLabel;

- (IBAction)chatButtonClick:(id)sender;

@end

NSString * const TYPE_VIDEO = @"VIDEO";
NSString * const TYPE_AUDIO = @"AUDIO";
NSString * const DEFAULT_IMAGE_SCALE = @"center";

int keyboardHeight = 0;
int questionBoxLines = 1;

@implementation RTMPLivePlayer
{
	AVPlayerViewController *moviePlayer;
}

@synthesize callbackId;

- (void) start:(CDVInvokedUrlCommand *)command {
    
    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
    self.callbackId = command.callbackId;

	NSString* strRTMPServerURL = [options objectForKey:@"rtmpServerURL"];

	NSString* strAlertSuccess = [options objectForKey:@"alertSuccess"];	
	NSString* strAlertOK = [options objectForKey:@"alertOK"];	
	NSString* strAlertQuestionSubmitted = [options objectForKey:@"alertQuestionSubmitted"];	
	NSString* strCharactersRemaining = [options objectForKey:@"labelCharactersRemaining"];	
	NSInteger intMaxCharacters = [[options objectForKey:@"maxCharacters"] integerValue];
	NSInteger intAudienceQuestionsEnabled = [[options objectForKey:@"audienceQuestionsEnabled"] integerValue];
	
	self.maxCharacters = MAX_CHARACTERS;
	self.labelCharactersRemaining = LABEL_CHARACTERS_REMAINING;
	self.audienceQuestionsEnabled = 0;

	if (strRTMPServerURL)
	{
		self.rtmpServerURL = strRTMPServerURL;
	}
	if (strAlertSuccess)
	{
		self.alertSuccess = strAlertSuccess;
	}
	if (strAlertOK)
	{
		self.alertOK = strAlertOK;
	}
	if (strAlertQuestionSubmitted)
	{
		self.alertQuestionSubmitted = strAlertQuestionSubmitted;
	}
	if (strCharactersRemaining)
	{
		self.labelCharactersRemaining = strCharactersRemaining;
	}
	if (intMaxCharacters > 0)
	{
		self.maxCharacters = intMaxCharacters;
	}
	if (intAudienceQuestionsEnabled > 0)
	{
		self.audienceQuestionsEnabled = intAudienceQuestionsEnabled;
	}

	//set notification for when keyboard shows/hides
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];

	//set notification for when a key is pressed.
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(keyPressed:) name: UITextViewTextDidChangeNotification  object: nil];

	//turn off scrolling and set the font details.
	//chatBox.scrollEnabled = NO;
	//chatBox.font = [UIFont fontWithName:@"Helvetica" size:14]; 
	
	NSString * strCharactersRemainingLabel = [NSString stringWithFormat:@"%@: %ld", self.labelCharactersRemaining, self.maxCharacters];
    self.charactersRemainingLabel.text = strCharactersRemainingLabel;

    NSLog(@"ALERT: Launching Live Player!");
	NSLog(@"server url: %@", strRTMPServerURL);
	//NSLog(@"XXXXX %d!", self.audienceQuestionsEnabled);

	[self playVideo];

	////////////////////////
	// https://stackoverflow.com/questions/28671578/how-do-i-intercept-tapping-of-the-done-button-in-avplayerviewcontroller/31193599
	////////////////////////

	[self doneButtonClickedTimerStart];
}

-(void)doneButtonClickedTimerStart
{
	doneButtonClickedTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(30.0 / 60.0)  target:self selector:@selector(checkDoneClicked) userInfo:nil repeats:TRUE];
}

-(void)checkDoneClicked
{
	if (moviePlayer.player.rate == 0 && (moviePlayer.isBeingDismissed || moviePlayer.nextResponder == nil)) 
	{
		// Handle user Done button click and invalidate timer
		[self doneButtonClickedTimerStop];

		NSLog(@"Done button clicked!!");    

		NSString *textValue = [NSString stringWithFormat:@"%s", "success"];
	
		NSDictionary *jsonObj = [ [NSDictionary alloc] initWithObjectsAndKeys: textValue, @"done", nil];

		CDVPluginResult* pluginResult = nil;	
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: jsonObj];
		[pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()	
		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];

	}
}

-(void)doneButtonClickedTimerStop
{
	[doneButtonClickedTimer invalidate];
    doneButtonClickedTimer = nil;
}

-(void) keyboardWillShow:(NSNotification *)notification
{
   //NSLog(@"ALERT: SHOWING KEYBOARD!");
}

-(void) keyboardWillHide:(NSNotification *)notification
{
   //NSLog(@"ALERT: HIDING KEYBOARD!");
}

-(void) keyboardWillChangeFrame:(NSNotification *)notification
{
   //NSLog(@"height: %f", [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height);
   //NSLog(@"XXX height: %f", self.viewController.view.bounds.size.height - 270);
   
   keyboardHeight = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;

   CGRect newFrame = self.questionTextContainerView.frame;

	//newFrame.size.width = self.viewController.view.bounds.size.width * (self.slideCount + 1);
	newFrame.origin.y = self.viewController.view.bounds.size.height - keyboardHeight - 60;
	[self.questionTextContainerView setFrame:newFrame];
   
}

-(void) keyPressed:(NSNotification *)notification
{
	[self resizeQuestionBox];
	
}

-(void) resizeQuestionBox
{
	//NSLog(@"ALERT: KEY PRESSED!");

	BOOL bolUpdateSizes = NO;
	
	int intQuestionBoxSize = 30;
	int intSubmitButtonTop = 0;
	int intTextContainerViewSize = 80;
	int intOriginY = 60;
	int intQuestionBoxViewHeight = 60;
	int intCharactersRemainingPosY = 34;

	int intCharacters = self.questionBox.text.length;
	int intCharactersRemaining = self.maxCharacters - intCharacters;

	if (intCharactersRemaining <= 0)
	{
		intCharactersRemaining = 0;		
		self.questionBox.text = [self.questionBox.text substringToIndex:self.maxCharacters];
	}

	switch (questionBoxLines)
	{
		case 0:
			questionBoxLines = 1;
			bolUpdateSizes = YES;
			break;
		case 1:
			if (intCharacters > 40)
			{	
				intQuestionBoxSize = 50;
				intSubmitButtonTop = 15;
				intTextContainerViewSize = 100;
				intQuestionBoxViewHeight = 80;
				intOriginY = 80;
				intCharactersRemainingPosY = 50;
				questionBoxLines = 2;
				bolUpdateSizes = YES;
			}
			break;
		case 2:
			if (intCharacters < 40)
			{	
				intQuestionBoxSize = 30;
				intSubmitButtonTop = 0;
				intTextContainerViewSize = 80;
				intQuestionBoxViewHeight = 60;
				intOriginY = 60;
				intCharactersRemainingPosY = 34;
				questionBoxLines = 1;
				bolUpdateSizes = YES;
			}
			if (intCharacters > 80)
			{	
				intQuestionBoxSize = 70;
				intSubmitButtonTop = 25;
				intTextContainerViewSize = 140;
				intQuestionBoxViewHeight = 100;
				intCharactersRemainingPosY = 75;
				intOriginY = 100;
				questionBoxLines = 3;
				bolUpdateSizes = YES;
			}
			break;
		case 3:
			if (intCharacters < 80)
			{	
				intQuestionBoxSize = 50;
				intSubmitButtonTop = 15;
				intTextContainerViewSize = 100;
				intQuestionBoxViewHeight = 80;
				intCharactersRemainingPosY = 50;
				intOriginY = 80;
				questionBoxLines = 2;
				bolUpdateSizes = YES;
			}
			break;
	}

	if (bolUpdateSizes == YES)
	{
		//NSLog(@"intTextContainerViewSize: %d", intTextContainerViewSize);

		self.questionBox.size = CGSizeMake(self.viewController.view.bounds.size.width - 60, intQuestionBoxSize);

		CGRect newFrame = self.questionTextContainerView.frame;
		newFrame.origin.y = self.viewController.view.bounds.size.height - keyboardHeight - intOriginY;
		//newFrame.size.height = intTextContainerViewSize;
		[self.questionTextContainerView setFrame:newFrame];

		CGRect newFrame2 = self.charactersRemainingLabel.frame;
		newFrame2.origin.y = intCharactersRemainingPosY;
		[self.charactersRemainingLabel setFrame:newFrame2];

		self.questionBoxView.size = CGSizeMake(self.viewController.view.bounds.size.width, intQuestionBoxViewHeight);

		self.submitButton.top = intSubmitButtonTop;
	}

	//NSString * strCharactersRemaining = [NSString stringWithFormat:@"%s %d", "characters remaining: ", intCharactersRemaining];
	NSString * strCharactersRemaining = [NSString stringWithFormat:@"%@: %d", self.labelCharactersRemaining, intCharactersRemaining];
	self.charactersRemainingLabel.text = strCharactersRemaining;	
}

- (IBAction)chatButtonClick:(id)sender{
	
}

-(void)playVideo {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    
	[self startPlayer:self.rtmpServerURL];
}

-(void)startPlayer:(NSString*)uri {
    
	//UIView * overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, self.viewController.view.bounds.size.height - 100, self.viewController.view.bounds.size.width, 30)];
	//UIView * overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 100, self.viewController.view.bounds.size.width, 100)];
	
	NSURL *url             =  [NSURL URLWithString:uri];
    AVPlayer *movie        =  [AVPlayer playerWithURL:url];
	moviePlayer            =  [[AVPlayerViewController alloc] init];

	if (self.audienceQuestionsEnabled == 1)
	{
		UIView * questionButtonContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.viewController.view.bounds.size.height - 170, self.viewController.view.bounds.size.width, 80)];

		self.questionTextContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.viewController.view.bounds.size.height - 270, self.viewController.view.bounds.size.width, 80)];
		self.questionTextDismissView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewController.view.bounds.size.width, 400)];

		self.questionTextContainerView.hidden = YES;
		self.questionTextDismissView.hidden = YES;

		[questionButtonContainerView addSubview:self.questionButton];		
		[self.questionTextContainerView addSubview:self.questionBoxView];		

		[moviePlayer.view addSubview:questionButtonContainerView];
		[moviePlayer.view addSubview:self.questionTextContainerView];
		[moviePlayer.view addSubview:self.questionTextDismissView];
	}    

	//UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
	//[moviePlayer.view addGestureRecognizer:tap];

	// Method 1: Add a gesture recognizer to the view
	//https://stackoverflow.com/questions/36878609/avplayer-uitapgesturerecognizer-not-working
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doneClicked:)];
    self.questionTextDismissView.gestureRecognizers = @[tap];

	//[self.viewController.view addSubview:overlayView];
	//[moviePlayer.contentOverlayView addSubview:overlayView];

    [moviePlayer setPlayer:movie];
    [moviePlayer setShowsPlaybackControls:YES];
    if(@available(iOS 11.0, *)) { [moviePlayer setEntersFullScreenWhenPlaybackBegins:YES]; }
    
    //present modally so we get a close button
    [self.viewController presentViewController:moviePlayer animated:YES completion:^(void){
        //let's start this bitch.
        [moviePlayer.player play];
    }];

	// Listen for closing of movie player
	// Set self to listen for the message "SecondViewControllerDismissed" and run a method when this message is detected
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayerDismissed:) name:@"AVPlayerViewControllerDismissNotification" object:nil];    

    // Listen for playback finishing
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:AVPlayerItemDidPlayToEndTimeNotification object:moviePlayer.player.currentItem];
    
    // Listen for errors
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:moviePlayer.player.currentItem];   
    
}

//- (void) moviePlayerDismissed:(NSNotification*)notification
//{
    
//}


- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    NSLog(@"Playback did finish");    
}

- (UIButton *)questionButton {
    if (!_questionButton) {
        _questionButton = [UIButton new];
        //_questionButton.size = CGSizeMake(44, 44);
        //_questionButton.origin = CGPointMake(0, 20);
		 _questionButton.size = CGSizeMake(80, 80);
		 //_questionButton.origin = CGPointMake(self.viewController.view.bounds.size.width / 2.0 - 40, self.viewController.view.bounds.size.height - 300);
		 _questionButton.origin = CGPointMake(self.viewController.view.bounds.size.width / 2.0 - 40, 0);
        [_questionButton setImage:[UIImage imageNamed:@"icon_chat"] forState:UIControlStateNormal];
        [_questionButton setImage:[UIImage imageNamed:@"icon_chat"] forState:UIControlStateSelected];
        _questionButton.exclusiveTouch = YES;
        //__weak typeof(self) _self = self;
		_questionButton.tag = 10; 
		//_questionButton.textAlignment = NSTextAlignmentCenter;	
	
	    [_questionButton addTarget:self action:@selector(addQuestion:) forControlEvents:UIControlEventTouchUpInside];

        //_questionButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
            //_self.session.questionFace = !_self.session.questionFace;
            //_self.questionButton.selected = !_self.session.questionFace; 
			//NSLog(@"Question button selected");    
        //}];
    }
    return _questionButton;
}

- (UIView *)questionBoxView {
	if (!_questionBoxView) 
	{
		//_questionBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewController.view.bounds.size.width, 40)];
		_questionBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewController.view.bounds.size.width, 60)];
		_questionBoxView.backgroundColor = [UIColor lightGrayColor];

		[_questionBoxView addSubview:self.questionBox];    
		[_questionBoxView addSubview:self.submitButton];    
		[_questionBoxView addSubview:self.charactersRemainingLabel];    		
	}       
    
    return _questionBoxView;
}

- (UITextView *)questionBox {
    if (!_questionBox) 
	{
        _questionBox = [UITextView new];
        _questionBox.size = CGSizeMake(self.viewController.view.bounds.size.width - 60, 30);
		//_questionBox.origin = CGPointMake(self.viewController.view.bounds.size.width / 2, 0);
		_questionBox.origin = CGPointMake(10, 5);
        _questionBox.exclusiveTouch = YES;
		_questionBox.hidden = YES;
		_questionBox.font = [UIFont fontWithName:@"Helvetica" size:16]; 
		//_questionBox.layer.borderColor = [UIColor(red: 200/255, green: 200/255, blue: 205/255, alpha:1).CGColor];
        _questionBox.layer.borderWidth = 0.5;
        _questionBox.layer.cornerRadius = 15;
		_questionBox.textContainerInset = UIEdgeInsetsMake(5, 10, 0, 10);

		//UIToolbar* keyboardDoneButtonView = [[UIToolbar alloc] init];
		//keyboardDoneButtonView.BarStyle = UIBarStyle.Black;
		//keyboardDoneButtonView.Translucent = true;
		//keyboardDoneButtonView.UserInteractionEnabled = true;
		//[keyboardDoneButtonView sizeToFit];

		//UIBarButtonItem* doneButton = [[UIBarButtonItemalloc] initWithTitle:@"Done"  style:UIBarButtonItemStyleBorderedtarget:selfaction:@selector(doneClicked:)];
		//UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Submit" style:UIBarButtonItemStylePlain target:self action:@selector(doneClicked:)];
		//[keyboardDoneButtonView setItems:[NSArray arrayWithObjects:doneButton, nil]];

		//_questionBox.inputAccessoryView = keyboardDoneButtonView;

    }
    return _questionBox;
}

- (UILabel *)charactersRemainingLabel {
    if (!_charactersRemainingLabel) {
	
		//NSString * strCharactersRemaining = [NSString stringWithFormat:@"%s: %d", self.charactersRemainingLabel, self.maxCharacters];

        _charactersRemainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 34, self.viewController.view.bounds.size.width, 20)]; 
        //_charactersRemainingLabel.text = @"characters remaining: 100";
		//_charactersRemainingLabel.text = strCharactersRemaining;
        _charactersRemainingLabel.textColor = [UIColor whiteColor];
        _charactersRemainingLabel.font = [UIFont boldSystemFontOfSize:12.f];
		_charactersRemainingLabel.textAlignment = NSTextAlignmentCenter;	
    }
    return _charactersRemainingLabel;
}

- (UIButton *)submitButton {
    if (!_submitButton) {
        _submitButton = [UIButton new];
        _submitButton.size = CGSizeMake(40, 40);
        //_closeButton.left = self.width - 10 - _closeButton.width;
		_submitButton.left = self.viewController.view.width - 50;
        _submitButton.top = 0;
        [_submitButton setImage:[UIImage imageNamed:@"icon_send"] forState:UIControlStateNormal];
        _submitButton.exclusiveTouch = YES;
		//__weak typeof(self) _self = self;

		[_submitButton addTarget:self action:@selector(submitClicked:) forControlEvents:UIControlEventTouchUpInside];

        //[_submitButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
		
			//UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.alertStopSessionTitle message:self.alertStopSessionMessage delegate:self cancelButtonTitle:self.alertStopSessionNo otherButtonTitles:self.alertStopSessionYes, nil];
			//[alert show];			
        //}];
    }
    return _submitButton;
}

-(void)dismissKeyboard 
{
	NSLog(@"dismissKeyboard clicked!");
    [_questionBox resignFirstResponder];
	[_questionBox setHidden:YES];
	[_questionButton setHidden:NO];
}

-(IBAction)submitClicked:(id)sender
{  
	NSString *textValue = [NSString stringWithFormat:@"%@", self.questionBox.text];
	//NSLog(@"xxxx %@", textValue);

	self.questionBox.text = @"";

	[_questionBox resignFirstResponder];
	[_questionBox setHidden:YES];
	[_questionButton setHidden:NO];

	self.questionTextContainerView.hidden = YES;
	self.questionTextDismissView.hidden = YES;

	questionBoxLines = 0;
	[self resizeQuestionBox];

	//UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"SUCCESS" message:@"Your question has been submitted." delegate:self cancelButtonTitle:self.alertStopSessionNo otherButtonTitles:self.alertStopSessionYes, nil];
	//[alert show];		
	
	//NSDictionary *jsonObj = [ [NSDictionary alloc] initWithObjectsAndKeys: @"question", textValue, nil];
	NSDictionary *jsonObj = [ [NSDictionary alloc] initWithObjectsAndKeys: textValue, @"question", nil];

	CDVPluginResult* pluginResult = nil;	
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: jsonObj];
	[pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()	
	[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];

	UIAlertController * alert = [UIAlertController alertControllerWithTitle:self.alertSuccess message:self.alertQuestionSubmitted preferredStyle:UIAlertControllerStyleAlert];
		
	UIAlertAction* okButton = [UIAlertAction actionWithTitle:self.alertOK style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) 
	{
        //Handle no, thanks button                
    }];

	[alert addAction:okButton];

	[moviePlayer presentViewController:alert animated:YES completion:nil];
	
}

-(IBAction)doneClicked:(id)sender
{
   NSLog(@"dismissKeyboard clicked!");
    [_questionBox resignFirstResponder];
	[_questionBox setHidden:YES];
	[_questionButton setHidden:NO];

	self.questionTextContainerView.hidden = YES;
	self.questionTextDismissView.hidden = YES;		
}

- (void) addQuestion:(UIButton *) sender {

    //NSLog(@"Question icon clicked!");
	[_questionBox becomeFirstResponder];
	[_questionBox setHidden:NO];

	[_questionButton setHidden:YES];

	self.questionTextContainerView.hidden = NO;
	self.questionTextDismissView.hidden = NO;

	
	//[moviePlayer.player pause];
	//[self.viewController dismissViewControllerAnimated:NO completion:nil];

}

@end
