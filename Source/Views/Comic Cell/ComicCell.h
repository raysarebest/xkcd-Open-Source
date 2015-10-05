//
//  ComicCell.h
//  xkcd Open Source
//
//  Created by Mike on 5/14/15.
//  Copyright (c) 2015 Mike Amaral. All rights reserved.
//

@import UIKit;
#import "Comic.h"

static NSString * const kComicCellReuseIdentifier = @"ComicCell";

@interface ComicCell : UICollectionViewCell

@property (nonatomic, strong) Comic *comic;

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) UILabel *numberLabel;
@property (nonatomic, strong) UIView *highlightedMask;
@property (nonatomic, strong) UIImageView *favoritedIcon;

@end
