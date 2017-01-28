//
//  OAQuickSearchHelper.m
//  OsmAnd
//
//  Created by Alexey Kulish on 27/01/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OAQuickSearchHelper.h"
#import "OsmAndApp.h"
#import "OAAppSettings.h"
#import "OASearchUICore.h"
#import "OASearchPhrase.h"
#import "OASearchResultMatcher.h"
#import "OAHistoryItem.h"
#import "OAHistoryHelper.h"
#import "OAPOIFiltersHelper.h"
#import "OAPOIUIFilter.h"
#import "OACustomSearchPoiFilter.h"

#include <OsmAndCore/IFavoriteLocation.h>
#include <OsmAndCore/GeoInfoDocument.h>

static const int SEARCH_FAVORITE_API_PRIORITY = 50;
static const int SEARCH_FAVORITE_API_CATEGORY_PRIORITY = 50;
static const int SEARCH_FAVORITE_OBJECT_PRIORITY = 50;
static const int SEARCH_FAVORITE_CATEGORY_PRIORITY = 51;
static const int SEARCH_WPT_API_PRIORITY = 50;
static const int SEARCH_WPT_OBJECT_PRIORITY = 52;
static const int SEARCH_HISTORY_API_PRIORITY = 50;
static const int SEARCH_HISTORY_OBJECT_PRIORITY = 53;


@implementation OASearchFavoritesAPI

-(BOOL)isSearchMoreAvailable:(OASearchPhrase *)phrase
{
    return NO;
}

-(BOOL)search:(OASearchPhrase *)phrase resultMatcher:(OASearchResultMatcher *)resultMatcher
{
    OsmAndAppInstance app = [OsmAndApp instance];
    for (const auto& point : app.favoritesCollection->getFavoriteLocations())
    {
        OASearchResult *sr = [[OASearchResult alloc] initWithPhrase:phrase];
        sr.localeName = point->getTitle().toNSString();
        sr.favorite = point;
        sr.priority = SEARCH_FAVORITE_OBJECT_PRIORITY;
        sr.objectType = FAVORITE;
        sr.location = [[CLLocation alloc] initWithLatitude:point->getLatLon().latitude longitude:point->getLatLon().longitude];
        sr.preferredZoom = 17;
        if ([phrase getUnknownSearchWordLength] <= 1 && [phrase isNoSelectedType])
            [resultMatcher publish:sr];
        else if ([[phrase getNameStringMatcher] matches:sr.localeName])
            [resultMatcher publish:sr];
    }
    return YES;
}

-(int)getSearchPriority:(OASearchPhrase *)p
{
    if (![p isNoSelectedType] || ![p isUnknownSearchWordPresent])
        return -1;
    
    return SEARCH_FAVORITE_API_PRIORITY;
}

@end


@implementation OASearchFavoritesCategoryAPI

-(BOOL)isSearchMoreAvailable:(OASearchPhrase *)phrase
{
    return NO;
}

-(BOOL)search:(OASearchPhrase *)phrase resultMatcher:(OASearchResultMatcher *)resultMatcher
{
    OsmAndAppInstance app = [OsmAndApp instance];
    for (const auto& point : app.favoritesCollection->getFavoriteLocations())
    {
        OASearchResult *sr = [[OASearchResult alloc] initWithPhrase:phrase];
        sr.localeName = point->getTitle().toNSString();
        sr.favorite = point;
        sr.priority = SEARCH_FAVORITE_CATEGORY_PRIORITY;
        sr.objectType = FAVORITE;
        sr.location = [[CLLocation alloc] initWithLatitude:point->getLatLon().latitude longitude:point->getLatLon().longitude];
        sr.preferredZoom = 17;
        if (!point->getGroup().isNull() && [[phrase getNameStringMatcher] matches:point->getGroup().toNSString()])
            [resultMatcher publish:sr];
    }
    return YES;
}

-(int)getSearchPriority:(OASearchPhrase *)p
{
    if (![p isNoSelectedType] || ![p isUnknownSearchWordPresent])
        return -1;
    
    return SEARCH_FAVORITE_API_CATEGORY_PRIORITY;
}

@end


@implementation OASearchWptAPI

-(BOOL)isSearchMoreAvailable:(OASearchPhrase *)phrase
{
    return NO;
}

