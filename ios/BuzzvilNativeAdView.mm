#import "BuzzvilNativeAdView.h"

#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@implementation BuzzvilNativeAdView {
    UIView * _view;
    std::string _unitId;
    std::string _layout;
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

    _view = [[UIView alloc] init];

    self.contentView = _view;
  }

  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    const auto &newViewProps = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(props);

    // Store the ad props; real Buzzvil SDK wiring lands in later tasks.
    _unitId = newViewProps.unitId;
    _layout = newViewProps.layout;

    [super updateProps:props oldProps:oldProps];
}

@end
