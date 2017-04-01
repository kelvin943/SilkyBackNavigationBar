//
//  ViewController.m
//  TestNagationBar
//
//  Created by 张泉 on 2017/4/1.
//  Copyright © 2017年 张泉. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()


@property (nonatomic,weak) IBOutlet UIButton * popBtn;
@property (nonatomic,weak) IBOutlet UIButton * pushBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title =@"主页";
    self.popBtn.layer.borderColor  =
    self.pushBtn.layer.borderColor =[UIColor redColor].CGColor;
    
}


-(void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17.0],NSForegroundColorAttributeName:[UIColor redColor]}];
    
}




@end
