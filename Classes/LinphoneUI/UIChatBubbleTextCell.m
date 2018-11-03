/* UIChatRoomCell.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Library General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "UIChatBubbleTextCell.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"

#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetRepresentation.h>

@implementation UIChatBubbleTextCell

#pragma mark - Lifecycle Functions

- (id)initWithIdentifier:(NSString *)identifier {
	if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier]) != nil) {
		if ([identifier isEqualToString:NSStringFromClass(self.class)]) {
			NSArray *arrayOfViews =
				[[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self.class) owner:self options:nil];
			// resize cell to match .nib size. It is needed when resized the cell to
			// correctly adapt its height too
			UIView *sub = ((UIView *)[arrayOfViews objectAtIndex:arrayOfViews.count - 1]);
			[self setFrame:CGRectMake(0, 0, sub.frame.size.width, sub.frame.size.height)];
			[self addSubview:sub];
		}
	}

	UITapGestureRecognizer *limeRecognizer =
	[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onLime)];
	limeRecognizer.numberOfTapsRequired = 1;
	[_LIMEKO addGestureRecognizer:limeRecognizer];
	_LIMEKO.userInteractionEnabled = YES;
	UITapGestureRecognizer *resendRecognizer =
	[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onResend)];
	resendRecognizer.numberOfTapsRequired = 1;
	[_imdmIcon addGestureRecognizer:resendRecognizer];
	_imdmIcon.userInteractionEnabled = YES;
	UITapGestureRecognizer *resendRecognizer2 =
	[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onResend)];
	resendRecognizer2.numberOfTapsRequired = 1;
	[_imdmLabel addGestureRecognizer:resendRecognizer2];
	_imdmLabel.userInteractionEnabled = YES;

	return self;
}

- (void)dealloc {
	[self setEvent:NULL];
	[self setChatMessage:NULL];
}

#pragma mark -

- (void)setEvent:(LinphoneEventLog *)event {
	if(!event)
		return;

	_event = event;
	if (!(linphone_event_log_get_type(event) == LinphoneEventLogTypeConferenceChatMessage)) {
		LOGE(@"Impossible to create a ChatBubbleText whit a non message event");
		return;
	}
	[self setChatMessage:linphone_event_log_get_chat_message(event)];
}

- (void)setChatMessage:(LinphoneChatMessage *)amessage {
	if (!amessage || amessage == _message) {
		return;
	}

	_message = amessage;
	linphone_chat_message_set_user_data(_message, (void *)CFBridgingRetain(self));
	LinphoneChatMessageCbs *cbs = linphone_chat_message_get_callbacks(_message);
	linphone_chat_message_cbs_set_msg_state_changed(cbs, message_status);
	linphone_chat_message_cbs_set_user_data(cbs, (void *)_event);
}

+ (NSString *)TextMessageForChat:(LinphoneChatMessage *)message {
	const char *url = linphone_chat_message_get_external_body_url(message);
	const LinphoneContent *last_content = linphone_chat_message_get_file_transfer_information(message);
	// Last message was a file transfer (image) so display a picture...
	if (url || last_content) {
        if (linphone_chat_message_get_text_content(message))
            return [NSString stringWithUTF8String:linphone_chat_message_get_text_content(message)];
		return @"🗻";
	} else {
        const char *text = linphone_chat_message_get_text_content(message) ?: "";
		return [NSString stringWithUTF8String:text] ?: [NSString stringWithCString:text encoding:NSASCIIStringEncoding]
														   ?: NSLocalizedString(@"(invalid string)", nil);
	}
}

+ (NSString *)ContactDateForChat:(LinphoneChatMessage *)message {
	const LinphoneAddress *address =
		linphone_chat_message_get_from_address(message)
			? linphone_chat_message_get_from_address(message)
			: linphone_chat_room_get_peer_address(linphone_chat_message_get_chat_room(message));
	return [NSString stringWithFormat:@"%@ - %@", [LinphoneUtils timeToString:linphone_chat_message_get_time(message)
																   withFormat:LinphoneDateChatBubble],
									  [FastAddressBook displayNameForAddress:address]];
}

- (NSString *)textMessage {
	return [self.class TextMessageForChat:_message];
}

- (void)update {
	if (_message == nil) {
		LOGW(@"Cannot update message room cell: null message");
		return;
	}

	_statusInProgressSpinner.accessibilityLabel = @"Delivery in progress";

	if (_messageText && ![LinphoneManager getMessageAppDataForKey:@"localvideo" inMessage:_message]) {
        LOGD(_messageText.text);
		[_messageText setHidden:FALSE];
		/* We need to use an attributed string here so that data detector don't mess
		 * with the text style. See http://stackoverflow.com/a/20669356 */

		NSAttributedString *attr_text =
			[[NSAttributedString alloc] initWithString:self.textMessage
											attributes:@{
												NSFontAttributeName : _messageText.font,
												NSForegroundColorAttributeName : [UIColor darkGrayColor]
											}];
		_messageText.attributedText = attr_text;
	}

	LinphoneChatMessageState state = linphone_chat_message_get_state(_message);
	BOOL outgoing = linphone_chat_message_is_outgoing(_message);

	if (outgoing) {
		_avatarImage.image = [LinphoneUtils selfAvatar];
	} else {
		[_avatarImage setImage:[FastAddressBook imageForAddress:linphone_chat_message_get_from_address(_message)]
					  bordered:NO
			 withRoundedRadius:YES];
	}
	_contactDateLabel.text = [self.class ContactDateForChat:_message];

	_backgroundColorImage.image = _bottomBarColor.image =
		[UIImage imageNamed:(outgoing ? @"color_A.png" : @"color_D.png")];
	_contactDateLabel.textColor = [UIColor colorWithPatternImage:_backgroundColorImage.image];

	if (outgoing && state == LinphoneChatMessageStateInProgress) {
		[_statusInProgressSpinner startAnimating];
	} else if (!outgoing && state == LinphoneChatMessageStateFileTransferError) {
		[_statusInProgressSpinner stopAnimating];
	} else {
		[_statusInProgressSpinner stopAnimating];
	}

	[_messageText setAccessibilityLabel:outgoing ? @"Outgoing message" : @"Incoming message"];
	if (outgoing &&
		(state == LinphoneChatMessageStateDeliveredToUser || state == LinphoneChatMessageStateDisplayed ||
		 state == LinphoneChatMessageStateNotDelivered || state == LinphoneChatMessageStateFileTransferError)) {
		[self displayImdmStatus:state];
	} else
		[self displayImdmStatus:LinphoneChatMessageStateInProgress];

	if (!outgoing && !linphone_chat_message_is_secured(_message) &&
		linphone_core_lime_enabled(LC) == LinphoneLimeMandatory) {
		_LIMEKO.hidden = FALSE;
	} else {
		_LIMEKO.hidden = TRUE;
	}
}

