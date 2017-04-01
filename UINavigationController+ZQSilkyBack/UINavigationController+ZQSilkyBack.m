//
//  UINavigationController+ZQSilkyBack.m
//  testNavBar
//
//  Created by 张泉 on 2017/3/23.
//  Copyright © 2017年 张泉. All rights reserved.
//

#import "UINavigationController+ZQSilkyBack.h"
#import <objc/runtime.h>

#define IS_IOS10_Later ([[[UIDevice currentDevice] systemVersion] floatValue] >=10.0)

static void exchange_method(Class class, SEL originalSelector, SEL swizzlingSelector){
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzlingMethod = class_getInstanceMethod(class, swizzlingSelector);
    
    BOOL didAddMethod =  class_addMethod( class, originalSelector,  method_getImplementation(swizzlingMethod), method_getTypeEncoding(swizzlingMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class, swizzlingSelector, method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    }
    else {
        method_exchangeImplementations(originalMethod, swizzlingMethod);
    }
}

@interface _FDFullscreenPopGestureRecognizerDelegate : NSObject <UIGestureRecognizerDelegate>

@property (nonatomic, weak) UINavigationController *navigationController;

@end

#pragma mark - 自定义左滑返回的手势代理
@implementation _FDFullscreenPopGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    // Ignore when no view controller is pushed into the navigation stack.
    if (self.navigationController.viewControllers.count <= 1) {
        return NO;
    }
    
    // Ignore when the active view controller doesn't allow interactive pop.
    UIViewController *topViewController = self.navigationController.viewControllers.lastObject;
    if (topViewController.zq_interactivePopDisabled) {
        return NO;
    }
    
    // Ignore when the beginning location is beyond max allowed initial distance to left edge.
    CGPoint beginningLocation = [gestureRecognizer locationInView:gestureRecognizer.view];
    CGFloat maxAllowedInitialDistance = topViewController.zq_popEdgeRegionSize;
    if (maxAllowedInitialDistance > 0 && beginningLocation.x > maxAllowedInitialDistance) {
        return NO;
    }
    
    // Ignore pan gesture when the navigation controller is currently in transition.
    if ([[self.navigationController valueForKey:@"_isTransitioning"] boolValue]) {
        return NO;
    }
    
    // Prevent calling the handler when the gesture begins in an opposite direction.
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    if (translation.x <= 0) {
        return NO;
    }
    
    return YES;
}
@end


#pragma mark -  导航栏分类
@implementation UINavigationController (ZQSilkyBack)

+ (void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        // Inject "-pushViewController:animated:"
        exchange_method([self class], @selector(pushViewController:animated:), @selector(zq_pushViewController:animated:));
        // Inject "-_updateInteractiveTransition:"
        exchange_method([self class], NSSelectorFromString(@"_updateInteractiveTransition:"), NSSelectorFromString(@"zq_updateInteractiveTransition:"));
        
        // Inject "-popViewControllerAnimated:"
        exchange_method([self class], @selector(popViewControllerAnimated:), @selector(zq_popViewControllerAnimated:));
        
        // Inject "-popToViewController:animated:"
        exchange_method([self class], @selector(popToViewController:animated:), @selector(zq_popToViewController:animated:));
        
        // Inject "-popToRootViewControllerAnimated:"
        exchange_method([self class], @selector(popToRootViewControllerAnimated:), @selector(zq_popToRootViewControllerAnimated:));
        
        // Inject "-popToRootViewControllerAnimated:"
        exchange_method([self class], @selector(childViewControllerForStatusBarStyle), @selector(zq_childViewControllerForStatusBarStyle));
    });
}

//修改了手势代理的时候，在push过程中触发手势滑动返回，会导致导航栏崩溃 需要在push 的时候禁用手势
- (void)zq_pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    
    viewController.hidesBottomBarWhenPushed =YES;
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.zq_fullscreenPopGestureRecognizer]) {
        
        // Add our own gesture recognizer to where the onboard screen edge pan gesture recognizer is attached to.
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.zq_fullscreenPopGestureRecognizer];
        
        // Forward the gesture events to the private handler of the onboard gesture recognizer.
        NSArray *internalTargets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id internalTarget = [internalTargets.firstObject valueForKey:@"target"];
        SEL internalAction = NSSelectorFromString(@"handleNavigationTransition:");
        
        self.zq_fullscreenPopGestureRecognizer.delegate = self.zq_popGestureRecognizerDelegate;
        [self.zq_fullscreenPopGestureRecognizer addTarget:internalTarget action:internalAction];
        
        // Disable the onboard gesture recognizer.
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    
    // Forward to primary implementation.
    if (![self.viewControllers containsObject:viewController]) { //执行 pop 动作
        
        UIViewController *fromViewcontroller = self.topViewController;
        CGFloat time = [self transitonTimeWithOperation:UINavigationControllerOperationPush fromViewController:fromViewcontroller toViewController:viewController];
        
        
        if (fromViewcontroller.zq_navBarAlpha == viewController.zq_navBarAlpha) {
            [self zq_pushViewController:viewController animated:YES];
            return;
        }
       
        [UIView animateWithDuration:time animations:^{
            [self zq_setNavigationBackgroundAlphaIfNeeded:viewController.zq_navBarAlpha];
        } completion:^(BOOL finished) {
        }];
        [self zq_pushViewController:viewController animated:animated];
        return;
    }
}

