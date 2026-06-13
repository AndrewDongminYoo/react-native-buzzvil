#import "Buzzvil.h"

#import <React/RCTUtils.h>

// BuzzvilSDK exposes the high-level `BuzzBenefit` session API; BuzzAdBenefitSDK
// exposes `BuzzBenefitHub`. Both are @objc and verified against the installed
// frameworks' generated `-Swift.h` headers (BuzzvilSDK 6.7.5).
#import <BuzzvilSDK/BuzzvilSDK-Swift.h>
#import <BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>

@class BuzzInterstitialLoader;

/**
 * Per-load helper that conforms to `BuzzInterstitialDelegate` and captures the
 * promise blocks + `unitId` for one `loadInterstitial` call.
 *
 * Why a helper at all: `BuzzInterstitial.delegate` is a **weak** property and
 * its delegate callbacks pass back the `BuzzInterstitial` (not the unitId). A
 * dedicated loader (a) owns the `BuzzInterstitial` strongly so a later
 * `showInterstitial` can present it, (b) carries the `unitId` directly so no
 * instance→unitId reverse lookup is needed, and (c) is retained by the module's
 * `_loaders` map so ARC doesn't dealloc it the moment `loadInterstitial`
 * returns (which would silently drop every callback and hang the promise).
 *
 * The back-ref to the module is **weak** to avoid a retain cycle (the module is
 * a long-lived TurboModule singleton). The module owns loader removal so a
 * loader's final act is `[module removeLoaderForUnitId:]` — after which `self`
 * may be deallocated, so callbacks touch nothing on `self` afterwards.
 */
@interface BuzzInterstitialLoader : NSObject <BuzzInterstitialDelegate>
@property (nonatomic, strong) BuzzInterstitial *interstitial;
@property (nonatomic, copy) NSString *unitId;
@property (nonatomic, copy) RCTPromiseResolveBlock resolve;
@property (nonatomic, copy) RCTPromiseRejectBlock reject;
@property (nonatomic, assign) BOOL settled; // settle the promise exactly once
@property (nonatomic, weak) Buzzvil *module;
@end

@implementation Buzzvil {
  // unitId → loader. Retains each loader (and its BuzzInterstitial) from load
  // until did-fail / did-dismiss removes it (parity with Android's map cleanup).
  NSMutableDictionary<NSString *, BuzzInterstitialLoader *> *_loaders;
}

- (NSMutableDictionary<NSString *, BuzzInterstitialLoader *> *)loaders
{
  if (_loaders == nil) {
    _loaders = [NSMutableDictionary new];
  }
  return _loaders;
}

- (void)removeLoaderForUnitId:(NSString *)unitId
{
  [_loaders removeObjectForKey:unitId];
}

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

#pragma mark - Interstitial

- (void)loadInterstitial:(NSString *)unitId
                    type:(NSString *)type
                 resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
{
  // type sentinel: "bottomSheet" → bottom sheet; "dialog"/""/unknown → dialog
  // (parity with Android's buildBottomSheet()/buildDialog()).
  BuzzInterstitialType interstitialType =
      [type isEqualToString:@"bottomSheet"] ? BuzzInterstitialTypeBottomSheet : BuzzInterstitialTypeDialog;

  BuzzInterstitialLoader *loader = [BuzzInterstitialLoader new];
  loader.unitId = unitId;
  loader.resolve = resolve;
  loader.reject = reject;
  loader.module = self;
  loader.interstitial = [[BuzzInterstitial alloc] initWithUnitId:unitId type:interstitialType];
  loader.interstitial.delegate = loader; // delegate is weak — loader must outlive this call

  // Retain the loader (and its BuzzInterstitial) until did-fail / did-dismiss.
  self.loaders[unitId] = loader;

  [loader.interstitial load];
}

- (void)showInterstitial:(NSString *)unitId
{
  // present presents UI — must run on the main thread (parity with BenefitHub).
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = RCTPresentedViewController();
    if (presenter == nil) {
      return;
    }
    BuzzInterstitialLoader *loader = self->_loaders[unitId];
    if (loader == nil) {
      return; // nothing loaded for this unitId — no-op
    }
    [loader.interstitial presentOnViewController:presenter];
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

#pragma mark - BuzzInterstitialLoader

@implementation BuzzInterstitialLoader

- (void)buzzInterstitialDidLoadAd:(BuzzInterstitial *)interstitial
{
  if (self.settled) {
    return;
  }
  self.settled = YES;
  self.resolve(nil);
  // Keep the loader in the map — showInterstitial needs it until dismiss.
}

- (void)buzzInterstitialDidFailToLoadAd:(BuzzInterstitial *)interstitial withError:(NSError *)error
{
  if (self.settled) {
    return;
  }
  self.settled = YES;
  // Capture before removal: removing from the map may dealloc self.
  NSString *unitId = self.unitId;
  RCTPromiseRejectBlock reject = self.reject;
  Buzzvil *module = self.module;
  reject(@"buzzvil_interstitial_load_failed", error.localizedDescription ?: @"Interstitial load failed.", error);
  [module removeLoaderForUnitId:unitId]; // final act — touch nothing on self after this
}

- (void)buzzInterstitialDidDismiss:(UIViewController *)viewController
{
  // Capture before removal: removing from the map may dealloc self.
  NSString *unitId = self.unitId;
  Buzzvil *module = self.module;
  // New-Arch typed EventEmitter: codegen generates emitOnInterstitialClosed on
  // the spec base; payload is a flat NSDictionary { unitId } (parity with Android).
  [module emitOnInterstitialClosed:@{@"unitId" : unitId}];
  [module removeLoaderForUnitId:unitId]; // final act — touch nothing on self after this
}

@end
