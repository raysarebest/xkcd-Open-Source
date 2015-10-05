//
//  DataManager.m
//  xkcd Open Source
//
//  Created by Mike on 5/14/15.
//  Copyright (c) 2015 Mike Amaral. All rights reserved.
//

#import "DataManager.h"
#import "RequestManager.h"
#import <GTTracker.h>

static NSInteger const kCurrentSchemaVersion = 2;
static NSString * const kLatestComicDownloadedKey = @"LatestComicDownloaded";

@implementation DataManager {
    NSUserDefaults *_defaults;
}


#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });

    return _sharedObject;
}


#pragma mark - Initialization

- (instancetype)init {
    self = [super init];

    _defaults = [NSUserDefaults standardUserDefaults];

    [self initializeRealm];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppEnteringForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppEnteringForeground) name:UIApplicationDidFinishLaunchingNotification object:nil];

    return self;
}

- (void)initializeRealm {
    RLMRealmConfiguration *defaultConfig = [RLMRealmConfiguration defaultConfiguration];
    defaultConfig.schemaVersion = kCurrentSchemaVersion;
    [RLMRealmConfiguration setDefaultConfiguration:defaultConfig];
    self.realm = [RLMRealm defaultRealm];
}


#pragma mark - Saving comics

- (void)saveComics:(NSArray *)comics {
    [self.realm beginWriteTransaction];
    [self.realm addOrUpdateObjectsFromArray:comics];
    [self.realm commitWriteTransaction];
}

- (void)markComicViewed:(Comic *)comic {
    [self.realm beginWriteTransaction];
    comic.viewed = YES;
    [self.realm commitWriteTransaction];
}

- (void)markComic:(Comic *)comic favorited:(BOOL)favorited {
    [self.realm beginWriteTransaction];
    comic.favorite = favorited;
    [self.realm commitWriteTransaction];
}


#pragma mark - Latest comic info

- (NSInteger)latestComicDownloaded {
    return [_defaults integerForKey:kLatestComicDownloadedKey];
}

- (void)setLatestComicDownloaded:(NSInteger)latest {
    [_defaults setInteger:latest forKey:kLatestComicDownloadedKey];
}


#pragma mark - App life cycle handling

- (void)handleAppEnteringForeground {
    // Download the latest comics.
    [self downloadLatestComicsWithCompletionHandler:^(NSError *error, NSInteger numberOfNewComics) {

        // If there was an error and we have none saved, there was an issue loading the first batch of
        // comics and we should probably retry after a short delay.
        if (error && [self allSavedComics].count == 0) {
            [[GTTracker sharedInstance] sendAnalyticsEventWithCategory:@"Foreground Fetch Error" action:error.localizedDescription];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self handleAppEnteringForeground];
            });
        }

        // Otherwise if we have new comics, notify the app that there are more available.
        else if (numberOfNewComics > 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NewComicsAvailableNotification object:nil];
        }
    }];
}


#pragma mark - Fetching comics

- (RLMResults *)allSavedComics {
    return [[Comic allObjects] sortedResultsUsingProperty:@"num" ascending:NO];
}

- (RLMResults *)comicsMatchingSearchString:(NSString *)searchString {
    return [[Comic objectsWithPredicate:[NSPredicate predicateWithFormat:@"comicID == %@ OR title CONTAINS[c] %@ OR alt CONTAINS %@", searchString, searchString, searchString]] sortedResultsUsingProperty:@"num" ascending:NO];
}

- (RLMResults *)allFavorites {
    return [[Comic objectsWithPredicate:[NSPredicate predicateWithFormat:@"favorite == YES"]] sortedResultsUsingProperty:@"num" ascending:NO];
}

- (void)downloadLatestComicsWithCompletionHandler:(void (^)(NSError *error, NSInteger numberOfNewComics))handler {
    // Calculate the starting index.
    NSInteger since = [self latestComicDownloaded];

    // Pass that to our request manager to fetch it.
    [[RequestManager sharedInstance] downloadComicsSince:since completionHandler:^(NSError *error, NSArray *comicDicts) {
        // Error handling
        if (error) {
            handler(error, 0);
            return;
        }

        // Convert the dictionaries to our comic models, also keeping track of the newest
        // latest comic.
        NSMutableArray *comics = [NSMutableArray arrayWithCapacity:comicDicts.count];
        NSInteger latestDownloaded = since;

        for (NSDictionary *comicDict in comicDicts) {
            Comic *comic = [Comic comicFromDictionary:comicDict];
            [comics addObject:comic];

            if (comic.num > latestDownloaded) {
                latestDownloaded = comic.num;
            }
        }

        // Save them in our realm.
        [self saveComics:comics];

        // Update our latest comic.
        [self setLatestComicDownloaded:latestDownloaded];

        handler(nil, comics.count);
    }];
}


#pragma mark - Background fetching

- (void)performBackgroundFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Download all of the latest comics.
    [self downloadLatestComicsWithCompletionHandler:^(NSError *error, NSInteger numberOfNewComics) {
        BOOL newData = numberOfNewComics > 0;

        if (error) {
            completionHandler(UIBackgroundFetchResultFailed);
        }

        else if (newData) {
            completionHandler(UIBackgroundFetchResultNewData);

            [[NSNotificationCenter defaultCenter] postNotificationName:NewComicsAvailableNotification object:nil];
        }

        else {
            completionHandler(UIBackgroundFetchResultNoData);
        }
    }];
}


#pragma mark - Converting token data

- (NSString *)tokenStringFromData:(NSData *)data {
    if (!data) {
        return @"";
    }

    NSString *token = [NSString stringWithFormat:@"%@", data];
    token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
    token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    return token;
}


#pragma mark - Randomization

- (NSInteger)randomNumberBetweenMin:(NSUInteger)min andMax:(NSUInteger)max {
    return (min + arc4random_uniform((u_int32_t)max - (u_int32_t)min + 1));
}

- (Comic *)randomComic {
    RLMResults *allComics = [self allSavedComics];
    NSInteger randomIndex = [self randomNumberBetweenMin:0 andMax:allComics.count - 1];
    return allComics[randomIndex];
}

@end
