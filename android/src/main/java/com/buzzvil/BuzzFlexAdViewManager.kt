package com.buzzvil

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.BuzzFlexAdViewManagerDelegate
import com.facebook.react.viewmanagers.BuzzFlexAdViewManagerInterface

@ReactModule(name = BuzzFlexAdViewManager.NAME)
class BuzzFlexAdViewManager :
  SimpleViewManager<BuzzFlexAdView>(),
  BuzzFlexAdViewManagerInterface<BuzzFlexAdView> {
  private val mDelegate: ViewManagerDelegate<BuzzFlexAdView>

  init {
    mDelegate = BuzzFlexAdViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<BuzzFlexAdView>? = mDelegate

  override fun getName(): String = NAME

  public override fun createViewInstance(context: ThemedReactContext): BuzzFlexAdView = BuzzFlexAdView(context)

  @ReactProp(name = "unitId")
  override fun setUnitId(
    view: BuzzFlexAdView,
    value: String?,
  ) {
    view.setUnitId(value ?: "")
  }

  @ReactProp(name = "primaryColor", customType = "Color")
  override fun setPrimaryColor(
    view: BuzzFlexAdView,
    value: Int?,
  ) {
    view.setPrimaryColor(value)
  }

  // Map the bubbling event names to the JS prop handlers declared in
  // BuzzFlexAdViewNativeComponent.ts.
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topLoaded" to mapOf("registrationName" to "onLoaded"),
      "topFailed" to mapOf("registrationName" to "onFailed"),
      "topClicked" to mapOf("registrationName" to "onClicked"),
    )

  // Single load entry point: a render that changes unitId reloads once the
  // prop batch settles (mirrors BuzzBannerViewManager / BuzzvilNativeAdViewManager).
  override fun onAfterUpdateTransaction(view: BuzzFlexAdView) {
    super.onAfterUpdateTransaction(view)
    view.loadIfReady()
  }

  override fun onDropViewInstance(view: BuzzFlexAdView) {
    view.cleanup()
    super.onDropViewInstance(view)
  }

  companion object {
    const val NAME = "BuzzFlexAdView"
  }
}
