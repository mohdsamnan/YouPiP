#import <version.h>
#import "Header.h"
#import <YouTubeHeader/YTAppSettingsSectionItemActionController.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]

#define FEATURE_CUTOFF_VERSION @"19.01.1"

static const NSInteger YouPiPSection = 200;

// Define missing keys
static NSString *const AccessibilityLabelKey = @"AccessibilityLabel";
static NSString *const SelectorKey = @"Selector";
static NSString *const ToggleKey = @"Toggle";
static NSString *const YouPiPWarnVersionKey = @"YouPiPWarnVersion";

@interface YTSettingsSectionItemManager (YouPiP)
- (void)updateYouPiPSectionWithEntry:(id)entry;
@end

extern BOOL TweakEnabled();
extern BOOL UsePiPButton();
extern BOOL UseTabBarPiPButton();
extern BOOL UseAllPiPMethod();
extern BOOL NoMiniPlayerPiP();
extern BOOL LegacyPiP();
extern BOOL NonBackgroundable();
extern BOOL FakeVersion();

extern NSBundle *YouPiPBundle();

NSString *currentVersion;

%hook YTAppSettingsPresentationData
+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound) {
        NSMutableArray <NSNumber *> *mutableOrder = order.mutableCopy;
        [mutableOrder insertObject:@(YouPiPSection) atIndex:insertIndex + 1];
        order = mutableOrder.copy;
    }
    return order;
}
%end

%hook YTSettingsSectionItemManager
- (void)updateYouPiPSectionWithEntry:(id)entry {
    YTSettingsViewController *delegate = [self valueForKey:"_dataDelegate"];
    NSMutableArray *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = YouPiPBundle();

    YTSettingsSectionItem *enabled = [%c(YTSettingsSectionItem) switchItemWithTitle:LOC(@"ENABLED")
        titleDescription:LOC(@"ENABLED_DESC")
        switchOn:TweakEnabled()
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"EnabledKey"];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:enabled];

    if ([delegate respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_PICTURE_IN_PICTURE;
        [delegate setSectionItems:sectionItems forCategory:YouPiPSection title:LOC(@"SETTINGS_TITLE") icon:icon titleDescription:nil headerHidden:NO];
    } else {
        [delegate setSectionItems:sectionItems forCategory:YouPiPSection title:LOC(@"SETTINGS_TITLE") titleDescription:nil headerHidden:NO];
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YouPiPSection) {
        [self updateYouPiPSectionWithEntry:entry];
        return;
    }
    %orig;
}
%end

BOOL loadWatchNextRequest = NO;

%hook YTVersionUtils
+ (NSString *)appVersion {
    return FakeVersion() && loadWatchNextRequest ? FEATURE_CUTOFF_VERSION : %orig;
}
%end

%hook YTWatchNextViewController
- (void)loadWatchNextRequest:(id)arg1 withInitialWatchNextResponse:(id)arg2 disableUnloadModel:(BOOL)arg3 {
    loadWatchNextRequest = YES;
    %orig;
    loadWatchNextRequest = NO;
}
%end

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    currentVersion = [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey];
    if (![defaults boolForKey:YouPiPWarnVersionKey] && [currentVersion compare:@(OS_STRINGIFY(MIN_YOUTUBE_VERSION)) options:NSNumericSearch] != NSOrderedDescending) {
        [defaults setBool:YES forKey:YouPiPWarnVersionKey];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSBundle *tweakBundle = YouPiPBundle();
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = @"YouPiP";
            alertView.subtitle = [NSString stringWithFormat:LOC(@"UNSUPPORTED_YT_VERSION"), currentVersion, @(OS_STRINGIFY(MIN_YOUTUBE_VERSION))];
            [alertView show];
        });
    }
    %init;
}
