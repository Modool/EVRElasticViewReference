//
//  ViewController.m
//  Demo
//
//  Created by Jave on 2017/11/8.
//  Copyright © 2017年 markejave. All rights reserved.
//

#import "ViewController.h"
#import "TestTableViewCell.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.tableView.rowHeight = 60;
    
    [[self tableView] registerClass:[TestTableViewCell class] forCellReuseIdentifier:NSStringFromClass([TestTableViewCell class])];
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    TestTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([TestTableViewCell class])];
    
    cell.textLabel.text = [NSString stringWithFormat:@"测试%ld", (long)[indexPath row]];
    cell.contentLabel.text = [NSString stringWithFormat:@"%ld", (long)[indexPath row]];
    
    return cell;
}

@end
