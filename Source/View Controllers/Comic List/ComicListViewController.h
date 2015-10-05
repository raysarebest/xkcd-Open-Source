//
//  ComicListViewController.h
//  xkcd Open Source
//
//  Created by Mike on 5/14/15.
//  Copyright (c) 2015 Mike Amaral. All rights reserved.
//

@import UIKit;
#import <Realm.h>
#import "ComicListFlowLayout.h"
#import "ComicViewController.h"

@interface ComicListViewController : UICollectionViewController <ComicListFlowLayoutDelegate, ComicViewControllerDelegate, UISearchBarDelegate>

@property (nonatomic, strong) RLMResults *comics;

@property (nonatomic, strong) UIBarButtonItem *searchButton;
@property (nonatomic, strong) UIBarButtonItem *filterFavoritesButton;

@property (nonatomic, strong) UIButton *randomComicButton;

@property (nonatomic) BOOL searching;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *noResultsLabel;

@property (nonatomic) BOOL filteringFavorites;

@end
