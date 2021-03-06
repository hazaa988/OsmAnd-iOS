//
//  OASaveTrackViewController.mm
//  OsmAnd
//
//  Created by Anna Bibyk on 14.01.2021.
//  Copyright © 2021 OsmAnd. All rights reserved.
//

#import "OASaveTrackViewController.h"
#import "OARootViewController.h"
#import "Localization.h"
#import "OAColors.h"
#import "OATextViewResizingCell.h"
#import "OASwitchTableViewCell.h"
#import "OASaveTrackBottomSheetViewController.h"
#import "OAGPXDatabase.h"
#import "OAMapLayers.h"
#import "OAMapRendererView.h"

#define kTextInputCell @"OATextViewResizingCell"
#define kRouteGroupsCell @""
#define kSwitchCell @"OASwitchTableViewCell"

@interface OASaveTrackViewController() <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate>

@end

@implementation OASaveTrackViewController
{
    NSArray<NSArray<NSDictionary *> *> *_data;
    OAAppSettings *_settings;
    
    NSString *_fileName;
    NSString *_sourceFileName;
    BOOL _showSimplifiedButton;
    BOOL _rightButtonEnabled;
    
    BOOL _simplifiedTrack;
    BOOL _showOnMap;
    
    NSString *_inputFieldError;

}

- (instancetype) initWithParams:(NSString *)fileName showOnMap:(BOOL)showOnMap simplifiedTrack:(BOOL)simplifiedTrack
{
    self = [super init];
    if (self)
    {
        _settings = [OAAppSettings sharedManager];
        _fileName = fileName;
        _sourceFileName = fileName;
        _showSimplifiedButton = simplifiedTrack;
        _showOnMap = showOnMap;
        
        _rightButtonEnabled = YES;
        _simplifiedTrack = NO;
        
        [self commonInit];
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.cancelButton.layer.cornerRadius = 9.0;
    self.saveButton.layer.cornerRadius = 9.0;
    
    [self updateBottomButtons];
}

- (void) applyLocalization
{
    [super applyLocalization];
    self.titleLabel.text = OALocalizedString(@"save_new_track");
    [self.cancelButton setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    [self.saveButton setTitle:OALocalizedString(@"shared_string_save") forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void) commonInit
{
    [self generateData];
}

- (void) generateData
{
    NSMutableArray *data = [NSMutableArray new];
    
    [data addObject:@[
        @{
            @"type" : kTextInputCell,
            @"fileName" : _fileName,
            @"header" : OALocalizedString(@"fav_name"),
            @"key" : @"input_name",
        }
    ]];
    // TODO: add gpx groups
//    [data addObject:@[
//        @{
//            @"type" : kRouteGroupsCell,
//            @"header" : OALocalizedString(@"fav_group"),
//            @"key" : @"route_groups",
//        }
//    ]];
    
    if (_showSimplifiedButton)
    {
        [data addObject:@[
            @{
                @"type" : kSwitchCell,
                @"title" : OALocalizedString(@"simplified_track"),
                @"key" : @"simplified_track",
                @"footer" : OALocalizedString(@"simplified_track_description")
            }
        ]];
    }
    
    [data addObject:@[
        @{
            @"type" : kSwitchCell,
            @"title" : OALocalizedString(@"map_settings_show"),
            @"key" : @"map_settings_show"
        }
    ]];
    
    _data = data;
}

- (void) updateBottomButtons
{
    self.saveButton.userInteractionEnabled = _rightButtonEnabled;
    [self.saveButton setBackgroundColor:_rightButtonEnabled ? UIColorFromRGB(color_primary_purple) : UIColorFromRGB(color_icon_inactive)];
}

- (BOOL) cellValueByKey:(NSString *)key
{
    if ([key isEqualToString:@"simplified_track"])
        return _simplifiedTrack;
    if ([key isEqualToString:@"map_settings_show"])
        return _showOnMap;
    return NO;
}

- (IBAction)cancelButtonPressed:(id)sender
{
    [self dismissViewController];
}

- (IBAction)saveButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:NO completion:nil];
    if (self.delegate)
        [self.delegate onSaveAsNewTrack:_fileName showOnMap:_showOnMap simplifiedTrack:_simplifiedTrack];
}

#pragma mark - UITableViewDataSource

- (nonnull UITableViewCell *) tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *cellType = item[@"type"];
    if ([cellType isEqualToString:kTextInputCell])
    {
        OATextViewResizingCell* cell = [tableView dequeueReusableCellWithIdentifier:kTextInputCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kTextInputCell owner:self options:nil];
            cell = (OATextViewResizingCell *)[nib objectAtIndex:0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        if (cell)
        {
            cell.inputField.text = item[@"fileName"];
            cell.inputField.delegate = self;
            cell.inputField.textContainer.lineBreakMode = NSLineBreakByCharWrapping;
            cell.clearButton.tag = cell.inputField.tag;
            [cell.clearButton removeTarget:NULL action:NULL forControlEvents:UIControlEventTouchUpInside];
            [cell.clearButton addTarget:self action:@selector(clearButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        return cell;
    }
    else if ([cellType isEqualToString:kSwitchCell])
    {
        OASwitchTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kSwitchCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OASwitchCell" owner:self options:nil];
            cell = (OASwitchTableViewCell *)[nib objectAtIndex:0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        if (cell)
        {
            [cell.textView setText: item[@"title"]];
            NSString *itemKey = item[@"key"];
            BOOL value = [self cellValueByKey:itemKey];
            cell.switchView.on = value;
            cell.switchView.tag = indexPath.section << 10 | indexPath.row;
            [cell.switchView addTarget:self action:@selector(applyParameter:) forControlEvents:UIControlEventValueChanged];
        }
        return cell;
    }
    
    return nil;
}

- (NSInteger) tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _data[section].count;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (void) tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]){
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *) view;
        headerView.textLabel.textColor = UIColorFromRGB(color_text_footer);
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]){
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *) view;
        headerView.textLabel.textColor = _inputFieldError != nil && section == 0 ? UIColorFromRGB(color_primary_red) : UIColorFromRGB(color_text_footer);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSDictionary *item = ((NSArray *)_data[section]).firstObject;
    
    return item[@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
        return _inputFieldError;
    NSDictionary *item = ((NSArray *)_data[section]).firstObject;
    
    return item[@"footer"];
}

-(void) clearButtonPressed:(UIButton *)sender
{
    _fileName = @"";
    
    UIButton *btn = (UIButton *)sender;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:btn.tag & 0x3FF inSection:btn.tag >> 10];
    
    [_tableView beginUpdates];
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section]];
    if ([cell isKindOfClass:OATextViewResizingCell.class])
        ((OATextViewResizingCell *) cell).inputField.text = @"";
    [_tableView endUpdates];
}