- (void)setEditing:(BOOL)editing {
	[self setEditing:editing animated:FALSE];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	_messageText.userInteractionEnabled = !editing;
	_resendRecognizer.enabled = !editing;
}

- (void)displayLIMEWarning {
	UIAlertController *errView =
		[UIAlertController alertControllerWithTitle:NSLocalizedString(@"LIME warning", nil)
											message:NSLocalizedString(@"This message is not encrypted.", nil)
									 preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
															style:UIAlertActionStyleDefault
														  handler:^(UIAlertAction *action){
														  }];

	[errView addAction:defaultAction];
	[PhoneMainView.instance presentViewController:errView animated:YES completion:nil];
}

- (void)getIcloudFiles {
    _documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"]
                                                                             inMode:UIDocumentPickerModeImport];
    _documentPicker.delegate = self;
 
    _documentPicker.modalPresentationStyle = UIModalPresentationOverCurrentContext ;
    ChatConversationView *view = VIEW(ChatConversationView);
    [view presentViewController:_documentPicker animated:YES completion:nil];
 }
 
 - (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
     NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
     [fileCoordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingWithoutChanges error:nil byAccessor:^(NSURL * _Nonnull newURL) {
         
         NSString *fileName = [newURL lastPathComponent];
         NSData *data = [NSData dataWithContentsOfURL:newURL];
         NSString *option = [LinphoneManager getMessageAppDataForKey:@"icloudFileOption" inMessage:self.message];
         
         if ([option isEqualToString:@"onResend"])
             [_chatRoomDelegate startFileUpload:data withName:fileName];
         else if ([option isEqualToString:@"onFileClick"]) {
             ChatConversationView *view = VIEW(ChatConversationView);
             NSString *filePath = [[LinphoneManager cacheDirectory] stringByAppendingPathComponent:fileName];
             [[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil];
             [view openFile:filePath];
     }
   }];
}


#pragma mark - Action Functions

- (void)onDelete {
	if (_message != NULL) {
		UITableView *tableView = VIEW(ChatConversationView).tableController.tableView;
		NSIndexPath *indexPath = [tableView indexPathForCell:self];
		[tableView.dataSource tableView:tableView
					 commitEditingStyle:UITableViewCellEditingStyleDelete
					  forRowAtIndexPath:indexPath];
	}
}

- (void)onLime {
	if (!_LIMEKO.hidden)
		[self displayLIMEWarning];
}

- (void)onResend {
	if (_message == nil || !linphone_chat_message_is_outgoing(_message))
		return;

	LinphoneChatMessageState state = linphone_chat_message_get_state(_message);
	if (state != LinphoneChatMessageStateNotDelivered && state != LinphoneChatMessageStateFileTransferError)
		return;

	if (linphone_chat_message_get_file_transfer_information(_message) != NULL) {
		NSString *localImage = [LinphoneManager getMessageAppDataForKey:@"localimage" inMessage:_message];
		NSNumber *uploadQuality =[LinphoneManager getMessageAppDataForKey:@"uploadQuality" inMessage:_message];
        NSString *localVideo = [LinphoneManager getMessageAppDataForKey:@"localvideo" inMessage:_message];
        NSString *localFile = [LinphoneManager getMessageAppDataForKey:@"localfile" inMessage:_message];

		[self onDelete];
        if(localImage){
            ChatConversationTableView *tableView = VIEW(ChatConversationView).tableController;
            UIImage *img = [tableView.imagesInChatroom objectForKey:localImage];
            if (img) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL),
                               ^(void) {
                                   [_chatRoomDelegate startImageUpload:img assetId:localImage withQuality:(uploadQuality ? [uploadQuality floatValue] : 0.9)];
                               });
            } else {
                PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:[NSArray arrayWithObject:localImage] options:nil];
                if (![assets firstObject])
                    return;
                PHAsset *asset = [assets firstObject];
                if (asset.mediaType != PHAssetMediaTypeImage)
                    return;
                
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.synchronous = TRUE;
                [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:options
                                                        resultHandler:^(UIImage *image, NSDictionary * info) {
                                                            if (image) {
                                                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL),
                                                                               ^(void) {
                                                                                   [_chatRoomDelegate startImageUpload:img assetId:localImage withQuality:(uploadQuality ? [uploadQuality floatValue] : 0.9)];
                                                                               });
                                                            } else {
                                                                LOGE(@"Can't read image");
                                                            }
                }];
            }
        } else if (localVideo) {
            PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:[NSArray arrayWithObject:localVideo] options:nil];
            if (![assets firstObject])
                return;
            PHAsset *asset = [assets firstObject];
            if (asset.mediaType != PHAssetMediaTypeVideo)
                return;
       
            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            options.version = PHImageRequestOptionsVersionCurrent;
            options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
            
            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                AVURLAsset *urlAsset = (AVURLAsset *)asset;
                    
                NSURL *url = urlAsset.URL;
                NSData *data = [NSData dataWithContentsOfURL:url];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL),
                                ^(void) {
                                    [_chatRoomDelegate startFileUpload:data assetId:localVideo];
                                });
            }];

        } else if (localFile) {
            [LinphoneManager setValueInMessageAppData:@"onResend" forKey:@"icloudFileOption" inMessage:_message];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL),
                           ^(void) {
                               [self getIcloudFiles];
                           });
        }
	} else {
        [self onDelete];
		double delayInSeconds = 0.4;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
		  [_chatRoomDelegate resendChat:self.textMessage withExternalUrl:nil];
		});
	}
}
#pragma mark - State changed handling
static void message_status(LinphoneChatMessage *msg, LinphoneChatMessageState state) {
	LOGI(@"State for message [%p] changed to %s", msg, linphone_chat_message_state_to_string(state));
	LinphoneEventLog *event = (LinphoneEventLog *)linphone_chat_message_cbs_get_user_data(linphone_chat_message_get_callbacks(msg));
	ChatConversationView *view = VIEW(ChatConversationView);
	[view.tableController updateEventEntry:event];
}

