#import "BuzzvilNativeAdView.h"

// BuzzAdBenefitSDK exposes the BuzzNative loader/binder/view classes as @objc;
// verified against the installed framework's generated -Swift.h (BuzzAdBenefitSDK
// 6.7.5). Same direct-from-Obj-C++ import the TurboModule (`Buzzvil.mm`) uses.
#import <BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>

#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/EventEmitters.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>

using namespace facebook::react;

@implementation BuzzvilNativeAdView {
  // Buzzvil ad card subviews, held so the binder can wire them post-load.
  BuzzNativeAdView *_adContainer;
  BuzzMediaView *_mediaView;
  UIImageView *_iconView;
  UILabel *_titleLabel;
  UILabel *_descriptionLabel;
  BuzzDefaultCtaView *_ctaView;

  BuzzNative *_native;
  BuzzNativeViewBinder *_binder;

  // Layout-variant state. The subviews are created in initWithFrame:, but the
  // `layout` prop (which family + height to use) only arrives in updateProps:.
  // Fabric recycles iOS views by COMPONENT TYPE, not by props, so a view first
  // mounted as a banner can be reused for a card cell — the arrangement must be
  // (re)applied whenever the resolved variant changes, not just once. We track
  // the variant currently applied and the constraints we activated for it so a
  // change can deactivate the old set before activating the new one.
  NSString *_appliedVariant;
  NSArray<NSLayoutConstraint *> *_variantConstraints;

  // Set when a load succeeds; the real size is emitted from layoutSubviews once
  // bounds are non-zero (a pre-layout emit would report {w,0}). Reset per load /
  // on recycle so we emit exactly once per successful load.
  BOOL _pendingLoadedEmit;

  // The unit id of the in-flight / loaded ad. Doubles as the recycle guard:
  // Fabric reuses the SAME object across cells (prepareForRecycle), so a stale
  // async callback must bail when this no longer matches the id it captured.
  // Cleared in prepareForRecycle — never latched permanently (that would brick
  // the recycled view).
  std::string _loadedUnitId;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<BuzzvilNativeAdViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const BuzzvilNativeAdViewProps>();
    _props = defaultProps;

    [self buildSubviews];
    self.contentView = _adContainer;
  }

  return self;
}

// Allocates the BuzzNativeAdView container and its subviews (media, icon, title,
// description, CTA) and adds them to the container. Does NOT activate any
// arrangement constraints — the family (banner vs card) is only known once the
// `layout` prop arrives, so layout is applied later in applyLayoutVariant:.
- (void)buildSubviews
{
  _adContainer = [[BuzzNativeAdView alloc] initWithFrame:CGRectZero];

  _mediaView = [[BuzzMediaView alloc] initWithFrame:CGRectZero];
  _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
  _iconView.contentMode = UIViewContentModeScaleAspectFit;
  _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  _titleLabel.numberOfLines = 1;
  _descriptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  _descriptionLabel.numberOfLines = 2;
  _ctaView = [[BuzzDefaultCtaView alloc] initWithFrame:CGRectZero];

  NSArray<UIView *> *children = @[ _mediaView, _iconView, _titleLabel, _descriptionLabel, _ctaView ];
  for (UIView *child in children) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [_adContainer addSubview:child];
  }
}

// Fixed inventory-box height (pt) per exact size. Width comes from the JS
// `style`. NOTE: under Fabric the host frame is ultimately driven by the shadow
// node, so this height is a best-effort hint (see PR notes).
- (CGFloat)heightForVariant:(NSString *)variant
{
  if ([variant isEqualToString:@"320x50"]) return 50;
  if ([variant isEqualToString:@"320x100"]) return 100;
  if ([variant isEqualToString:@"320x130"]) return 130;
  if ([variant isEqualToString:@"320x480"]) return 480;
  return 250; // 300x250 and default
}

- (BOOL)isBannerVariant:(NSString *)variant
{
  return [variant isEqualToString:@"320x50"] || [variant isEqualToString:@"320x100"] ||
      [variant isEqualToString:@"320x130"];
}

