//
//  UIViewController+STPopup.m
//  STPopup
//
//  Created by Kevin Lin on 13/9/15.
//  Copyright (c) 2015 Sth4Me. All rights reserved.
//

#import "UIViewController+STPopup.h"
#import "STPopupController.h"
#import <objc/runtime.h>

@implementation UIViewController (STPopup)

@dynamic contentSizeInPopup;
@dynamic landscapeContentSizeInPopup;
@dynamic popupController;

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleSelector:@selector(viewDidLoad) toSelector:@selector(st_viewDidLoad)];
        [self swizzleSelector:@selector(presentViewController:animated:completion:) toSelector:@selector(st_presentViewController:animated:completion:)];
        [self swizzleSelector:@selector(dismissViewControllerAnimated:completion:) toSelector:@selector(st_dismissViewControllerAnimated:completion:)];
        [self swizzleSelector:@selector(presentedViewController) toSelector:@selector(st_presentedViewController)];
        [self swizzleSelector:@selector(presentingViewController) toSelector:@selector(st_presentingViewController)];
    });
}

+ (void)swizzleSelector:(SEL)originalSelector toSelector:(SEL)swizzledSelector
{
    Class class = [self class];
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)st_viewDidLoad
{
    CGSize contentSize = CGSizeZero;
    switch ([UIApplication sharedApplication].statusBarOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight: {
            contentSize = self.landscapeContentSizeInPopup;
            if (CGSizeEqualToSize(contentSize, CGSizeZero)) {
                contentSize = self.contentSizeInPopup;
            }
        }
            break;
        default: {
            contentSize = self.contentSizeInPopup;
        }
            break;
    }
    
    if (!CGSizeEqualToSize(contentSize, CGSizeZero)) {
        self.view.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    [self st_viewDidLoad];
}

- (void)st_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion
{
    if (!self.popupController) {
        [self st_rotateIfNeededForViewController:viewControllerToPresent completion:^{
            [self st_presentViewController:viewControllerToPresent animated:flag completion:completion];
        }];
        return;
    }
    
    [[self.popupController valueForKey:@"containerViewController"] presentViewController:viewControllerToPresent animated:flag completion:completion];
}

- (void)st_dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    if (!self.popupController) {
        UIViewController *controller = self.presentingViewController;
        if (!controller) {
            controller = self;
        }
        [self st_rotateIfNeededForViewController:controller completion:^{
            [self st_dismissViewControllerAnimated:flag completion:completion];
        }];
        return;
    }
    
    [self.popupController dismissWithCompletion:completion];
}

- (void)st_rotateIfNeededForViewController:(UIViewController *)viewController completion:(dispatch_block_t)completion {
    UIInterfaceOrientationMask mask = [viewController supportedInterfaceOrientations];
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    UIInterfaceOrientationMask statusBarOrientationMask = 1 << statusBarOrientation;
    if ((mask & statusBarOrientationMask) != statusBarOrientationMask) {
        UIDeviceOrientation orientation = UIDeviceOrientationUnknown;
        if ((mask & UIInterfaceOrientationMaskLandscapeLeft) == UIInterfaceOrientationMaskLandscapeLeft) {
            orientation = UIDeviceOrientationLandscapeRight;
        } else if ((mask & UIInterfaceOrientationMaskLandscapeRight) == UIInterfaceOrientationMaskLandscapeRight) {
            orientation = UIDeviceOrientationLandscapeLeft;
        } else if ((mask & UIInterfaceOrientationMaskPortraitUpsideDown) == UIInterfaceOrientationMaskPortraitUpsideDown) {
            orientation = UIDeviceOrientationPortraitUpsideDown;
        } else {
            orientation = UIDeviceOrientationPortrait;
        }
        [self st_rotateToOrientation:orientation completion:completion];
    } else {
        if (completion) {
            completion();
        }
    }
}

- (void)st_rotateToOrientation:(UIDeviceOrientation)orientation
                    completion:(nullable dispatch_block_t)completion {
    if (@available(iOS 16.0, *)) {
        [self setNeedsUpdateOfSupportedInterfaceOrientations];
        UIWindowScene *scene = self.view.window.windowScene;
        UIWindowSceneGeometryPreferencesIOS *preferences = ({
            [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:(1 << orientation)];
        });
        [scene requestGeometryUpdateWithPreferences:preferences
                                       errorHandler:^(NSError * _Nonnull error) {
#if DEBUG
            NSLog(@"%@", error);
#endif
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });
        return;
    }
    
    [[UIDevice currentDevice] setValue:@(orientation) forKey:@"orientation"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) {
            completion();
        }
    });
}

- (UIViewController *)st_presentedViewController
{
    if (!self.popupController) {
        return [self st_presentedViewController];
    }
    return [[self.popupController valueForKey:@"containerViewController"] presentedViewController];
}

- (UIViewController *)st_presentingViewController
{
    if (!self.popupController) {
        return [self st_presentingViewController];
    }
    return [[self.popupController valueForKey:@"containerViewController"] presentingViewController];
}

- (void)setContentSizeInPopup:(CGSize)contentSizeInPopup
{
    if (!CGSizeEqualToSize(CGSizeZero, contentSizeInPopup) && contentSizeInPopup.width == 0) {
        switch ([UIApplication sharedApplication].statusBarOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
            case UIInterfaceOrientationLandscapeRight: {
                contentSizeInPopup.width = [UIScreen mainScreen].bounds.size.height;
            }
                break;
            default: {
                contentSizeInPopup.width = [UIScreen mainScreen].bounds.size.width;
            }
                break;
        }
    }
    objc_setAssociatedObject(self, @selector(contentSizeInPopup), [NSValue valueWithCGSize:contentSizeInPopup], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)contentSizeInPopup
{
    return [objc_getAssociatedObject(self, @selector(contentSizeInPopup)) CGSizeValue];
}

- (void)setLandscapeContentSizeInPopup:(CGSize)landscapeContentSizeInPopup
{
    if (!CGSizeEqualToSize(CGSizeZero, landscapeContentSizeInPopup) && landscapeContentSizeInPopup.width == 0) {
        switch ([UIApplication sharedApplication].statusBarOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
            case UIInterfaceOrientationLandscapeRight: {
                landscapeContentSizeInPopup.width = [UIScreen mainScreen].bounds.size.width;
            }
                break;
            default: {
                landscapeContentSizeInPopup.width = [UIScreen mainScreen].bounds.size.height;
            }
                break;
        }
    }
    objc_setAssociatedObject(self, @selector(landscapeContentSizeInPopup), [NSValue valueWithCGSize:landscapeContentSizeInPopup], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)landscapeContentSizeInPopup
{
    return [objc_getAssociatedObject(self, @selector(landscapeContentSizeInPopup)) CGSizeValue];
}

- (void)setPopupController:(STPopupController *)popupController
{
    objc_setAssociatedObject(self, @selector(popupController), popupController, OBJC_ASSOCIATION_ASSIGN);
}

- (STPopupController *)popupController
{
    STPopupController *popupController = objc_getAssociatedObject(self, @selector(popupController));
    if (!popupController) {
        return self.parentViewController.popupController;
    }
    return popupController;
}

@end
