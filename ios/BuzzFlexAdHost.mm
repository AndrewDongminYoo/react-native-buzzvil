#import "BuzzFlexAdHost.h"

// SDK import isolated to THIS translation unit. BuzzAdBenefitSDK vends
// `BuzzFlex` / `BuzzFlexAdView` / `BuzzFlexDelegate` (verified against the
// installed framework's generated -Swift.h + .swiftinterface, BuzzAdBenefitSDK
// 6.7.5). Same direct-from-Obj-C++ import the TurboModule (`Buzzvil.mm`) and
// `BuzzBannerAdHost.mm` use. The SDK's `BuzzFlexAdView` is a UIView whose name
// collides with our RN Fabric class of the same name — keeping this import out
// of BuzzFlexAdView.mm is the whole reason this host file exists.
#import <BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>

// `BuzzFlexAdBinder` is the @objc Swift shim (BuzzFlexAdShim.swift, compiled
// into THIS pod) that exposes `BuzzFlexAdView.bind(_:)`, which is not @objc.
// Same-target generated header: quoted import, no module prefix (Buzzvil is
// a static library, not a framework, so `<Buzzvil/Buzzvil-Swift.h>` doesn't
// resolve).
#import "Buzzvil-Swift.h"

@interface BuzzFlexAdHost () <BuzzFlexDelegate>
@end

@implementation BuzzFlexAdHost {
  BuzzFlexAdView *_adView;
  BuzzFlex *_flex;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    // The SDK ad + view are allocated per request (see requestAdWithUnitId…),
    // mirroring BuzzBannerAdHost: re-configuring after removeAd is not a
    // contract the headers express, so a clean instance avoids relying on it.
  }
  return self;
}

- (void)requestAdWithUnitId:(NSString *)unitId primaryColor:(nullable UIColor *)primaryColor
{
  // Fresh SDK ad + view per request (mirrors BuzzBannerAdHost). Tear down +
  // replace any previous one so an in-place reconfigure (unitId change) starts
  // clean instead of re-binding a used view.
  [self removeAd];

  BuzzFlexAdView *adView = [[BuzzFlexAdView alloc] initWithFrame:CGRectZero];
  adView.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:adView];
  [NSLayoutConstraint activateConstraints:@[
    [adView.topAnchor constraintEqualToAnchor:self.topAnchor],
    [adView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [adView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [adView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
  ]];
  _adView = adView;

  BuzzFlex *flex = [[BuzzFlex alloc] initWithUnitId:unitId];
  flex.delegate = self;
  if (primaryColor != nil) {
    [flex setPrimaryColor:primaryColor];
  }
  _flex = flex;

  [flex load];
}

- (void)removeAd
{
  [_adView removeFromSuperview];
  _adView = nil;
  _flex.delegate = nil;
  _flex = nil;
}

#pragma mark - BuzzFlexDelegate

- (void)buzzFlexOnSuccess
{
  [BuzzFlexAdBinder bind:_adView to:_flex];
  [self.adDelegate flexAdHostDidLoad:self];
}

- (void)buzzFlexOnFailure:(NSError *)error
{
  // Parity with BuzzBannerAdHost: the SDK's localizedDescription can be terse,
  // so append the error domain + code so the JS `message` is self-describing
  // in logs. The bare numeric `code` field is preserved for programmatic
  // handling.
  NSString *code = [@(error.code) stringValue];
  NSString *description = error.localizedDescription.length > 0 ? error.localizedDescription : @"unknown error";
  NSString *message = [NSString stringWithFormat:@"%@ (domain=%@, code=%@)", description, error.domain, code];
  [self.adDelegate flexAdHost:self didFailWithCode:code message:message];
}

- (void)buzzFlexOnClicked
{
  [self.adDelegate flexAdHostDidClick:self];
}

@end