// Activates the correct arrangement (banner OR card) plus a fixed height
// constraint. Banner: horizontal icon + title/desc + CTA, media hidden+zero-size
// (the binder REQUIRES a non-nil mediaView — verified against the SDK header:
// "Required component"). Card: the original vertical stack with media on top.
// Re-appliable: a no-op when the variant is unchanged, otherwise the previously
// activated constraints are deactivated first (a recycled view may switch family).
- (void)applyLayoutVariant:(NSString *)variant
{
  if ([variant isEqualToString:_appliedVariant]) {
    return;
  }
  if (_variantConstraints.count > 0) {
    [NSLayoutConstraint deactivateConstraints:_variantConstraints];
  }
  _appliedVariant = variant;

  BOOL banner = [self isBannerVariant:variant];
  _mediaView.hidden = banner;

  NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];

  if (banner) {
    // Media kept in the tree (binder requires it) but collapsed to zero size.
    [constraints addObjectsFromArray:@[
      [_mediaView.widthAnchor constraintEqualToConstant:0],
      [_mediaView.heightAnchor constraintEqualToConstant:0],
      [_mediaView.topAnchor constraintEqualToAnchor:_adContainer.topAnchor],
      [_mediaView.leadingAnchor constraintEqualToAnchor:_adContainer.leadingAnchor],

      [_iconView.leadingAnchor constraintEqualToAnchor:_adContainer.leadingAnchor constant:8],
      [_iconView.centerYAnchor constraintEqualToAnchor:_adContainer.centerYAnchor],
      [_iconView.widthAnchor constraintEqualToConstant:36],
      [_iconView.heightAnchor constraintEqualToConstant:36],

      [_titleLabel.topAnchor constraintEqualToAnchor:_adContainer.topAnchor constant:8],
      [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8],
      [_titleLabel.trailingAnchor constraintEqualToAnchor:_ctaView.leadingAnchor constant:-8],

      [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
      [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
      [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

      [_ctaView.trailingAnchor constraintEqualToAnchor:_adContainer.trailingAnchor constant:-8],
      [_ctaView.centerYAnchor constraintEqualToAnchor:_adContainer.centerYAnchor],
    ]];
  } else {
    // Vertical stack: media on top, then icon + title/desc, then CTA.
    [constraints addObjectsFromArray:@[
      [_mediaView.topAnchor constraintEqualToAnchor:_adContainer.topAnchor],
      [_mediaView.leadingAnchor constraintEqualToAnchor:_adContainer.leadingAnchor],
      [_mediaView.trailingAnchor constraintEqualToAnchor:_adContainer.trailingAnchor],

      [_iconView.topAnchor constraintEqualToAnchor:_mediaView.bottomAnchor constant:8],
      [_iconView.leadingAnchor constraintEqualToAnchor:_adContainer.leadingAnchor constant:8],
      [_iconView.widthAnchor constraintEqualToConstant:40],
      [_iconView.heightAnchor constraintEqualToConstant:40],

      [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.topAnchor],
      [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8],
      [_titleLabel.trailingAnchor constraintEqualToAnchor:_adContainer.trailingAnchor constant:-8],

      [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
      [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
      [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_adContainer.trailingAnchor constant:-8],

      [_ctaView.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:8],
      [_ctaView.leadingAnchor constraintEqualToAnchor:_adContainer.leadingAnchor constant:8],
      [_ctaView.trailingAnchor constraintEqualToAnchor:_adContainer.trailingAnchor constant:-8],
      [_ctaView.bottomAnchor constraintEqualToAnchor:_adContainer.bottomAnchor constant:-8],
    ]];
  }

  // Fixed inventory-box height on the container.
  [constraints addObject:[_adContainer.heightAnchor constraintEqualToConstant:[self heightForVariant:variant]]];

  _variantConstraints = constraints;
  [NSLayoutConstraint activateConstraints:constraints];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(props);

  // Resolve the layout family/height from the `layout` prop (empty -> card
  // default) and apply the arrangement. applyLayoutVariant: is a no-op when the
  // variant is unchanged, so this runs on every updateProps but only does work
  // on first mount or when a recycled view switches family. Must happen before
  // the load below so the binder sees the correct (banner vs card) view tree.
  NSString *variant = newViewProps.layout.empty()
      ? @"300x250"
      : [NSString stringWithUTF8String:newViewProps.layout.c_str()];
  [self applyLayoutVariant:variant];

  const std::string &unitId = newViewProps.unitId;
  // Fabric sets props in any order and may re-deliver them; only (re)load when a
  // non-empty unit id actually changes.
  if (!unitId.empty() && unitId != _loadedUnitId) {
    _loadedUnitId = unitId;
    [self loadAdWithUnitId:unitId];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)loadAdWithUnitId:(const std::string &)unitId
{
  // Tear down any previous ad before a new load (mirrors prepareForRecycle);
  // a unitId prop change on a mounted view reuses this same object.
  [_binder unbind];
  _binder = nil;
  _native = nil;
  _pendingLoadedEmit = NO;

  NSString *unitIdString = [NSString stringWithUTF8String:unitId.c_str()];
  // Capture the id this load is for; the recycle guard compares against it.
  std::string requestedUnitId = unitId;

  _native = [[BuzzNative alloc] initWithUnitId:unitIdString];

  // Subscribe BEFORE load (the SDK header mandates this ordering). Weak self in
  // every block: `_native` is a strong ivar that retains these blocks, so strong
  // capture would form a self -> _native -> block -> self cycle.
  // All emits hop to main: the `_loadedUnitId` recycle guard is written on the
  // main thread (updateProps / prepareForRecycle), so its callback reads must be
  // on main too, and it keeps the threading model uniform with the load path.
  __weak BuzzvilNativeAdView *weakSelf = self;
  [_native subscribeAdEventsOnImpressed:^(BuzzNativeAd *ad) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf emitImpressedForUnitId:requestedUnitId];
    });
  }
      onClicked:^(BuzzNativeAd *ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [weakSelf emitClickedForUnitId:requestedUnitId];
        });
      }
      onRewardRequested:^(BuzzNativeAd *ad) {
        // No matching JS event.
      }
      onRewarded:^(BuzzNativeAd *ad, enum BuzzRewardResult result) {
        BOOL success = (result == BuzzRewardResultSuccess);
        dispatch_async(dispatch_get_main_queue(), ^{
          [weakSelf emitRewarded:success forUnitId:requestedUnitId];
        });
      }
      onParticipated:^(BuzzNativeAd *ad) {
        // No matching JS event.
      }];

  [_native loadOnSuccess:^(BuzzNativeAd *ad) {
    // Binding + emitting touches UIKit and the event emitter — hop to main and
    // re-check the recycle guard AFTER the hop, since a recycle can land during it.
    dispatch_async(dispatch_get_main_queue(), ^{
      BuzzvilNativeAdView *strongSelf = weakSelf;
      if (strongSelf == nil || strongSelf->_loadedUnitId != requestedUnitId) {
        return;
      }
      [strongSelf bindLoadedAd];
    });
  }
      onFailure:^(NSError *error) {
        NSString *codeString = [@(error.code) stringValue];
        NSString *messageString = error.localizedDescription;
        dispatch_async(dispatch_get_main_queue(), ^{
          BuzzvilNativeAdView *strongSelf = weakSelf;
          if (strongSelf == nil || strongSelf->_loadedUnitId != requestedUnitId) {
            return;
          }
          [strongSelf emitFailedWithCode:codeString message:messageString];
        });
      }];
}

