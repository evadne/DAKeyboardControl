//
//  DAKeyboardControl.m
//  DAKeyboardControlExample
//
//  Created by Daniel Amitay on 7/14/12.
//  Copyright (c) 2012 Daniel Amitay. All rights reserved.
//

#import "DAKeyboardControl.h"
#import <objc/runtime.h>

static char UIViewKeyboardTriggerOffset;
static char UIViewKeyboardDidMoveBlock;
static char UIViewKeyboardActiveInput;
static char UIViewKeyboardActiveView;
static char UIViewKeyboardPanRecognizer;

@interface UIView (DAKeyboardControl_Internal) <UIGestureRecognizerDelegate>

@property (nonatomic) DAKeyboardDidMoveBlock keyboardDidMoveBlock;
@property (nonatomic, assign) UIResponder *keyboardActiveInput;
@property (nonatomic, assign) UIView *keyboardActiveView;
@property (nonatomic, strong) UIPanGestureRecognizer *keyboardPanRecognizer;

@end

@implementation UIView (DAKeyboardControl)
@dynamic keyboardTriggerOffset;

#pragma mark - Public Methods

- (void)addKeyboardPanningWithActionHandler:(DAKeyboardDidMoveBlock)actionHandler
{
    [self addKeyboardControl:YES actionHandler:actionHandler];
}

- (void)addKeyboardNonpanningWithActionHandler:(DAKeyboardDidMoveBlock)actionHandler
{
    [self addKeyboardControl:NO actionHandler:actionHandler];
}

- (void)addKeyboardControl:(BOOL)panning actionHandler:(DAKeyboardDidMoveBlock)actionHandler
{
    self.keyboardDidMoveBlock = actionHandler;
    
    // Register for text input notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(responderDidBecomeActive:)
                                                 name:UITextFieldTextDidBeginEditingNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(responderDidBecomeActive:)
                                                 name:UITextViewTextDidBeginEditingNotification
                                               object:nil];
    
    // Register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputKeyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputKeyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    
    // For the sake of 4.X compatibility
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputKeyboardWillChangeFrame:)
                                                 name:@"UIKeyboardWillChangeFrameNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputKeyboardDidChangeFrame:)
                                                 name:@"UIKeyboardDidChangeFrameNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputKeyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputKeyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    
    if (panning)
    {
        // Register for gesture recognizer calls
        self.keyboardPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(panGestureDidChange:)];
        [self.keyboardPanRecognizer setMinimumNumberOfTouches:1];
        [self.keyboardPanRecognizer setDelegate:self];
        [self addGestureRecognizer:self.keyboardPanRecognizer];
    }
}

- (CGRect)keyboardFrameInView
{
    if (self.keyboardActiveView)
    {
        CGRect keyboardFrameInView = [self convertRect:self.keyboardActiveView.frame
                                              fromView:self.keyboardActiveView.window];
        return keyboardFrameInView;
    }
    else
    {
        CGRect keyboardFrameInView = CGRectMake(0.0f,
                                                [[UIScreen mainScreen] bounds].size.height,
                                                0.0f,
                                                0.0f);
        return keyboardFrameInView;
    }
}

- (void)removeKeyboardControl
{
    // Unregister for text input notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextFieldTextDidBeginEditingNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextViewTextDidBeginEditingNotification
                                                  object:nil];
    
    // Unregister for keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    
    // For the sake of 4.X compatibility
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"UIKeyboardWillChangeFrameNotification"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"UIKeyboardDidChangeFrameNotification"
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidHideNotification
                                                  object:nil];
    
    // Unregister any gesture recognizer
    [self removeGestureRecognizer:self.keyboardPanRecognizer];
    
    // Release a few properties
    self.keyboardDidMoveBlock = nil;
    self.keyboardActiveInput = nil;
    self.keyboardActiveView = nil;
    self.keyboardPanRecognizer = nil;
}

- (void)hideKeyboard
{
    self.keyboardActiveView.hidden = YES;
    self.keyboardActiveView.userInteractionEnabled = NO;
    [self.keyboardActiveInput resignFirstResponder];
}

#pragma mark - Input Notifications

