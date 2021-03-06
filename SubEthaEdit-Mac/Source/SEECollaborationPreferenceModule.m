//  SEECollaborationPreferenceModule.m
//  SubEthaEdit
//
//  Created by Lisa Brodner on 10/04/14.

#import "SEECollaborationPreferenceModule.h"

#import "PreferenceKeys.h"

#import "TCMMMUserManager.h"
#import "TCMMMBEEPSessionManager.h"
#import "TCMMMUser.h"
#import "TCMMMUserSEEAdditions.h"
#import "TCMMMPresenceManager.h"

#import <TCMPortMapper/TCMPortMapper.h>
#import "TCMMMBEEPSessionManager.h"

#import <Quartz/Quartz.h>

@interface SEECollaborationPreferenceModule ()
@property (nonatomic, strong) IKPictureTaker *imagePicker;
@property (nonatomic) BOOL showingImageTaker;

@property (nonatomic) BOOL portmapperIsDoingWork;
@end

@implementation SEECollaborationPreferenceModule

#pragma mark - Preference Module - Basics
- (NSImage *)icon {
    return [NSImage imageNamed:@"PrefIconCollaboration"];
}

- (NSString *)iconLabel {
    return NSLocalizedStringWithDefaultValue(@"CollaborationPrefsIconLabel", nil, [NSBundle mainBundle], @"Collaboration", @"Label displayed below collaboration icon and used as window title.");
}

- (NSString *)identifier {
    return @"de.codingmonkeys.subethaedit.preferences.collaboration";
}

- (NSString *)mainNibName {
    return @"SEECollaborationPrefs";
}

- (void)mainViewDidLoad {
    // Initialize user interface elements to reflect current preference settings
	
	[self localizeText];
	[self localizeLayout];

    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    
    TCMMMUser *me = [TCMMMUserManager me];

    [self.O_nameTextField setStringValue:[me name]];
    [self.O_emailTextField setStringValue:[[me properties] objectForKey:@"Email"]];

    [self.O_automaticallyMapPortButton setState:[defaults boolForKey:ShouldAutomaticallyMapPort]?NSOnState:NSOffState];
	
	[self updateLocalPort];
	
    TCMPortMapper *pm = [TCMPortMapper sharedInstance];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portMapperDidStartWork:) name:TCMPortMapperDidStartWorkNotification object:pm];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portMapperDidFinishWork:) name:TCMPortMapperDidFinishWorkNotification object:pm];
    if ([pm isAtWork]) {
        [self portMapperDidStartWork:nil];
    } else {
        [self portMapperDidFinishWork:nil];
    }
	
	[self.O_disableNetworkingButton setState:[TCMMMBEEPSessionManager sharedInstance].isNetworkingDisabled ? NSOnState : NSOffState];
	[self.O_invisibleOnNetworkButton setState:[[TCMMMPresenceManager sharedInstance] isVisible] ? NSOffState : NSOnState];
	
	SEEUserColorsPreviewView *preview = self.O_userColorsPreview;
	NSUserDefaultsController *defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	[preview bind:@"userColorHue" toObject:defaultsController withKeyPath:@"values.MyColorHue" options:nil];
	[preview bind:@"changesSaturation" toObject:defaultsController withKeyPath:@"values.MyChangesSaturation" options:nil];
	[preview bind:@"showsChangesHighlight" toObject:defaultsController withKeyPath:@"values.HighlightChanges" options:nil];
	
	// avatar image view related things
	SEEAvatarImageView *avatarImageView = self.O_avatarImageView;
	avatarImageView.image = me.image; // is updated by the choose image method
	avatarImageView.initials = me.initials; // are updated by the change name method
	[avatarImageView bind:@"borderColor" toObject:defaultsController withKeyPath:@"values.MyColorHue" options:@{ NSValueTransformerNameBindingOption : @"HueToColor"}];
	[avatarImageView enableHoverImage];
	
	NSButton *button = [[NSButton alloc] initWithFrame:avatarImageView.frame];
	[button setAction:@selector(chooseImage:)];
	[button setTarget:self];
	[button setTransparent:YES];
	[avatarImageView.superview addSubview:button positioned:NSWindowAbove relativeTo:avatarImageView];
	
	self.showingImageTaker = NO;
}

- (void)didSelect {
	[super didSelect];
	[self.O_userColorsPreview updateViewWithUserDefaultsValues];
}

#pragma mark - Port Mapper

