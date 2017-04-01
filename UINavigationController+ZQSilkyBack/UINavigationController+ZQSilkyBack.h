//
//  UINavigationController+ZQSilkyBack.h
//  testNavBar
//
//  Created by 张泉 on 2017/3/23.
//  Copyright © 2017年 张泉. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UINavigationController (ZQSilkyBack) <UINavigationBarDelegate>

/// The gesture recognizer that actually handles interactive pop.
@property (nonatomic, strong, readonly) UIPanGestureRecognizer *zq_fullscreenPopGestureRecognizer;

///  is pan gesture to pop 
@property (nonatomic, assign) BOOL isPanGesturePop;

@end

@interface UIViewController (ZQSilkyBack)

/// 左滑返回手势是否禁用
@property (nonatomic, assign) BOOL zq_interactivePopDisabled;

/// 左滑返回手势的触发范围（系统的默认边缘值 13）
@property (nonatomic, assign) CGFloat zq_popEdgeRegionSize;

/// 导航栏背景颜色的透明度(0,1)
@property (nonatomic, assign) CGFloat zq_navBarAlpha;

- (void)setStatusBarBackgroundColor:(UIColor *)color;



@end
