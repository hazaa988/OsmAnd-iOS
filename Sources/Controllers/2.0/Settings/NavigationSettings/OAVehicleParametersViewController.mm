//
//  OAVehicleParametersViewController.mm
//  OsmAnd Maps
//
//  Created by Anna Bibyk on 27.06.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OAVehicleParametersViewController.h"
#import "OAAppSettings.h"
#import "OAApplicationMode.h"
#import "OAIconTitleValueCell.h"
#import "OAIconTextTableViewCell.h"
#import "OASettingsTitleTableViewCell.h"
#import "OANavigationTypeViewController.h"
#import "OARouteParametersViewController.h"
#import "OAVoicePromptsViewController.h"
#import "OAScreenAlertsViewController.h"
#import "OASettingsModalPresentationViewController.h"
#import "OAVehicleParametersSettingsViewController.h"
#import "OADefaultSpeedViewController.h"
#import "OARouteSettingsBaseViewController.h"

#import "Localization.h"
#import "OAColors.h"

#define kCellTypeIconTitleValue @"OAIconTitleValueCell"
#define kCellTypeIconText @"OAIconTextCell"

@interface OAVehicleParametersViewController () <UITableViewDelegate, UITableViewDataSource, OAVehicleParametersSettingDelegate>

@end

@implementation OAVehicleParametersViewController
{
    NSArray<NSArray *> *_data;
    OAAppSettings *_settings;
    vector<RoutingParameter> _otherParameters;
}

- (instancetype) initWithAppMode:(OAApplicationMode *)appMode
{
    self = [super initWithAppMode:appMode];
    if (self)
    {
        _settings = [OAAppSettings sharedManager];
    }
    return self;
}

-(void) applyLocalization
{
    self.titleLabel.text = OALocalizedString(@"vehicle_parameters");
    self.subtitleLabel.text = self.appMode.name;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorInset = UIEdgeInsetsMake(0., 16., 0., 0.);
    [self setupView];
}

- (void) setupView
{
    NSMutableArray *tableData = [NSMutableArray array];
    NSMutableArray *parametersArr = [NSMutableArray array];
    NSMutableArray *defaultSpeedArr = [NSMutableArray array];
    auto router = [self.class getRouter:self.appMode];
    _otherParameters.clear();
    if (router && self.appMode != OAApplicationMode.PUBLIC_TRANSPORT && self.appMode != OAApplicationMode.SKI && self.appMode.parent != OAApplicationMode.PUBLIC_TRANSPORT && self.appMode.parent != OAApplicationMode.SKI)
    {
        auto& parameters = router->getParametersList();
        for (const auto& p : parameters)
        {
            NSString *param = [NSString stringWithUTF8String:p.id.c_str()];
            if (![param hasPrefix:@"avoid_"] && ![param hasPrefix:@"prefer_"] &&![param isEqualToString:@"short_way"] && "driving_style" != p.group)
                _otherParameters.push_back(p);
        }
        for (const auto& p : _otherParameters)
        {
            NSString *paramId = [NSString stringWithUTF8String:p.id.c_str()];
            NSString *title = [self getRoutingStringPropertyName:paramId defaultName:[NSString stringWithUTF8String:p.name.c_str()]];
            if (!(p.type == RoutingParameterType::BOOLEAN))
            {
                OAProfileString *stringParam = [_settings getCustomRoutingProperty:paramId defaultValue: @"0"];
                NSString *value = [stringParam get:self.appMode];
                NSMutableArray *possibleValues = [NSMutableArray array];
                NSMutableArray *possibleValuesDescr = [NSMutableArray array];
                int index = -1;
                for (int i = 0; i < p.possibleValues.size(); i++)
                {
                    NSNumberFormatter *formatter = [[NSNumberFormatter alloc]init];
                    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
                    [formatter setMaximumFractionDigits:1];
                    [formatter setMinimumFractionDigits:0];
                    
                    [possibleValues addObject:[formatter numberFromString:[NSString stringWithFormat:@"%.1f", p.possibleValues[i]]]];
                    [possibleValuesDescr addObject:[NSString stringWithUTF8String:p.possibleValueDescriptions[i].c_str()]];
                    if ([value isEqualToString:[possibleValues[i] stringValue]])
                        index = i;
                }
                if (index == 0)
                    value = OALocalizedString(@"sett_no_ext_input");
                else if (index != -1)
                    value = [NSString stringWithUTF8String:p.possibleValueDescriptions[index].c_str()];
                else
                    value = [NSString stringWithFormat:@"%@%@", value, [paramId isEqualToString:@"weight"] ? @"t" : @"m"];
                [parametersArr addObject:
                 @{
                     @"name" : paramId,
                     @"title" : title,
                     @"value" : value,
                     @"selectedItem" : [NSNumber numberWithInt:index],
                     @"icon" : [self getParameterIcon:paramId],
                     @"possibleValues" : possibleValues,
                     @"possibleValuesDescr" : possibleValuesDescr,
                     @"setting" : stringParam,
                     @"type" : kCellTypeIconTitleValue }
                 ];
            }
        }
    }
    // TODO: add default speed functionality when it's ready
//    if (self.appMode != OAApplicationMode.PUBLIC_TRANSPORT && self.appMode.parent != OAApplicationMode.PUBLIC_TRANSPORT)
//    {
//        if (self.appMode != OAApplicationMode.AIRCRAFT && self.appMode.parent != OAApplicationMode.AIRCRAFT)
//            [defaultSpeedArr addObject:@{
//                @"type" : kCellTypeIconText,
//                @"title" : OALocalizedString(@"default_speed"),
//                @"minSpeed" : [NSNumber numberWithDouble:router->getMinSpeed()],
//                @"defaultSpeed" : [NSNumber numberWithDouble:router->getDefaultSpeed()],
//                @"maxSpeed" : [NSNumber numberWithDouble:router->getMaxSpeed()],
//                @"icon" : @"ic_action_speed",
//                @"name" : @"defaultSpeed",
//            }];
//        else
//            [defaultSpeedArr addObject:@{
//                @"type" : kCellTypeIconText,
//                @"title" : OALocalizedString(@"default_speed"),
//                @"defaultSpeedOnly" : @YES,
//                @"icon" : @"ic_action_speed",
//                @"name" : @"defaultSpeed",
//            }];
//    }
    if (parametersArr.count > 0)
        [tableData addObject:parametersArr];
    if (defaultSpeedArr.count > 0)
        [tableData addObject:defaultSpeedArr];
    _data = [NSArray arrayWithArray:tableData];
}