- (void)displayImdmStatus:(LinphoneChatMessageState)state {
	if (state == LinphoneChatMessageStateDeliveredToUser) {
		[_imdmIcon setImage:[UIImage imageNamed:@"chat_delivered"]];
		[_imdmLabel setText:NSLocalizedString(@"Delivered", nil)];
		[_imdmLabel setTextColor:[UIColor grayColor]];
		[_imdmIcon setHidden:FALSE];
		[_imdmLabel setHidden:FALSE];
	} else if (state == LinphoneChatMessageStateDisplayed) {
		[_imdmIcon setImage:[UIImage imageNamed:@"chat_read"]];
		[_imdmLabel setText:NSLocalizedString(@"Read", nil)];
		[_imdmLabel setTextColor:([UIColor colorWithRed:(24 / 255.0) green:(167 / 255.0) blue:(175 / 255.0) alpha:1.0])];
		[_imdmIcon setHidden:FALSE];
		[_imdmLabel setHidden:FALSE];
	} else if (state == LinphoneChatMessageStateNotDelivered || state == LinphoneChatMessageStateFileTransferError) {
		[_imdmIcon setImage:[UIImage imageNamed:@"chat_error"]];
		[_imdmLabel setText:NSLocalizedString(@"Resend", nil)];
		[_imdmLabel setTextColor:[UIColor redColor]];
		[_imdmIcon setHidden:FALSE];
		[_imdmLabel setHidden:FALSE];
	} else {
		[_imdmIcon setHidden:TRUE];
		[_imdmLabel setHidden:TRUE];
	}
}