-(void) zq_updateInteractiveTransition:(CGFloat)percentComplete {
    [self zq_updateInteractiveTransition:(percentComplete)];
    UIViewController *topVC = self.topViewController;
    if (topVC) {
        id<UIViewControllerTransitionCoordinator> coor = topVC.transitionCoordinator;
        if (coor != nil) {
            // 随着滑动的过程设置导航栏透明度渐变
            CGFloat fromAlpha = [coor viewControllerForKey:UITransitionContextFromViewControllerKey].zq_navBarAlpha ;
            CGFloat toAlpha = [coor viewControllerForKey:UITransitionContextToViewControllerKey].zq_navBarAlpha ;
            CGFloat nowAlpha = fromAlpha + (toAlpha - fromAlpha) * percentComplete;
            [self zq_setNavigationBackgroundAlphaIfNeeded:nowAlpha];
        }
    }
}

-(nullable UIViewController *) zq_popViewControllerAnimated:(BOOL)animated{
    __weak UIViewController *fromViewContrller = self.topViewController;
    CGFloat fromAlpha = fromViewContrller.zq_navBarAlpha;
    __weak NSArray *vcs = self.viewControllers;
    if (vcs.count < 2) {
        return [self zq_popViewControllerAnimated:animated];
        
    }
    __weak UIViewController *toViewController = [vcs objectAtIndex:vcs.count-2];
    CGFloat toAlpha = toViewController.zq_navBarAlpha;
    if (fromAlpha == toAlpha) { //不需要 pop 动画
        return [self zq_popViewControllerAnimated:animated];

    }
    if (!animated) {//不需要 pop 动画
        [self zq_setNavigationBackgroundAlphaIfNeeded:toAlpha];
        return  [self zq_popViewControllerAnimated:animated];

    }
    //点击按钮或者代码引起的pop
    CGFloat time = [self transitonTimeWithOperation:UINavigationControllerOperationPop fromViewController:fromViewContrller toViewController:[vcs objectAtIndex:vcs.count-2]];
    [UIView animateWithDuration:time animations:^{
        [self zq_setNavigationBackgroundAlphaIfNeeded:toAlpha];
    } completion:^(BOOL finished) {
    }];
    
    return [self zq_popViewControllerAnimated:animated];
}

-(nullable NSArray<__kindof UIViewController *> *) zq_popToViewController:(UIViewController *)viewController animated:(BOOL)animated{
    
    [self zq_setNavigationBackgroundAlphaIfNeeded:viewController.zq_navBarAlpha];
    return [self zq_popToViewController: viewController animated:animated];
}

-(nullable NSArray<__kindof UIViewController *> *) zq_popToRootViewControllerAnimated:(BOOL)animated{
    [self zq_setNavigationBackgroundAlphaIfNeeded:self.viewControllers.firstObject.zq_navBarAlpha];
    return [self zq_popToRootViewControllerAnimated:animated];
}


/**
     将info.plist文 件的 View controller-based status bar appearance 设置为 NO禁用掉
     全局的状态栏颜色StatusBar 一定要要UINavigationController 中重写此方法
     否则子控制器viewcontroll（局部）中实现的改变状态栏的颜色将会无效 这里采
     用 methodswizzing 调换方法 （另外继承UINavigationController 重写也可以实现）
 **/
- (UIViewController *)zq_childViewControllerForStatusBarStyle{
    return self.topViewController;
}

