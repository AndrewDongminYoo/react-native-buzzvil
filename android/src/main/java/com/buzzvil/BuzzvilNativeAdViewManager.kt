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

  override fun getDelegate(): ViewManagerDelegate<BuzzvilNativeAdView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): BuzzvilNativeAdView {
    return BuzzvilNativeAdView(context)
  }

  @ReactProp(name = "unitId")
  override fun setUnitId(view: BuzzvilNativeAdView, value: String?) {
    view.setUnitId(value ?: "")
  }

  @ReactProp(name = "layout")
  override fun setLayout(view: BuzzvilNativeAdView, value: String?) {
    view.setLayoutVariant(value ?: "300x250")
  }

  companion object {
    const val NAME = "BuzzvilNativeAdView"
  }
}
