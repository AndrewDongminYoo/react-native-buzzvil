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

    [self buildAdCard];
    self.contentView = _adContainer;
  }

  return self;
}

// Builds the BuzzNativeAdView container holding (vertically, via Auto Layout) a
// media view, icon, title, description, and CTA. Visual refinement is a later
// task — wiring the binder-required views correctly is what matters here.
- (void)buildAdCard
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

  // Simple vertical stack pinned to the container edges. Exact sizing is refined
  // in the layout-variants task.
  [NSLayoutConstraint activateConstraints:@[
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

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(props);

  // `layout` is consumed by the visual layout task; read it so the prop is wired.
  (void)newViewProps.layout;

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

  CGSize size = _adContainer.bounds.size;
  [self emitLoadedWithWidth:size.width height:size.height];
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

  [super prepareForRecycle];
}

@end