#pragma mark - 自定义全屏左滑手势返回和代理
- (_FDFullscreenPopGestureRecognizerDelegate *)zq_popGestureRecognizerDelegate
{
    _FDFullscreenPopGestureRecognizerDelegate *delegate = objc_getAssociatedObject(self, _cmd);
    
    if (!delegate) {
        delegate = [[_FDFullscreenPopGestureRecognizerDelegate alloc] init];
        delegate.navigationController = self;
        
        objc_setAssociatedObject(self, _cmd, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return delegate;
}

- (UIPanGestureRecognizer *)zq_fullscreenPopGestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = objc_getAssociatedObject(self, _cmd);
    
    if (!panGestureRecognizer) {
        panGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
        panGestureRecognizer.maximumNumberOfTouches = 1;
        objc_setAssociatedObject(self, _cmd, panGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return panGestureRecognizer;
}

///可以设置透明度的导航栏背景View
- (UIView *)zq_barBackgroundView {
    UIView *barBackgroundView  = objc_getAssociatedObject(self, _cmd);
    if (barBackgroundView == nil) {
        UINavigationBar *navigationBar = self.navigationBar;
        if (!IS_IOS10_Later) {
            id _backgroundView = [navigationBar valueForKey:@"_backgroundView"];
            barBackgroundView = _backgroundView;
        }else {
            id _backgroundView = [navigationBar valueForKey:@"_barBackgroundView"];
            id backgroundEffectView = [_backgroundView valueForKey:@"_backgroundEffectView"];
            barBackgroundView = (UIView *)backgroundEffectView;
        }
    }
    return barBackgroundView;
}

///导航栏背景View的下划线
- (UIView *)zq_shadowView {
    UIView *shadowView = objc_getAssociatedObject(self, _cmd);
    if (shadowView == nil) {
        if (!IS_IOS10_Later) {
            shadowView = [self.zq_barBackgroundView valueForKey:@"_shadowView"];
        }else {
            id _backgroundView = [self.navigationBar valueForKey:@"_barBackgroundView"];
            shadowView = [_backgroundView valueForKey:@"_shadowView"];
        }
    }
    return shadowView;
}

// 导航栏背景透明度设置
-(void) zq_setNavigationBackgroundAlphaIfNeeded:(CGFloat) alpha{
    self.zq_shadowView.alpha = alpha;
    UIView *barBackgroundView =self.navigationBar.subviews[0];// _UIBarBackground
    if (self.navigationBar.isTranslucent) {
        self.zq_barBackgroundView.alpha =alpha;
    }
    barBackgroundView.alpha =alpha;
    
    
//    UIView *barBackGroundView =  [self.navigationBar valueForKey:@"_barBackgroundView"];
//    UIView * shadowView = [barBackGroundView valueForKey:@"_shadowView"];
//    if (shadowView) {//导航栏下面的下划线
//        shadowView.alpha =alpha;
//    }
//    if (self.navigationBar.isTranslucent) {
//        if (IS_IOS10_Later) {
//            
//            UIView * backgroundEffectView =[barBackGroundView valueForKey:@"_backgroundEffectView"];
//            if (backgroundEffectView) {
//                backgroundEffectView.alpha =alpha;
//                return;
//            }
//        }else{
//            UIView *adaptiveBackdrop =[barBackGroundView valueForKey:@"_adaptiveBackdrop"];
//            if (adaptiveBackdrop) {
//                UIView * backdropEffectView =[adaptiveBackdrop valueForKey:@"_backdropEffectView"];
//                if (backdropEffectView) {
//                    backdropEffectView.alpha =alpha;
//                    return;
//                }
//            }
//            
//        }
//    }
//    barBackGroundView.alpha =alpha;
//    
    
    
    
    
}

//计算 pop 动画的完成的时间
- (CGFloat)transitonTimeWithOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController  *)fromViewController toViewController:(UIViewController *)toViewController {
    CGFloat time = 0.25;
    if (self.delegate) {
        UIViewController *fromViewcontroller = self.topViewController;
        if ([self.delegate respondsToSelector:@selector(navigationController:animationControllerForOperation:fromViewController:toViewController:)]) {
            id<UIViewControllerAnimatedTransitioning> transition = [self.delegate navigationController:self animationControllerForOperation:operation fromViewController:fromViewcontroller toViewController:toViewController];
            time = [transition transitionDuration:nil];
        }
    }
    return time;
}

//手势状态
- (void)zq_panGesture:(UIPanGestureRecognizer *)pan {
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.isPanGesturePop = YES;
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            self.isPanGesturePop = NO;
            break;
        default:
            break;
    }
    
}


#pragma mark - set/get
- (BOOL)isPanGesturePop {
    id isPanGesturePop = objc_getAssociatedObject(self, _cmd);
    if (!isPanGesturePop) {
        return NO;
    }
    return [isPanGesturePop boolValue];
}
- (void)setIsPanGesturePop:(BOOL)isPanGesturePop {
    objc_setAssociatedObject(self,@selector(isPanGesturePop),@(isPanGesturePop),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}



#pragma mark - UINavigationBar Delegate
-(BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item{
    
    UIViewController *topVC = self.topViewController;
    if (topVC) {
        id<UIViewControllerTransitionCoordinator> coor = topVC.transitionCoordinator;
        if (coor && coor.initiallyInteractive) {
            if (IS_IOS10_Later) {
                [coor notifyWhenInteractionChangesUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> context){
                    [self dealInteractionChanges:context];
                }];
            }else{
                [coor notifyWhenInteractionEndsUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                     [self dealInteractionChanges:context];
                }];
            }
        }
         return  YES;
    }
    NSInteger itemCount = self.navigationBar.items== nil? 0 : self.navigationBar.items.count ;
    int n = self.viewControllers.count >= itemCount ? 2:1;
    UIViewController* popToVC = self.viewControllers[self.viewControllers.count - n];
    [self popToViewController:popToVC animated:YES];
    return  YES;
}

-(BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPushItem:(UINavigationItem *)item{
    [self zq_setNavigationBackgroundAlphaIfNeeded:self.topViewController.zq_navBarAlpha];
    return YES;
}

- (void)dealInteractionChanges:(id<UIViewControllerTransitionCoordinatorContext>)context {
    
    if ([context isCancelled]) {// 自动取消了返回手势
        NSTimeInterval cancelDuration = [context transitionDuration] * (double)[context percentComplete];
        [UIView animateWithDuration:cancelDuration animations:^{
            
            CGFloat nowAlpha = [context viewControllerForKey:UITransitionContextFromViewControllerKey].zq_navBarAlpha ;
            [self zq_setNavigationBackgroundAlphaIfNeeded:nowAlpha];
        }];
    } else {// 自动完成了返回手势
        NSTimeInterval finishDuration = [context transitionDuration] * (double)(1 - [context percentComplete]);
        [UIView animateWithDuration:finishDuration animations:^{
            CGFloat nowAlpha = [context viewControllerForKey:
                                UITransitionContextToViewControllerKey].zq_navBarAlpha;
            [self zq_setNavigationBackgroundAlphaIfNeeded:nowAlpha];
        }];
    }
}

@end







@implementation UIViewController (ZQSilkyBack)

#pragma mark - 新增属性的get/set

//是否允许左滑反回手势
- (BOOL)zq_interactivePopDisabled{
    NSNumber * popDisable =objc_getAssociatedObject(self, _cmd);
    if (!popDisable) {
        return NO; // default value  默认开始左滑返回
    }
    return popDisable. boolValue;
}

- (void)setZq_interactivePopDisabled:(BOOL)disabled{
    objc_setAssociatedObject(self, @selector(zq_interactivePopDisabled), @(disabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


//左滑返回手势边缘范围
- (CGFloat)zq_popEdgeRegionSize{
    id edgeRegionSize =objc_getAssociatedObject(self, _cmd);
    if (!edgeRegionSize) {
        objc_setAssociatedObject(self, _cmd, @([UIScreen mainScreen].bounds.size.width -100), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return [UIScreen mainScreen].bounds.size.width -100 ; //默认为屏幕宽度 -100
    }
#if CGFLOAT_IS_DOUBLE
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
#else
    return [objc_getAssociatedObject(self, _cmd) floatValue];
#endif
}

- (void)setZq_popEdgeRegionSize:(CGFloat)distance
{
    SEL key = @selector(zq_popEdgeRegionSize);
    objc_setAssociatedObject(self, key, @(MAX(0, distance)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


//导航栏透明度
- (CGFloat)zq_navBarAlpha{
    id edgeRegionSize =objc_getAssociatedObject(self, _cmd);
    if (!edgeRegionSize) {
        return  1.0f; //默认值
    }
#if CGFLOAT_IS_DOUBLE
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
#else
    return [objc_getAssociatedObject(self, _cmd) floatValue];
#endif
}

- (void)setZq_navBarAlpha:(CGFloat)alpha{
    objc_setAssociatedObject(self, @selector(zq_navBarAlpha), @(MAX(MIN(alpha, 1), 0)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    //设置导航栏的透明度
    [self.navigationController zq_setNavigationBackgroundAlphaIfNeeded:alpha];
}



/**
    设置状态栏背景颜色
    将info.plist文 件的 View controller-based status bar appearance 设置为 NO禁用掉
    全局的状态栏颜色StatusBar 一定要要UINavigationController 中重写此方法
    否则子控制器viewcontroll（局部）中实现的改变状态栏的颜色将会无效 这里采
    用 methodswizzing 调换方法 （另外继承UINavigationController 重写也可以实现）
    @param color 设置颜色
 **/
- (void)setStatusBarBackgroundColor:(UIColor *)color {
    
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    
    if ([statusBar respondsToSelector:@selector(setBackgroundColor:)]) {
        
        statusBar.backgroundColor = color;
    }
}

@end



