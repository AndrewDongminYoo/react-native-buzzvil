package com.buzzvil

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.BuzzBannerViewManagerDelegate
import com.facebook.react.viewmanagers.BuzzBannerViewManagerInterface

@ReactModule(name = BuzzBannerViewManager.NAME)
class BuzzBannerViewManager :
  SimpleViewManager<BuzzBannerView>(),
  BuzzBannerViewManagerInterface<BuzzBannerView> {
  private val mDelegate: ViewManagerDelegate<BuzzBannerView>

  init {
    mDelegate = BuzzBannerViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<BuzzBannerView>? = mDelegate

  override fun getName(): String = NAME

  public override fun createViewInstance(context: ThemedReactContext): BuzzBannerView = BuzzBannerView(context)

  @ReactProp(name = "placementId")
  override fun setPlacementId(
    view: BuzzBannerView,
    value: String?,
  ) {
    view.setPlacementId(value ?: "")
  }

  @ReactProp(name = "size")
  override fun setSize(
    view: BuzzBannerView,
    value: String?,
  ) {
    view.setSize(value ?: "W320XH50")
  }

  // Map the bubbling event names to the JS prop handlers declared in
  // BuzzBannerViewNativeComponent.ts.
  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topLoaded" to mapOf("registrationName" to "onLoaded"),
      "topFailed" to mapOf("registrationName" to "onFailed"),
      "topClicked" to mapOf("registrationName" to "onClicked"),
    )

  override fun onDropViewInstance(view: BuzzBannerView) {
    view.cleanup()
    super.onDropViewInstance(view)
  }

  companion object {
    const val NAME = "BuzzBannerView"
  }
}