- (void)responderDidBecomeActive:(NSNotification *)notification
{
    // Grab the active input, it will be used to find the keyboard view later on
    self.keyboardActiveInput = notification.object;
    if (!self.keyboardActiveInput.inputAccessoryView)
    {
        UITextField *textField = (UITextField *)self.keyboardActiveInput;
        UIView *nullView = [[UIView alloc] initWithFrame:CGRectZero];
        nullView.backgroundColor = [UIColor clearColor];
        textField.inputAccessoryView = nullView;
        self.keyboardActiveInput = (UIResponder *)textField;
        // Force the keyboard active view reset
        [self inputKeyboardDidShow:nil];
    }
}

#pragma mark - Keyboard Notifications

- (UIViewAnimationOptions) animationOptionsForCurve:(UIViewAnimationCurve)curve {
	return ((UIViewAnimationOptions[]){
		[UIViewAnimationCurveEaseInOut] = UIViewAnimationOptionCurveEaseInOut,
		[UIViewAnimationCurveEaseIn] = UIViewAnimationOptionCurveEaseIn,
		[UIViewAnimationCurveEaseOut] = UIViewAnimationOptionCurveEaseOut,
		[UIViewAnimationCurveLinear] = UIViewAnimationOptionCurveLinear
	})[curve];
}

- (void)inputKeyboardWillShow:(NSNotification *)notification
{
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrameWindow];
    
    double keyboardTransitionDuration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&keyboardTransitionDuration];
    
    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&keyboardTransitionAnimationCurve];
    
    self.keyboardActiveView.hidden = NO;
    
    CGRect keyboardEndFrameView = [self convertRect:keyboardEndFrameWindow fromView:nil];
    
    [UIView animateWithDuration:keyboardTransitionDuration
                          delay:0.0f
                        options:[self animationOptionsForCurve:keyboardTransitionAnimationCurve]
                     animations:^{
                         if (self.keyboardDidMoveBlock)
                             self.keyboardDidMoveBlock(keyboardEndFrameView);
                     }
                     completion:^(BOOL finished){
                     }];
}

- (void)inputKeyboardDidShow:(NSNotification *)notification
{
    // Grab the keyboard view
    self.keyboardActiveView = self.keyboardActiveInput.inputAccessoryView.superview;
    self.keyboardActiveView.hidden = NO;
    
    // If the active keyboard view could not be found (UITextViews...), try again
    if (!self.keyboardActiveView)
    {
        // Find the first responder on subviews and look re-assign first responder to it
        [self reAssignFirstResponder];
    }
}

- (void)inputKeyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrameWindow];
    
    double keyboardTransitionDuration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&keyboardTransitionDuration];
    
    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&keyboardTransitionAnimationCurve];
		
		
    
    CGRect keyboardEndFrameView = [self convertRect:keyboardEndFrameWindow fromView:nil];
    
    [UIView animateWithDuration:keyboardTransitionDuration
                          delay:0.0f
                        options:[self animationOptionsForCurve:keyboardTransitionAnimationCurve]
                     animations:^{
                         if (self.keyboardDidMoveBlock)
                             self.keyboardDidMoveBlock(keyboardEndFrameView);
                     }
                     completion:^(BOOL finished){
                     }];
}

- (void)inputKeyboardDidChangeFrame:(NSNotification *)notification
{
    // Nothing to see here
}

- (void)inputKeyboardWillHide:(NSNotification *)notification
{
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrameWindow];
    
    double keyboardTransitionDuration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&keyboardTransitionDuration];
    
    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&keyboardTransitionAnimationCurve];
    
    CGRect keyboardEndFrameView = [self convertRect:keyboardEndFrameWindow fromView:nil];
    
    [UIView animateWithDuration:keyboardTransitionDuration
                          delay:0.0f
                        options:[self animationOptionsForCurve:keyboardTransitionAnimationCurve]
                     animations:^{

                         if (self.keyboardDidMoveBlock)
                             self.keyboardDidMoveBlock(keyboardEndFrameView);
                     }
                     completion:^(BOOL finished){
                     }];
}

- (void)inputKeyboardDidHide:(NSNotification *)notification
{
    self.keyboardActiveView.hidden = NO;
    self.keyboardActiveView.userInteractionEnabled = YES;
    self.keyboardActiveView = nil;
}

