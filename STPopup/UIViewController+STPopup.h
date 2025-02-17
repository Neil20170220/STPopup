//
//  UIViewController+STPopup.h
//  STPopup
//
//  Created by Kevin Lin on 13/9/15.
//  Copyright (c) 2015 Sth4Me. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class STPopupController;

@protocol UIViewControllerSTPopupProtocol <NSObject>

@optional
/**
 底部边距
 */
- (CGFloat)actionSheetBottomMargin;

@end

@interface UIViewController (STPopup)

/**
 Content size of popup in portrait orientation.
 */
@property (nonatomic, assign) IBInspectable CGSize contentSizeInPopup;

/**
 Content size of popup in landscape orientation.
 */
@property (nonatomic, assign) IBInspectable CGSize landscapeContentSizeInPopup;

/**
 Popup controller which is containing the view controller.
 Will be nil if the view controller is not contained in any popup controller.
 */
@property (nullable, nonatomic, weak, readonly) STPopupController *popupController;

@end

NS_ASSUME_NONNULL_END