- (void)bindLoadedAd
{
  _binder = [BuzzNativeViewBinder viewBinderWith:^(BuzzNativeViewBinderBuilder *builder) {
    builder.nativeAdView = _adContainer;
    builder.mediaView = _mediaView;
    builder.iconImageView = _iconView;
    builder.titleLabel = _titleLabel;
    builder.descriptionLabel = _descriptionLabel;
    builder.ctaView = _ctaView;
  }];
  // bind() takes the BuzzNative loader, not the loaded BuzzNativeAd (mirrors Android).
  [_binder bind:_native];

  // Defer the size emit to layoutSubviews: at bind time the view hasn't been
  // laid out yet, so bounds would be {w,0}. layoutSubviews fires once a real
  // frame is assigned; the flag makes us emit exactly once per load.
  _pendingLoadedEmit = YES;
  [self setNeedsLayout];
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  // Emit the real measured size once the host has a non-zero frame.
  if (_pendingLoadedEmit && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
    _pendingLoadedEmit = NO;
    CGSize size = self.bounds.size;
    [self emitLoadedWithWidth:size.width height:size.height];
  }
}

#pragma mark - Event emitter

- (const BuzzvilNativeAdViewEventEmitter &)eventEmitterRef
{
  return static_cast<const BuzzvilNativeAdViewEventEmitter &>(*_eventEmitter);
}

- (void)emitLoadedWithWidth:(CGFloat)width height:(CGFloat)height
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onAdLoaded(
      BuzzvilNativeAdViewEventEmitter::OnAdLoaded{.width = (double)width, .height = (double)height});
}

- (void)emitFailedWithCode:(NSString *)code message:(NSString *)message
{
  if (!_eventEmitter) {
    return;
  }
  [self eventEmitterRef].onAdFailed(BuzzvilNativeAdViewEventEmitter::OnAdFailed{
      .code = std::string(code.UTF8String ?: ""),
      .message = std::string(message.UTF8String ?: "")});
}

- (void)emitClickedForUnitId:(const std::string &)unitId
{
  if (!_eventEmitter || _loadedUnitId != unitId) {
    return;
  }
  [self eventEmitterRef].onAdClicked(BuzzvilNativeAdViewEventEmitter::OnAdClicked{});
}

- (void)emitImpressedForUnitId:(const std::string &)unitId
{
  if (!_eventEmitter || _loadedUnitId != unitId) {
    return;
  }
  [self eventEmitterRef].onImpressed(BuzzvilNativeAdViewEventEmitter::OnImpressed{});
}

- (void)emitRewarded:(BOOL)success forUnitId:(const std::string &)unitId
{
  if (!_eventEmitter || _loadedUnitId != unitId) {
    return;
  }
  [self eventEmitterRef].onRewarded(BuzzvilNativeAdViewEventEmitter::OnRewarded{.success = (bool)success});
}

#pragma mark - Recycling

- (void)prepareForRecycle
{
  // Clearing _loadedUnitId is the recycle guard: any in-flight callback captured
  // the old id and will bail on mismatch. Do NOT latch a permanent disposed flag
  // — Fabric reuses this same object, so it must be able to load again.
  [_binder unbind];
  _binder = nil;
  _native = nil;
  _loadedUnitId.clear();
  _pendingLoadedEmit = NO;

  [super prepareForRecycle];
}

@end
