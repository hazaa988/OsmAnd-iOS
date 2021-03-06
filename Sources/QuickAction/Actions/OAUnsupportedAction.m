//
//  OAUnsupportedAction.m
//  OsmAnd
//
//  Created by nnngrach on 18.12.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OAUnsupportedAction.h"
#import "OAQuickActionType.h"
#import "OARootViewController.h"

#define kName @"name"
#define kActionType @"actionType"
#define kParams @"params"

static OAQuickActionType *TYPE;

@implementation OAUnsupportedAction
{
    NSString *_actionTypeId;
}

- (instancetype) initWithActionTypeId:(NSString *)actionTypeId;
{
    self = [super initWithActionType:self.class.TYPE];
    if (self)
        _actionTypeId = actionTypeId;

    return self;
}

- (NSString *)getActionTypeId
{
    return _actionTypeId;
}

- (NSString *) getIconResName
{
    return @"ic_custom_alert";
}

- (NSString *) getDefaultName
{
    return [NSString stringWithFormat:OALocalizedString(@"unsupported_action_title"), _actionTypeId];
}

- (NSString *) getActionText
{
    return OALocalizedString(@"unsupported_action_descr");
}

- (NSString *) getActionStateName
{
    NSString *name = self.getName;
    return name.length > 0 ? name : OALocalizedString(@"unsupported_action");
}

- (void) execute
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:OALocalizedString(@"unsupported_action_descr") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_ok") style:UIAlertActionStyleDefault handler:nil]];
    [OARootViewController.instance presentViewController:alert animated:YES completion:nil];
}

+ (OAQuickActionType *) TYPE
{
    if (!TYPE)
        TYPE = [[OAQuickActionType alloc] initWithIdentifier:-1 stringId:@"unsupported.action" class:self.class name:OALocalizedString(@"unsupported_action") category:UNSUPPORTED iconName:@"ic_custom_alert" secondaryIconName:nil editable:NO];
       
    return TYPE;
}

@end