-(BOOL)search:(OASearchPhrase *)phrase resultMatcher:(OASearchResultMatcher *)resultMatcher
{
    if ([phrase isEmpty])
        return NO;
    
    QList<std::shared_ptr<const OsmAnd::GeoInfoDocument>> list;
    for (const auto& gpx : list)
    {
        for (const auto& point : gpx->locationMarks)
        {
            OASearchResult *sr = [[OASearchResult alloc] initWithPhrase:phrase];
            sr.localeName = point->name.toNSString();
            sr.wpt = point;
            sr.priority = SEARCH_WPT_OBJECT_PRIORITY;
            sr.objectType = WPT;
            sr.location = [[CLLocation alloc] initWithLatitude:point->position.latitude longitude:point->position.longitude];
            //sr.localeRelatedObjectName = app.getRegions().getCountryName(sr.location);
            sr.relatedGpx = gpx;
            sr.preferredZoom = 17;
            if ([phrase getUnknownSearchWordLength] <= 1 && [phrase isNoSelectedType])
                [resultMatcher publish:sr];
            else if ([[phrase getNameStringMatcher] matches:sr.localeName])
                [resultMatcher publish:sr];
        }
    }
    return YES;
}

-(int)getSearchPriority:(OASearchPhrase *)p
{
    if (![p isNoSelectedType])
        return -1;
    
    return SEARCH_WPT_API_PRIORITY;
}

@end


@implementation OASearchHistoryAPI

- (BOOL) isSearchMoreAvailable:(OASearchPhrase *)phrase
{
    return NO;
}

-(BOOL)search:(OASearchPhrase *)phrase resultMatcher:(OASearchResultMatcher *)resultMatcher
{
    OAHistoryHelper *helper = [OAHistoryHelper sharedInstance];
    NSArray *allItems = [helper getPointsHavingTypes:helper.searchTypes limit:0];
    int p = 0;
    for (OAHistoryItem *point in allItems)
    {
        OASearchResult *sr = [[OASearchResult alloc] initWithPhrase:phrase];
        sr.localeName = point.name;
        sr.object = point;
        sr.priority = SEARCH_HISTORY_OBJECT_PRIORITY + (p++);
        sr.objectType = RECENT_OBJ;
        sr.location = [[CLLocation alloc] initWithLatitude:point.latitude longitude:point.longitude];
        sr.preferredZoom = 17;
        if ([phrase getUnknownSearchWordLength] <= 1 && [phrase isNoSelectedType])
            [resultMatcher publish:sr];
        else if ([[phrase getNameStringMatcher] matches:sr.localeName])
            [resultMatcher publish:sr];
    }
    return YES;
}

-(int)getSearchPriority:(OASearchPhrase *)p
{
    if (![p isEmpty])
        return -1;
    
    return SEARCH_HISTORY_API_PRIORITY;
}

@end


@implementation OAQuickSearchHelper
{
    OASearchUICore *_core;
    OASearchResultCollection *_resultCollection;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        NSString *lang = [OAAppSettings sharedManager].settingPrefMapLanguage;
        BOOL transliterate = [OAAppSettings sharedManager].settingMapLanguageTranslit;
        _core = [[OASearchUICore alloc] initWithLang:lang transliterate:transliterate];
    }
    return self;
}

- (OASearchUICore *) getCore
{
    return _core;
}

- (OASearchResultCollection *) getResultCollection
{
    return _resultCollection;
}

- (void) setResultCollection:(OASearchResultCollection *)resultCollection
{
    _resultCollection = resultCollection;
}

- (void) initSearchUICore
{
    [_core initApi];
    
    // Register favorites search api
    [_core registerAPI:[[OASearchFavoritesAPI alloc] init]];

    // Register favorites by category search api
    [_core registerAPI:[[OASearchFavoritesCategoryAPI alloc] init]];
    
    // Register WptPt search api
    [_core registerAPI:[[OASearchWptAPI alloc] init]];
    [_core registerAPI:[[OASearchHistoryAPI alloc] init]];
    
    [self refreshCustomPoiFilters];
    
    OAPOIFiltersHelper *poiFilters = [OAPOIFiltersHelper sharedInstance];
    [_core addCustomSearchPoiFilter:[poiFilters getLocalWikiPOIFilter] priority:1];
    [_core addCustomSearchPoiFilter:[poiFilters getShowAllPOIFilter] priority:1];
}

- (void) refreshCustomPoiFilters
{
    [_core clearCustomSearchPoiFilters];
    OAPOIFiltersHelper *poiFilters = [OAPOIFiltersHelper sharedInstance];
    for (OACustomSearchPoiFilter *udf in [poiFilters getUserDefinedPoiFilters])
        [_core addCustomSearchPoiFilter:udf priority:0];
}

@end
