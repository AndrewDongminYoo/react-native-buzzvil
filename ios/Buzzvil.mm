#import "Buzzvil.h"

#import <React/RCTUtils.h>

// BuzzvilSDK exposes the high-level `BuzzBenefit` session API; BuzzAdBenefitSDK
// exposes `BuzzBenefitHub`. Both are @objc and verified against the installed
// frameworks' generated `-Swift.h` headers (BuzzvilSDK 6.7.5).
#import <BuzzvilSDK/BuzzvilSDK-Swift.h>
#import <BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>

@implementation Buzzvil

- (void)initialize:(NSString *)appId
{
  BuzzBenefitConfig *config = [BuzzBenefitConfig configWith:^(BuzzBenefitConfigBuilder *builder) {
    builder.appId = appId;
  }];
  [[BuzzBenefit sharedInstance] initializeWith:config onCompleted:nil];
}

- (void)login:(NSString *)userId
       gender:(NSString *)gender
    birthYear:(double)birthYear
      resolve:(RCTPromiseResolveBlock)resolve
       reject:(RCTPromiseRejectBlock)reject
{
  BuzzBenefitUser *user = [BuzzBenefitUser userWith:^(BuzzBenefitUserBuilder *builder) {
    builder.userId = userId;
    // Sentinel contract (see NativeBuzzvil.ts): "" → leave gender unset.
    if ([gender isEqualToString:@"MALE"]) {
      builder.gender = BuzzBenefitUserGenderMale;
    } else if ([gender isEqualToString:@"FEMALE"]) {
      builder.gender = BuzzBenefitUserGenderFemale;
    }
    // Sentinel: 0 → leave birth year unset.
    if (birthYear > 0) {
      builder.birthYear = (NSInteger)birthYear;
    }
  }];

  [[BuzzBenefit sharedInstance] loginWith:user
                                onSuccess:^{
                                  resolve(nil);
                                }
                                onFailure:^(NSError *error) {
                                  reject(@"buzzvil_login_failed",
                                         error.localizedDescription ?: @"Buzzvil login failed",
                                         error);
                                }];
}

- (void)logout
{
  [[BuzzBenefit sharedInstance] logout];
}

- (void)isLoggedIn:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@([[BuzzBenefit sharedInstance] isLoggedIn]));
}

- (void)showBenefitHub:(NSString *)routePath showHistory:(BOOL)showHistory
{
  // BenefitHub presentation is UI work — must run on the main thread.
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = RCTPresentedViewController();
    if (presenter == nil) {
      return;
    }

    BuzzBenefitHub *hub = [BuzzBenefitHub new];

    if (routePath.length > 0 || showHistory) {
      BuzzBenefitHubConfig *config = [BuzzBenefitHubConfig configWith:^(BuzzBenefitHubConfigBuilder *builder) {
        if (routePath.length > 0) {
          builder.routePath = routePath;
        }
        if (showHistory) {
          builder.queryParams = [[BuzzBenefitHubPage history] toRedirectQueryParams];
        }
      }];
      [hub setConfig:config];
    }

    [hub showOn:presenter];
  });
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeBuzzvilSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"Buzzvil";
}

@end