#pragma mark - Bubble size computing

+ (CGSize)computeBoundingBox:(NSString *)text size:(CGSize)size font:(UIFont *)font {
	if (!text || text.length == 0)
		return CGSizeMake(0, 0);

	return [text boundingRectWithSize:size
							  options:(NSStringDrawingUsesLineFragmentOrigin |
									   NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesFontLeading)
						   attributes:@{
							   NSFontAttributeName : font
						   }
							  context:nil].size;
}

static const CGFloat CELL_MIN_HEIGHT = 60.0f;
static const CGFloat CELL_MIN_WIDTH = 190.0f;
static const CGFloat CELL_MESSAGE_X_MARGIN = 78 + 10.0f;
static const CGFloat CELL_MESSAGE_Y_MARGIN = 52; // 44;

+ (CGSize)ViewHeightForMessage:(LinphoneChatMessage *)chat withWidth:(int)width {
	NSString *messageText = [UIChatBubbleTextCell TextMessageForChat:chat];
	static UIFont *messageFont = nil;
    
	if (!messageFont) {
		UIChatBubbleTextCell *cell =
			[[UIChatBubbleTextCell alloc] initWithIdentifier:NSStringFromClass(UIChatBubbleTextCell.class)];
		messageFont = cell.messageText.font;
	}
	width -= 40; /*checkbox */
	CGSize size;
	const char *url = linphone_chat_message_get_external_body_url(chat);
	if (url == nil && linphone_chat_message_get_file_transfer_information(chat) == NULL) {
		size = [self computeBoundingBox:messageText
								   size:CGSizeMake(width - CELL_MESSAGE_X_MARGIN - 4, CGFLOAT_MAX)
								   font:messageFont];
	} else {
		NSString *localImage = [LinphoneManager getMessageAppDataForKey:@"localimage" inMessage:chat];
        NSString *localFile = [LinphoneManager getMessageAppDataForKey:@"localfile" inMessage:chat];
        NSString *localVideo = [LinphoneManager getMessageAppDataForKey:@"localvideo" inMessage:chat];
        
        if(localFile) {
            CGSize fileSize = CGSizeMake(200, 80);
            size = [self getMediaMessageSizefromOriginalSize:fileSize withWidth:width];
        } else {
            if (!localImage && !localVideo) {
                //We are loading the image
                return CGSizeMake(CELL_MIN_WIDTH + CELL_MESSAGE_X_MARGIN, CELL_MIN_HEIGHT + CELL_MESSAGE_Y_MARGIN);
            }
            PHFetchResult<PHAsset *> *assets;
            if(localImage)
                assets = [PHAsset fetchAssetsWithLocalIdentifiers:[NSArray arrayWithObject:localImage] options:nil];
            else
                assets = [PHAsset fetchAssetsWithLocalIdentifiers:[NSArray arrayWithObject:localVideo] options:nil];
            if (![assets firstObject]) {
                return CGSizeMake(CELL_MIN_WIDTH, CELL_MIN_HEIGHT);
            }
            PHAsset *asset = [assets firstObject];
            CGSize originalImageSize = CGSizeMake([asset pixelWidth], [asset pixelHeight]);
            size = [self getMediaMessageSizefromOriginalSize:originalImageSize withWidth:width];
            //This fixes the image being too small. I think the issue comes form the fact that the display is retina. This should probably be changed in the future.
            size.height += 40;
            size.width -= CELL_MESSAGE_X_MARGIN;
            
            if (![messageText isEqualToString:@"🗻"]) {
                CGSize textSize = [self computeBoundingBox:messageText
                                                      size:CGSizeMake(width - CELL_MESSAGE_X_MARGIN - 4, CGFLOAT_MAX)
                                                      font:messageFont];
                size.height += textSize.height;
                size.width = MAX(textSize.width, size.width);
            }
        }
	}
    
	size.width = MAX(size.width + CELL_MESSAGE_X_MARGIN, CELL_MIN_WIDTH);
	size.height = MAX(size.height + CELL_MESSAGE_Y_MARGIN, CELL_MIN_HEIGHT);
	return size;
}
+ (CGSize)ViewSizeForMessage:(LinphoneChatMessage *)chat withWidth:(int)width {
	static UIFont *dateFont = nil;
	static CGSize dateViewSize;

	if (!dateFont) {
		UIChatBubbleTextCell *cell =
			[[UIChatBubbleTextCell alloc] initWithIdentifier:NSStringFromClass(UIChatBubbleTextCell.class)];
		dateFont = cell.contactDateLabel.font;
		dateViewSize = cell.contactDateLabel.frame.size;
		dateViewSize.width = CGFLOAT_MAX;
	}

	CGSize messageSize = [self ViewHeightForMessage:chat withWidth:width];
	CGSize dateSize = [self computeBoundingBox:[self ContactDateForChat:chat] size:dateViewSize font:dateFont];
	messageSize.width = MAX(MAX(messageSize.width, MIN(dateSize.width + CELL_MESSAGE_X_MARGIN, width)), CELL_MIN_WIDTH);

	return messageSize;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (_message != nil) {
		UITableView *tableView = VIEW(ChatConversationView).tableController.tableView;
		BOOL is_outgoing = linphone_chat_message_is_outgoing(_message);
		CGRect bubbleFrame = _bubbleView.frame;
		int available_width = self.frame.size.width;
		int origin_x;

		bubbleFrame.size = [self.class ViewSizeForMessage:_message withWidth:available_width];

		if (tableView.isEditing) {
			origin_x = 0;
		} else {
			origin_x = (is_outgoing ? self.frame.size.width - bubbleFrame.size.width : 0);
		}

		bubbleFrame.origin.x = origin_x;
		_bubbleView.frame = bubbleFrame;
	}
}


+ (CGSize)getMediaMessageSizefromOriginalSize:(CGSize)originalSize withWidth:(int)width {
    CGSize mediaSize = CGSizeMake(0, 0);
    int availableWidth = width;
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
        availableWidth = availableWidth /3;
    }
    int newHeight = originalSize.height;
    float originalAspectRatio = originalSize.width / originalSize.height;
    // We resize in width and crop in height
    if (originalSize.width > availableWidth) {
        newHeight = availableWidth / originalAspectRatio;
    }
    mediaSize.height = MIN(newHeight, availableWidth);
    mediaSize.width = MIN(availableWidth, originalSize.width);
    return mediaSize;
}

@end