- (void)updateLocalPort {
	NSString *localPortString = [NSString stringWithFormat:@"%d",[[TCMMMBEEPSessionManager sharedInstance] listeningPort]];
	if ([TCMMMBEEPSessionManager sharedInstance].networkingDisabled) {
		localPortString = NSLocalizedString(@"PORT_NETWORKING_DISABLED", @"");
		[self.O_mappingStatusProgressIndicator stopAnimation:self];
		[self.O_mappingStatusImageView setHidden:YES];
		[self.O_mappingStatusTextField setHidden:YES];
		
	} else {
		// update portmapperstatus as well
		[self.O_mappingStatusTextField setHidden:NO];
		if (self.portmapperIsDoingWork) {
			[self.O_mappingStatusProgressIndicator startAnimation:self];
			[self.O_mappingStatusImageView setHidden:YES];
			[self.O_mappingStatusTextField setStringValue:NSLocalizedString(@"Checking port status...",@"Status of port mapping while trying")];
		} else {
			[self.O_mappingStatusProgressIndicator stopAnimation:self];
			// since we only have one mapping this is fine
			TCMPortMapping *mapping = [[[TCMPortMapper sharedInstance] portMappings] anyObject];
			if ([mapping mappingStatus]==TCMPortMappingStatusMapped) {
				[self.O_mappingStatusImageView setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
				[self.O_mappingStatusTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Port mapped (%d)",@"Status of Port mapping when successful"), [mapping externalPort]]];
			} else {
				[self.O_mappingStatusImageView setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
				[self.O_mappingStatusTextField setStringValue:NSLocalizedString(@"Port not mapped",@"Status of Port mapping when unsuccessful or intentionally unmapped")];
			}
			[self.O_mappingStatusImageView setHidden:NO];
		}
	}
	
    [self.O_localPortTextField setStringValue:localPortString];
}

- (void)portMapperDidStartWork:(NSNotification *)aNotification {
	self.portmapperIsDoingWork = YES;
	[self updateLocalPort];
}

- (void)portMapperDidFinishWork:(NSNotification *)aNotification {
	self.portmapperIsDoingWork = NO;
	[self updateLocalPort];
}

#pragma mark - Me Card - Image

- (void)updateUserWithImage:(NSImage *)anImage {
	TCMMMUser *me = [TCMMMUserManager me];

	if (anImage) {
		[me setImage:anImage];
		[me writeImageToUrl:[TCMMMUser applicationSupportURLForUserImage]];

	} else {
		[me setDefaultImage];
		[me removePersistedUserImage];
	}
	
	[TCMMMUserManager didChangeMe];
}

- (IBAction)chooseImage:(id)aSender {
	if (self.showingImageTaker) {
		[self.imagePicker close];
		[self.imagePicker orderOut:aSender];
		self.showingImageTaker = NO;
	} else {
		if (self.imagePicker == nil) {
			self.imagePicker = ({
				IKPictureTaker *imagePicker = [IKPictureTaker pictureTaker];
				TCMMMUser *me = [TCMMMUserManager me];
				if (![me hasDefaultImage]) {
					[imagePicker setInputImage:me.image]; // is also updated in the chooseImage method
				}

				[imagePicker setValue:[NSValue valueWithSize:NSMakeSize(256., 256.)] forKey:IKPictureTakerOutputImageMaxSizeKey];
				[imagePicker setValue:@(YES) forKey:IKPictureTakerShowAddressBookPictureKey];
				[imagePicker setValue:[me defaultImage] forKey:IKPictureTakerShowEmptyPictureKey]; // is also updated in the change name method
				[imagePicker setValue:@(YES) forKey:IKPictureTakerShowEffectsKey];
				
				imagePicker;
			});
		}

		self.showingImageTaker = YES;
		[self.imagePicker popUpRecentsMenuForView:self.O_avatarImageView withDelegate:self didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

#pragma mark - IKPictureTaker

- (void)pictureTakerDidEnd:(IKPictureTaker *)aPictureTaker returnCode:(NSInteger)aReturnCode contextInfo:(void *)aContextInfo {
	self.showingImageTaker = NO;
    if (aReturnCode != NSModalResponseCancel) {
		NSImage *image = aPictureTaker.outputImage;
		[self updateUserWithImage:image];
		[self.O_avatarImageView setImage:image];
		[self.imagePicker setInputImage:image];
	}
}

#pragma mark - IBActions - Me

- (IBAction)changeName:(id)aSender {
	// TODO: bind to pref - send a user change notification?
	// do not set as kCFPreferencesCurrentUser, kCFPreferencesCurrentHost?!

    TCMMMUser *me=[TCMMMUserManager me];
    NSString *newValue=[self.O_nameTextField stringValue];
    if (![[me name] isEqualTo:newValue]) {
		
        CFStringRef appID = (__bridge CFStringRef)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        // Set up the preference.
        CFPreferencesSetValue((__bridge CFStringRef)MyNamePreferenceKey, (__bridge CFStringRef)newValue, appID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        // Write out the preference data.
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
		
        [me setName:newValue];
        [TCMMMUserManager didChangeMe];
		
		self.O_avatarImageView.initials = me.initials;
		if (me.hasDefaultImage) {
			[self.O_avatarImageView setImage:me.image];
		}

		if (self.imagePicker != nil) {
			[self.imagePicker setValue:[me defaultImage] forKey:IKPictureTakerShowEmptyPictureKey];
		}
    }
}

- (IBAction)changeEmail:(id)aSender {
    TCMMMUser *me=[TCMMMUserManager me];
    NSString *newValue = [self.O_emailTextField stringValue];
    if (![[[me properties] objectForKey:@"Email"] isEqualTo:newValue]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:newValue forKey:MyEmailPreferenceKey];

// TODO: remove MyEmailIdentifierPreferenceKey
// TODO: bind to pref - send a user change notification?
		
        [[me properties] setObject:newValue forKey:@"Email"];
        [TCMMMUserManager didChangeMe];
    }
}

- (IBAction)updateChangesColor:(id)sender {
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];

    NSNumber *userHue = [defaults objectForKey:MyColorHuePreferenceKey];
    [[TCMMMUserManager me] setUserHue:userHue];
    [TCMMMUserManager didChangeMe];
	
	// check if needed?
    [defaults setObject:[defaults objectForKey:ChangesSaturationPreferenceKey] forKey:ChangesSaturationPreferenceKey];
    [defaults setObject:[defaults objectForKey:SelectionSaturationPreferenceKey] forKey:SelectionSaturationPreferenceKey];
	
	[self postGeneralViewPreferencesDidChangeNotificiation:self];
}

#pragma mark - View Update Notification
- (void)TCM_sendGeneralViewPreferencesDidChangeNotificiation {
    [[NSNotificationQueue defaultQueue]
	 enqueueNotification:[NSNotification notificationWithName:GeneralViewPreferencesDidChangeNotificiation object:self]
	 postingStyle:NSPostWhenIdle
	 coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender
	 forModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

- (IBAction)postGeneralViewPreferencesDidChangeNotificiation:(id)aSender {
    [self TCM_sendGeneralViewPreferencesDidChangeNotificiation];
}

#pragma mark - IBActions - Port Mapping
- (IBAction)changeAutomaticallyMapPorts:(id)aSender {
    BOOL shouldStart = ([self.O_automaticallyMapPortButton state]==NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:shouldStart forKey:ShouldAutomaticallyMapPort];
	[[TCMMMBEEPSessionManager sharedInstance] validatePortMapping];
}

- (IBAction)changeDisableNetworking:(id)aSender {
	BOOL networkingDisabled = [self.O_disableNetworkingButton state] == NSOnState ? YES : NO;
	[TCMMMBEEPSessionManager sharedInstance].networkingDisabled = networkingDisabled;
	[self updateLocalPort];
}

- (IBAction)changeVisiblityOnNetwork:(id)aSender {
	[[TCMMMPresenceManager sharedInstance] setVisible:[self.O_invisibleOnNetworkButton state] == NSOffState ? YES : NO];
}

#pragma mark - Localization

- (void)localizeText {
	// me card related
	self.O_avatarImageView.hoverString =
	NSLocalizedStringWithDefaultValue(@"COLLAB_USER_IMAGE_HOVER_STRING", nil, [NSBundle mainBundle],
									  @"Edit",
									  @"Collaboration Preferences - Description to show when the user hovers over the avatar image"
									  );

	self.O_userNameLabel.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_USER_NAME_LABEL", nil, [NSBundle mainBundle],
									  @"Name:",
									  @"Collaboration Preferences - Label for the user name text field"
									  );

	self.O_userEmailLabel.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_USER_EMAIL_LABEL",
									  nil, [NSBundle mainBundle],
									  @"Email:",
									  @"Collaboration Preferences - Label for the user email text field"
									  );

	
	self.O_userColorLabel.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_USER_COLOR_LABEL",
									  nil, [NSBundle mainBundle],
									  @"Color:",
									  @"Collaboration Preferences - Label for the user color slider"
									  );

	self.O_highlightChangesButton.title =
	NSLocalizedStringWithDefaultValue(@"COLLAB_HIGHLIGHT_CHANGES_LABEL",
									  nil, [NSBundle mainBundle],
									  @"Highlight Changes",
									  @"Collaboration Preferences - Label for the highlight changes toggle"
									  );
	
	self.O_highlightChangesSlider.toolTip =
	NSLocalizedStringWithDefaultValue(@"COLLAB_HIGHLIGHT_CHANGES_SLIDER_TOOL_TIP",
									  nil, [NSBundle mainBundle],
									  @"Adjusts the strength of the background color indicating changes.",
									  @"Collaboration Preferences - Tooltip for the highlight changes toggle"
									  );
	
	self.O_changesSaturationLabelPale.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_HIGHLIGHT_CHANGES_SLIDER_LABEL_PALE",
									  nil, [NSBundle mainBundle],
									  @"pale",
									  @"Collaboration Preferences - Label for the highlight changes saturation slider - pale end"
									  );
	
	self.O_changesSaturationLabelStrong.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_HIGHLIGHT_CHANGES_SLIDER_LABEL_STRONG",
									  nil, [NSBundle mainBundle],
									  @"strong",
									  @"Collaboration Preferences - Label for the highlight changes saturation slider - strong end"
									  );
	
	self.O_invisibleOnNetworkButton.title =
	NSLocalizedStringWithDefaultValue(@"COLLAB_NETWORK_INVISIBLE_LABEL", nil, [NSBundle mainBundle],
									  @"Invisible to others on the Network",
									  @"Collaboration Preferences - Label for the invisible on network toggle"
									  );
	
	self.O_invisibleOnNetworkExplanationTextField.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_NETWORK_INVISIBLE_DESCRIPTION", nil, [NSBundle mainBundle],
									  @"You will still be visible if you advertise a document",
									  @"Collaboration Preferences - Label with additional description for the invisible on network toggle"
									  );
	
	// disable networking
	self.O_disableNetworkingButton.title =
	NSLocalizedStringWithDefaultValue(@"COLLAB_NETWORK_DISABLE_LABEL", nil, [NSBundle mainBundle],
									  @"Disable Networking",
									  @"Collaboration Preferences - Label for the disable networking toggle"
									  );
	// network box
	self.O_networkBox.title =
	NSLocalizedStringWithDefaultValue(@"COLLAB_NETWORK_LABEL", nil, [NSBundle mainBundle],
									  @"Network",
									  @"Collaboration Preferences - Label for the network box"
									  );
	
	self.O_localPortLabel.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_LOCAL_PORT_LABEL",
									  nil, [NSBundle mainBundle],
									  @"Local Port:",
									  @"Collaboration Preferences - Label for the local port"
									  );
	
	self.O_automaticallyMapPortButton.title =
	NSLocalizedStringWithDefaultValue(@"COLLAB_AUTOMATICALLY_MAP_PORT_LABEL", nil, [NSBundle mainBundle],
									  @"Try to map port automatically",
									  @"Collaboration Preferences - Label for the automatically map port toggle"
									  );
	
	self.O_automaticallyMapPortButton.toolTip =
	NSLocalizedStringWithDefaultValue(@"COLLAB_AUTOMATICALLY_MAP_PORT_TOOL_TIP", nil, [NSBundle mainBundle],
									  @"SubEthaEdit will try to automatically map the local port to an external port if it is behind a NAT. For this to work you have to enable UPnP or NAT-PMP on your router.",
									  @"Collaboration Preferences - tool tip for the automatically map port toggle"
									  );
	
	self.O_automaticallyMapPortExplanationTextField.stringValue =
	NSLocalizedStringWithDefaultValue(@"COLLAB_AUTOMATICALLY_MAP_PORT_DESCRIPTION", nil, [NSBundle mainBundle],
									  @"NAT traversal uses either NAT-PMP or UPnP",
									  @"Collaboration Preferences - Label with additional description for the automatically map port toggle"
									  );
}