- (void) applyParameter:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:sw.tag & 0x3FF inSection:sw.tag >> 10];
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *key = item[@"key"];
    if ([key isEqualToString:@"simplified_track"])
    {
        _simplifiedTrack = !_simplifiedTrack;
        [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    if ([key isEqualToString:@"map_settings_show"])
    {
        _showOnMap = !_showOnMap;
        [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark - UITextViewDelegate

- (void) textViewDidChange:(UITextView *)textView
{
    [self updateFileNameFromEditText:textView.text];
    
    [textView sizeToFit];
    [self.tableView beginUpdates];
    UITableViewHeaderFooterView *footer = [self.tableView footerViewForSection:0];
    footer.textLabel.textColor = _inputFieldError != nil ? UIColorFromRGB(color_primary_red) : UIColorFromRGB(color_text_footer);
    footer.textLabel.text = _inputFieldError;
    [footer sizeToFit];
    [self.tableView endUpdates];
}

- (void) updateFileNameFromEditText:(NSString *)name
{
    _rightButtonEnabled = NO;
    NSString *text = name.trim;
    if (text.length == 0)
    {
        _inputFieldError = OALocalizedString(@"empty_filename");
    }
    else if ([self isFileExist:name])
    {
        _inputFieldError = OALocalizedString(@"gpx_already_exsists");
    }
    else
    {
        _inputFieldError = nil;
        _fileName = text;
        _rightButtonEnabled = YES;
    }
    [self updateBottomButtons];
}

- (BOOL) isFileExist:(NSString *)name
{
    NSString *filePath = [[OsmAndApp.instance.gpxPath stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"gpx"];
    return [NSFileManager.defaultManager fileExistsAtPath:filePath];
}

#pragma mark - Keyboard Notifications

- (CGFloat)getModalPresentationOffset:(BOOL)keyboardShown
{
    CGFloat modalOffset = 0;
    if (@available(iOS 13.0, *)) {
        // accounts for additional top offset in modal presentation 
        modalOffset = keyboardShown ? 6. : 10.;
    }
    return modalOffset;
}

- (void) keyboardWillShow:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardBounds;
    [[userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardBounds];
    CGFloat duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        self.view.frame = CGRectMake(0., 0., self.view.frame.size.width, DeviceScreenHeight - OAUtilities.getStatusBarHeight - keyboardBounds.size.height - [self getModalPresentationOffset:YES]);
    } completion:nil];
}

- (void) keyboardWillHide:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    CGFloat duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        self.view.frame = CGRectMake(0., 0., self.view.frame.size.width, DeviceScreenHeight - OAUtilities.getStatusBarHeight - [self getModalPresentationOffset:NO]);
    } completion:nil];
}

@end