#pragma mark - Touches Management

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == self.keyboardPanRecognizer || otherGestureRecognizer == self.keyboardPanRecognizer)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == self.keyboardPanRecognizer)
    {
        // Don't allow panning if inside the active input (unless SELF is a UITextView and the receiving view)
        return (![touch.view isFirstResponder] || ([self isKindOfClass:[UITextView class]] && [self isEqual:touch.view]));
    }
    else
    {
        return YES;
    }
}

- (void) panGestureDidChange:(UIPanGestureRecognizer *)panGestureRecognizer {
	
	UIView * const keyboard = self.keyboardActiveView;
	UIResponder * const input = self.keyboardActiveInput;
	
	if (!keyboard || !input || keyboard.hidden) {
		[self reAssignFirstResponder];
		return;
	}

	keyboard.hidden = NO;
	
	CGFloat const keyboardViewHeight = keyboard.bounds.size.height;
	CGFloat const keyboardWindowHeight = keyboard.window.bounds.size.height;
	CGPoint const touchLocationInKeyboardWindow = [panGestureRecognizer locationInView:keyboard.window];
    
	//	If touch is inside trigger offset, then disable keyboard input
	keyboard.userInteractionEnabled = touchLocationInKeyboardWindow.y <= (keyboardWindowHeight - keyboardViewHeight - self.keyboardTriggerOffset);
	
	switch (panGestureRecognizer.state) {
		
		case UIGestureRecognizerStateBegan: {
			break;
		}
		
		case UIGestureRecognizerStateChanged: {

			CGRect fromKeyboardBounds = keyboard.bounds;
			CGPoint fromKeyboardCenter = keyboard.center;
			
			CGPoint fromKeyboardTopLeft = (CGPoint){
				fromKeyboardCenter.x - 0.5f * CGRectGetWidth(fromKeyboardBounds),
				fromKeyboardCenter.y - 0.5f * CGRectGetHeight(fromKeyboardBounds)
			};
			
			CGPoint toKeyboardTopLeft = (CGPoint){
				fromKeyboardTopLeft.x,
				MAX(
					MIN(
						touchLocationInKeyboardWindow.y + self.keyboardTriggerOffset,
						keyboardWindowHeight
					),
					keyboardWindowHeight - keyboardViewHeight
				)
			};
					
			if (!CGPointEqualToPoint(fromKeyboardTopLeft, toKeyboardTopLeft)) {
			
				[UIView animateWithDuration:0.0f delay:0.0f options:UIViewAnimationOptionTransitionNone animations:^{
					
					keyboard.center = (CGPoint){
						toKeyboardTopLeft.x + 0.5f * CGRectGetWidth(fromKeyboardBounds),
						toKeyboardTopLeft.y + 0.5f * CGRectGetHeight(fromKeyboardBounds)
					};
					
					if (self.keyboardDidMoveBlock) {
						self.keyboardDidMoveBlock([self convertRect:keyboard.frame fromView:keyboard.superview]);
					}
				
				} completion:nil];
				
			}
			
			break;
			
		}

		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled: {
			
			CGFloat thresholdHeight = keyboardWindowHeight - keyboardViewHeight - self.keyboardTriggerOffset + 44.0f;
			CGPoint velocity = [panGestureRecognizer velocityInView:self.keyboardActiveView];
			BOOL shouldRecede = !(touchLocationInKeyboardWindow.y < thresholdHeight || velocity.y < 0);
			
			CGRect fromKeyboardBounds = keyboard.bounds;
			CGPoint fromKeyboardCenter = keyboard.center;
			
			CGPoint fromKeyboardTopLeft = (CGPoint){
				fromKeyboardCenter.x - 0.5f * CGRectGetWidth(fromKeyboardBounds),
				fromKeyboardCenter.y - 0.5f * CGRectGetHeight(fromKeyboardBounds)
			};
			
			CGPoint toKeyboardTopLeft = (CGPoint){
				fromKeyboardTopLeft.x,
				(shouldRecede ?
					keyboardWindowHeight :
					(keyboardWindowHeight - keyboardViewHeight))
			};
			
			// If the keyboard has only been pushed down 44 pixels or has been panned upwards let it pop back up; otherwise, let it drop down
      
			if (!CGPointEqualToPoint(fromKeyboardTopLeft, toKeyboardTopLeft)) {

				[UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{

					keyboard.center = (CGPoint){
						toKeyboardTopLeft.x + 0.5f * CGRectGetWidth(fromKeyboardBounds),
						toKeyboardTopLeft.y + 0.5f * CGRectGetHeight(fromKeyboardBounds)
					};

					if (self.keyboardDidMoveBlock) {
						self.keyboardDidMoveBlock([self convertRect:(CGRect){
							toKeyboardTopLeft,
							fromKeyboardBounds.size
						} fromView:keyboard.superview]);
					}
			 
			} completion:^(BOOL finished){
				
				if (shouldRecede)
					[self hideKeyboard];
						 
			 }];
			
			}
		
			break;
			
		}
		
		default: {
			break;
		}
		
	}
}

