//
//  ViewController2.m
//  TestNagationBar
//
//  Created by 张泉 on 2017/4/1.
//  Copyright © 2017年 张泉. All rights reserved.
//

#import "ViewController2.h"
#import "ViewController.h"
#import "UINavigationController+ZQSilkyBack.h"

@interface ViewController2 () <UIScrollViewDelegate>
@property (nonatomic,weak) IBOutlet UITableView * tableView;

@end

@implementation ViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title =@"透明页面";
    
    
    UIImageView *headView =  [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 350)];
    headView.image = [UIImage imageNamed:@"lanch"];
    self.tableView.tableHeaderView =headView;

    self.zq_navBarAlpha = 0 ;//设置透明页
    // Do any additional setup after loading the view.
}

-(void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //    [self.navigationController setNavigationBarHidden:YES animated:animated];
    self.navigationController.navigationBar.tintColor = [UIColor magentaColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17.0],NSForegroundColorAttributeName:[UIColor magentaColor]}];
    
}
-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //    [self.navigationController setNavigationBarHidden:NO animated:animated];
}


#pragma mark - UITableViewDelegate and UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectio{
    return 20;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"第%ld行",(long)indexPath.row];
    return cell;
}


#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    
    CGFloat offsetY = scrollView.contentOffset.y + _tableView.contentInset.top;//注意
    NSLog(@"offsetY :%lf", offsetY);
    if (offsetY <=64   ) {
        self.zq_navBarAlpha =0;
    }
    else if (offsetY >64 && offsetY <=  350) {
        //设置透明度
        self.zq_navBarAlpha =((offsetY-64)/(350-64)) >= 1 ? 1 : (offsetY-64)/(350-64);
    }
    else if (offsetY > 350) {//超过头视图之后导航安透明的为1
        self.zq_navBarAlpha = 1;
    }

    
}



//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    UIStoryboard * mainSB = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
//    ViewController * vc = [mainSB instantiateViewControllerWithIdentifier:@"ViewController"];
//    [self.navigationController pushViewController:vc animated:YES];
//}



@end