+ (std::shared_ptr<GeneralRouter>) getRouter:(OAApplicationMode *)am
{
    OsmAndAppInstance app = [OsmAndApp instance];
    auto router = app.defaultRoutingConfig->getRouter([am.getRoutingProfile UTF8String]);
    if (!router && am.parent)
        router = app.defaultRoutingConfig->getRouter([am.parent.getRoutingProfile UTF8String]);
    return router;
}

- (NSString *) getRoutingStringPropertyName:(NSString *)propertyName defaultName:(NSString *)defaultName
{
    NSString *key = [NSString stringWithFormat:@"routing_attr_%@_name", propertyName];
    NSString *res = OALocalizedString(key);
    if ([res isEqualToString:key])
        res = defaultName;
    return res;
}

- (NSString *) getParameterIcon:(NSString *)parameterName
{
    if ([parameterName isEqualToString:@"weight"])
        return @"ic_custom_weight_limit";
    else if ([parameterName isEqualToString:@"height"])
        return @"ic_custom_height_limit";
    else if ([parameterName isEqualToString:@"length"])
        return @"ic_custom_length_limit";
    else if ([parameterName isEqualToString:@"width"])
        return @"ic_custom_width_limit";
    return @"";
}

#pragma mark - TableView

- (nonnull UITableViewCell *) tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *cellType = item[@"type"];
    if ([cellType isEqualToString:kCellTypeIconTitleValue])
    {
        static NSString* const identifierCell = kCellTypeIconTitleValue;
        OAIconTitleValueCell* cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:identifierCell owner:self options:nil];
            cell = (OAIconTitleValueCell *)[nib objectAtIndex:0];
            cell.separatorInset = UIEdgeInsetsMake(0., 62., 0., 0.);
            cell.iconView.image = [[UIImage imageNamed:@"ic_custom_arrow_right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.iconView.tintColor = UIColorFromRGB(color_tint_gray);
        }
        if (cell)
        {
            cell.textView.text = item[@"title"];
            cell.descriptionView.text = item[@"value"];
            cell.leftImageView.image = [[UIImage imageNamed:item[@"icon"]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.leftImageView.tintColor = [item[@"value"] isEqualToString:@"-"] ? UIColorFromRGB(color_icon_inactive) : UIColorFromRGB(color_osmand_orange);
        }
        return cell;
    }
    else if ([cellType isEqualToString:kCellTypeIconText])
    {
        static NSString* const identifierCell = kCellTypeIconText;
        OAIconTextTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:identifierCell owner:self options:nil];
            cell = (OAIconTextTableViewCell *)[nib objectAtIndex:0];
            cell.separatorInset = UIEdgeInsetsMake(0., 62., 0., 0.);
            cell.arrowIconView.image = [[UIImage imageNamed:@"ic_custom_arrow_right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.arrowIconView.tintColor = UIColorFromRGB(color_tint_gray);
        }
        if (cell)
        {
            cell.textView.text = item[@"title"];
            cell.iconView.image = [[UIImage imageNamed:item[@"icon"]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.iconView.tintColor = UIColorFromRGB(color_icon_inactive);
        }
        return cell;
    }
    return nil;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *itemName = item[@"name"];
    OASettingsModalPresentationViewController* settingsViewController = nil;
    if ([itemName isEqualToString:@"defaultSpeed"])
        settingsViewController = [[OADefaultSpeedViewController alloc] initWithApplicationMode:self.appMode speedParameters:item];
    else
        settingsViewController = [[OAVehicleParametersSettingsViewController alloc] initWithApplicationMode:self.appMode vehicleParameter:item];
    
    settingsViewController.delegate = self;
    [self presentViewController:settingsViewController animated:YES completion:nil];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSInteger) tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _data[section].count;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section == 0 ? @"" : OALocalizedString(@"help_other_header");
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return section == 0 ? OALocalizedString(@"touting_specified_vehicle_parameters_descr") : OALocalizedString(@"default_speed_descr");
}

#pragma mark - OAVehicleParametersSettingDelegate

- (void) onSettingsChanged
{
    [self setupView];
    [self.tableView reloadData];
}

@end