#pragma mark - Internal Methods

- (void)reAssignFirstResponder
{
    // Find first responder
    UIView *inputView = [self recursiveFindFirstResponder:self];
    if (inputView != nil)
    {
        // Re assign the focus
        [inputView resignFirstResponder];
        [inputView becomeFirstResponder];
    }
}

- (UIView *)recursiveFindFirstResponder:(UIView *)view
{
    if ([view isFirstResponder])
    {
        return view;
    }
    UIView *found = nil;
    for (UIView *v in view.subviews)
    {
        found = [self recursiveFindFirstResponder:v];
        if (found)
        {
            break;
        }
    }
    return found;
}

#pragma mark - Property Methods

- (DAKeyboardDidMoveBlock)keyboardDidMoveBlock
{
    return objc_getAssociatedObject(self,
                                    &UIViewKeyboardDidMoveBlock);
}

- (void)setKeyboardDidMoveBlock:(DAKeyboardDidMoveBlock)keyboardDidMoveBlock
{
    [self willChangeValueForKey:@"keyboardDidMoveBlock"];
    objc_setAssociatedObject(self,
                             &UIViewKeyboardDidMoveBlock,
                             keyboardDidMoveBlock,
                             OBJC_ASSOCIATION_COPY);
    [self didChangeValueForKey:@"keyboardDidMoveBlock"];
}

- (CGFloat)keyboardTriggerOffset
{
    NSNumber *keyboardTriggerOffsetNumber = objc_getAssociatedObject(self,
                                                                     &UIViewKeyboardTriggerOffset);
    return [keyboardTriggerOffsetNumber floatValue];
}

- (void)setKeyboardTriggerOffset:(CGFloat)keyboardTriggerOffset
{
    [self willChangeValueForKey:@"keyboardTriggerOffset"];
    objc_setAssociatedObject(self,
                             &UIViewKeyboardTriggerOffset,
                             [NSNumber numberWithFloat:keyboardTriggerOffset],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"keyboardTriggerOffset"];
}

- (UIResponder *)keyboardActiveInput
{
    return objc_getAssociatedObject(self,
                                    &UIViewKeyboardActiveInput);
}

- (void)setKeyboardActiveInput:(UIResponder *)keyboardActiveInput
{
    [self willChangeValueForKey:@"keyboardActiveInput"];
    objc_setAssociatedObject(self,
                             &UIViewKeyboardActiveInput,
                             keyboardActiveInput,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"keyboardActiveInput"];
}

- (UIView *)keyboardActiveView
{
    return objc_getAssociatedObject(self,
                                    &UIViewKeyboardActiveView);
}

- (void)setKeyboardActiveView:(UIView *)keyboardActiveView
{
    [self willChangeValueForKey:@"keyboardActiveView"];
    objc_setAssociatedObject(self,
                             &UIViewKeyboardActiveView,
                             keyboardActiveView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"keyboardActiveView"];
}

- (UIPanGestureRecognizer *)keyboardPanRecognizer
{
    return objc_getAssociatedObject(self,
                                    &UIViewKeyboardPanRecognizer);
}

- (void)setKeyboardPanRecognizer:(UIPanGestureRecognizer *)keyboardPanRecognizer
{
    [self willChangeValueForKey:@"keyboardPanRecognizer"];
    objc_setAssociatedObject(self,
                             &UIViewKeyboardPanRecognizer,
                             keyboardPanRecognizer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"keyboardPanRecognizer"];
}

@end