package com.buzzvil

import android.view.LayoutInflater
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

// Buzzvil native-ad API. Class names / signatures verified against the resolved
// com.buzzvil:buzzad-benefit-base 6.7.7 AAR via `javap` (transitive through
// buzzvil-sdk / buzzvil-bom). Notably: BuzzNativeViewBinder.bind() takes the
// BuzzNative loader (NOT the loaded BuzzNativeAd), and the binder exposes
// unbind()/dispose() for cleanup.
import com.buzzvil.buzzbenefit.buzznative.BuzzMediaView
import com.buzzvil.buzzbenefit.DefaultBuzzCtaView
import com.buzzvil.buzzbenefit.buzznative.BuzzNative
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeAd
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdEventsListener
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdView as BuzzAdView
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeViewBinder
import com.buzzvil.buzzbenefit.buzznative.BuzzRewardResult

class BuzzvilNativeAdView(context: ThemedReactContext) : FrameLayout(context) {
  // Plain private fields + explicit setters. Do NOT use `var x; private set` —
  // its generated setX(String) would clash with the fun setX(String) below.
  private var unitId: String? = null
  private var layoutVariant: String = "300x250"

  private var buzzNative: BuzzNative? = null
  private var binder: BuzzNativeViewBinder? = null
  private var loaded = false

  fun setUnitId(id: String) {
    unitId = id.ifEmpty { null }
    loadIfReady()
  }

  fun setLayoutVariant(v: String) {
    layoutVariant = v
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    loadIfReady()
  }

  // Fabric sets props in any order, and the view may not be attached when the
  // unitId arrives — both entry points call this, the `loaded` guard makes it
  // idempotent so we load exactly once.
  private fun loadIfReady() {
    val id = unitId
    if (loaded || id == null || !isAttachedToWindow) return
    loaded = true

    val buzz = BuzzNative(id)
    buzzNative = buzz

    buzz.setAdEventsListener(
      object : BuzzNativeAdEventsListener {
        override fun onImpressed(ad: BuzzNativeAd) {
          emit("topImpressed", Arguments.createMap())
        }

        override fun onClicked(ad: BuzzNativeAd) {
          emit("topAdClicked", Arguments.createMap())
        }

        override fun onRewardRequested(ad: BuzzNativeAd) {
          // No matching JS event.
        }

        override fun onParticipated(ad: BuzzNativeAd) {
          // No matching JS event.
        }

        override fun onRewarded(ad: BuzzNativeAd, result: BuzzRewardResult) {
          val payload = Arguments.createMap()
          payload.putBoolean("success", result == BuzzRewardResult.SUCCESS)
          emit("topRewarded", payload)
        }
      },
    )

    buzz.load(
      { _ ->
        // Inflate + bind must touch views on the UI thread.
        UiThreadUtil.runOnUiThread { bindLoadedAd(buzz) }
      },
      { error ->
        // Marshal to the UI thread for symmetry with the success path; the SDK
        // gives no thread guarantee for these callbacks.
        UiThreadUtil.runOnUiThread {
          val payload = Arguments.createMap()
          payload.putString("code", error.type.name)
          payload.putString("message", error.message ?: error.type.name)
          emit("topAdFailed", payload)
        }
      },
    )
  }

  private fun bindLoadedAd(buzz: BuzzNative) {
    val adView = LayoutInflater.from(context)
      .inflate(R.layout.buzzvil_native_ad_card, this, false) as BuzzAdView
    removeAllViews()
    addView(adView)

    val media = adView.findViewById<BuzzMediaView>(R.id.buzz_media)
    val icon = adView.findViewById<ImageView>(R.id.buzz_icon)
    val title = adView.findViewById<TextView>(R.id.buzz_title)
    val desc = adView.findViewById<TextView>(R.id.buzz_desc)
    val cta = adView.findViewById<DefaultBuzzCtaView>(R.id.buzz_cta)

    binder = BuzzNativeViewBinder.Builder()
      .buzzNativeAdView(adView)
      .buzzMediaView(media)
      .iconImageView(icon)
      .titleTextView(title)
      .descriptionTextView(desc)
      .buzzCtaView(cta)
      .build()
    // bind() takes the BuzzNative loader, not the loaded BuzzNativeAd.
    binder?.bind(buzz)

    val payload = Arguments.createMap()
    payload.putDouble("width", width.toDouble())
    payload.putDouble("height", height.toDouble())
    emit("topAdLoaded", payload)
  }

  private fun emit(eventName: String, payload: WritableMap) {
    val reactContext = context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id) ?: return
    dispatcher.dispatchEvent(BuzzvilAdEvent(surfaceId, id, eventName, payload))
  }

  fun cleanup() {
    binder?.dispose()
    binder = null
    buzzNative = null
    loaded = false
    removeAllViews()
  }

  private class BuzzvilAdEvent(
    surfaceId: Int,
    viewTag: Int,
    private val name: String,
    private val payload: WritableMap,
  ) : Event<BuzzvilAdEvent>(surfaceId, viewTag) {
    override fun getEventName() = name

    override fun getEventData() = payload
  }
}
