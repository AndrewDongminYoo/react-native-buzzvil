package com.buzzvil

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.BuzzvilNativeAdViewManagerDelegate
import com.facebook.react.viewmanagers.BuzzvilNativeAdViewManagerInterface

@ReactModule(name = BuzzvilNativeAdViewManager.NAME)
class BuzzvilNativeAdViewManager :
  SimpleViewManager<BuzzvilNativeAdView>(),
  BuzzvilNativeAdViewManagerInterface<BuzzvilNativeAdView> {
  private val mDelegate: ViewManagerDelegate<BuzzvilNativeAdView>

  init {
    mDelegate = BuzzvilNativeAdViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<BuzzvilNativeAdView>? = mDelegate

  override fun getName(): String = NAME

  public override fun createViewInstance(context: ThemedReactContext): BuzzvilNativeAdView = BuzzvilNativeAdView(context)

  @ReactProp(name = "unitId")
  override fun setUnitId(
    view: BuzzvilNativeAdView,
    value: String?,
  ) {
    view.setUnitId(value ?: "")
  }

  @ReactProp(name = "layout")
  override fun setLayout(
    view: BuzzvilNativeAdView,
    value: String?,
  ) {
    view.setLayoutVariant(value ?: "300x250")
  }

  // Map the bubbling event names dispatched by the view to the JS prop handlers
  // declared in BuzzvilNativeAdViewNativeComponent.ts.
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topAdLoaded" to mapOf("registrationName" to "onAdLoaded"),
      "topAdFailed" to mapOf("registrationName" to "onAdFailed"),
      "topAdClicked" to mapOf("registrationName" to "onAdClicked"),
      "topImpressed" to mapOf("registrationName" to "onImpressed"),
      "topRewarded" to mapOf("registrationName" to "onRewarded"),
    )

  // Single load entry point: React applies unitId/layout through separate setters
  // (store-only), then calls this once after the prop batch settles — so a render
  // that changes both props triggers exactly one load with the final
  // (unitId, layout) pair, never an intermediate request for a stale pair, and a
  // layout-only change rebinds with the new layout instead of being silently
  // dropped by the unitId-keyed dedup.
  override fun onAfterUpdateTransaction(view: BuzzvilNativeAdView) {
    super.onAfterUpdateTransaction(view)
    view.loadIfReady()
  }

  override fun onDropViewInstance(view: BuzzvilNativeAdView) {
    view.cleanup()
    super.onDropViewInstance(view)
  }

  companion object {
    const val NAME = "BuzzvilNativeAdView"
  }
}