- (void)localizeLayout {
	NSArray *array = [NSLocale preferredLanguages];
	NSString *firstChoice = [array firstObject];
	if ([firstChoice isEqualToString:@"de"] || [firstChoice isEqualToString:@"German"]) {
		// re-layout for German
		CGFloat preWidth = NSWidth(self.O_localPortLabel.frame);
		[self.O_localPortLabel sizeToFit];

		CGAffineTransform transform = CGAffineTransformMakeTranslation(NSWidth(self.O_localPortLabel.frame) - preWidth, 0);
		self.O_localPortTextField.frame = NSRectFromCGRect(CGRectApplyAffineTransform(NSRectToCGRect            (self.O_localPortTextField.frame), transform));
		self.O_mappingStatusImageView.frame = NSRectFromCGRect(CGRectApplyAffineTransform(NSRectToCGRect        (self.O_mappingStatusImageView.frame), transform));;
		self.O_mappingStatusProgressIndicator.frame = NSRectFromCGRect(CGRectApplyAffineTransform(NSRectToCGRect(self.O_mappingStatusProgressIndicator.frame), transform));
		self.O_mappingStatusTextField.frame = NSRectFromCGRect(CGRectApplyAffineTransform(NSRectToCGRect        (self.O_mappingStatusTextField.frame), transform));
	}
}

@end
