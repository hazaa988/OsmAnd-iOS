//
//  OAMapSourceAction.m
//  OsmAnd
//
//  Created by Paul on 8/13/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OAMapSourceAction.h"
#import "OAAppSettings.h"
#import "OsmAndApp.h"
#import "OAMapSource.h"
#import "Localization.h"
#import "OAAppData.h"
#import "OAQuickActionSelectionBottomSheetViewController.h"

#define LAYER_OSM_VECTOR @"type_default"
#define KEY_SOURCE @"source"

@implementation OAMapSourceAction

- (instancetype) init
{
    self = [super initWithType:EOAQuickActionTypeMapSource];
    if (self)
    {
        [super commonInit];
    }
    return self;
}

- (void)execute
{
    NSArray<NSArray<NSString *> *> *sources = self.getParams[self.getListKey];
    if (sources.count > 0)
    {
        BOOL showBottomSheetStyles = [self.getParams[KEY_DIALOG] boolValue];
        if (showBottomSheetStyles)
        {
            OAQuickActionSelectionBottomSheetViewController *bottomSheet = [[OAQuickActionSelectionBottomSheetViewController alloc] initWithAction:self type:EOAMapSourceTypeSource];
            [bottomSheet show];
            return;
        }
        
        OsmAndAppInstance app = [OsmAndApp instance];
        OAMapSource *currSource = app.data.lastMapSource;
        NSInteger index = -1;
        for (NSInteger idx = 0; idx < sources.count; idx++)
        {
            if ([sources[idx].firstObject isEqualToString:currSource.variant])
            {
                index = idx;
                break;
            }
        }
        
        NSArray<NSString *> *nextSource = sources[0];
        
        if (index >= 0 && index < sources.count - 1)
            nextSource = sources[index + 1];
        
        [self executeWithParams:nextSource.firstObject];
    }
}

- (void)executeWithParams:(NSString *)params
{
    OsmAndAppInstance app = [OsmAndApp instance];
    if ([params isEqualToString:LAYER_OSM_VECTOR])
    {
        OAMapSource *mapSource = app.data.prevOfflineSource;
        if (!mapSource)
        {
            mapSource = [OAAppData defaults].lastMapSource;
            [app.data setPrevOfflineSource:mapSource];
        }
        app.data.lastMapSource = mapSource;
    }
    else
    {
        OAMapSource *newMapSource = nil;
        for (OAMapSource *mapSource in self.onlineMapSources)
        {
            if ([mapSource.variant isEqualToString:params])
            {
                newMapSource = mapSource;
                break;
            }
        }
        app.data.lastMapSource = newMapSource;
    }
//     indicate change with toast?
}

- (NSString *)getTranslatedItemName:(NSString *)item
{
    if ([item isEqualToString:LAYER_OSM_VECTOR])
        return OALocalizedString(@"offline_vector_maps");
    else
        return item;
    return nil;
}

-(NSString *) getAddBtnText
{
    return OALocalizedString(@"add_map_source");
}

- (NSString *)getDescrHint
{
    return OALocalizedString(@"quick_action_list_descr");
}

- (NSString *)getDescrTitle
{
    return OALocalizedString(@"map_sources");
}

- (NSString *)getListKey
{
    return KEY_SOURCE;
}

- (OrderedDictionary *)getUIModel
{
    MutableOrderedDictionary *data = [[MutableOrderedDictionary alloc] init];
    [data setObject:@[@{
                          @"type" : @"OASwitchTableViewCell",
                          @"key" : KEY_DIALOG,
                          @"title" : OALocalizedString(@"quick_actions_show_dialog"),
                          @"value" : @([self.getParams[KEY_DIALOG] boolValue]),
                          },
                      @{
                          @"footer" : OALocalizedString(@"quick_action_dialog_descr")
                          }] forKey:OALocalizedString(@"quick_action_dialog")];
    
    NSArray<NSArray <NSString *> *> *sources = self.getParams[self.getListKey];
    NSMutableArray *arr = [NSMutableArray new];
    for (NSArray *source in sources)
    {
        [arr addObject:@{
                         @"type" : @"OATitleDescrDraggableCell",
                         @"title" : source.lastObject,
                         @"value" : source.firstObject,
                         @"img" : @"ic_custom_map_style"
                         }];
    }
    [arr addObject:@{
                     @"title" : OALocalizedString(@"add_map_source"),
                     @"type" : @"OAButtonCell",
                     @"target" : @"addMapSource"
                     }];
    [data setObject:[NSArray arrayWithArray:arr] forKey:OALocalizedString(@"map_sources")];
    return data;
}

- (BOOL)fillParams:(NSDictionary *)model
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.getParams];
    NSMutableArray *sources = [NSMutableArray new];
    for (NSArray *arr in model.allValues)
    {
        for (NSDictionary *item in arr)
        {
            if ([item[@"key"] isEqualToString:KEY_DIALOG])
                [params setValue:item[@"value"] forKey:KEY_DIALOG];
            else if ([item[@"type"] isEqualToString:@"OATitleDescrDraggableCell"])
                [sources addObject:@[item[@"value"], item[@"title"]]];
        }
    }
    [params setObject:sources forKey:KEY_SOURCE];
    [self setParams:[NSDictionary dictionaryWithDictionary:params]];
    return sources.count > 0;
}

@end