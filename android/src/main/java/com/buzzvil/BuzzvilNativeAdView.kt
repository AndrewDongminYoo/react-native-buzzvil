package com.buzzvil

import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.core.view.doOnLayout
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

class BuzzvilNativeAdView(
  context: ThemedReactContext,
) : FrameLayout(context) {
  // Plain private fields + explicit setters. Do NOT use `var x; private set` —
  // its generated setX(String) would clash with the fun setX(String) below.
  private var unitId: String? = null
  private var layoutVariant: String = "300x250"

  @Volatile private var disposed = false

  private var buzzNative: BuzzNative? = null
  private var binder: BuzzNativeViewBinder? = null

  // The (unitId, layoutVariant) pair the in-flight / loaded ad was configured
  // with. Doubles as the reload guard: an in-place prop change must (re)load
  // (mirrors iOS's `_loadedUnitId` comparison). Cleared in cleanup() so a recycled
  // view can load again — never latched permanently. Keyed on the pair so that a
  // layoutVariant-only change re-binds with the new layout instead of being
  // silently ignored.
  private var loadedKey: String? = null

  // Setters STORE ONLY — they must not trigger a load. React applies unitId and
  // layout through separate @ReactProp setters; loading from each one would, on a
  // render that changes both, fire an intermediate load for the first-delivered
  // prop paired with the stale other prop (an extra ad request for a combination
  // JS never rendered). The manager drives the single load from
  // onAfterUpdateTransaction, once the whole prop batch has settled.
  fun setUnitId(id: String) {
    unitId = id.ifEmpty { null }
  }

  fun setLayoutVariant(v: String) {
    layoutVariant = v
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    loadIfReady()
  }

  // Fabric sets props in any order, and the view may not be attached when the
  // unitId arrives — every entry point calls this. Guard on a key comparison
  // (mirrors iOS): (re)load only when a non-null unitId is present, the view is
  // attached, and the (id, layoutVariant) pair actually changed — so an in-place
  // prop change on a mounted view reloads instead of being ignored, and a
  // layoutVariant-only change still re-binds with the new layout.
  // Called from onAttachedToWindow and from the manager's onAfterUpdateTransaction
  // (after a prop batch settles). The key guard makes repeat calls a no-op, so
  // driving it from both entry points is safe.
  internal fun loadIfReady() {
    val id = unitId ?: return
    if (!isAttachedToWindow) return
    val key = "$id|$layoutVariant"
    if (key == loadedKey) return
    loadedKey = key

    // Tear down any previous ad before the new load (mirrors cleanup()'s
    // teardown); a unitId change on a mounted view reuses this same object.
    binder?.unbind()
    binder?.dispose()
    binder = null
    buzzNative = null
    removeAllViews()
    // Re-arm the in-flight guard so the new load's callbacks (and the
    // doOnLayout size emit) are not blocked by a previous cleanup()/load.
    disposed = false

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

        override fun onRewarded(
          ad: BuzzNativeAd,
          result: BuzzRewardResult,
        ) {
          val payload = Arguments.createMap()
          payload.putBoolean("success", result == BuzzRewardResult.SUCCESS)
          emit("topRewarded", payload)
        }
      },
    )

    buzz.load(
      { _ ->
        // Inflate + bind must touch views on the UI thread. Re-check the reload
        // guard on the UI thread (mirrors iOS): a late callback from a previous
        // load must bail when `loadedKey` has since changed, otherwise it would
        // bind a stale ad and double-emit.
        UiThreadUtil.runOnUiThread {
          if (disposed || key != loadedKey) return@runOnUiThread
          bindLoadedAd(buzz)
        }
      },
      { error ->
        // Marshal to the UI thread for symmetry with the success path; the SDK
        // gives no thread guarantee for these callbacks.
        UiThreadUtil.runOnUiThread {
          if (disposed || key != loadedKey) return@runOnUiThread
          val payload = Arguments.createMap()
          payload.putString("code", error.type.name)
          payload.putString("message", error.message ?: error.type.name)
          emit("topAdFailed", payload)
        }
      },
    )
  }

  // Two layout families: compact horizontal banner (no media) for the small
  // inventory sizes, the vertical media-on-top card for the large ones.
  private fun layoutResFor(variant: String): Int =
    when (variant) {
      "320x50", "320x100", "320x130" -> R.layout.buzzvil_native_ad_banner
      else -> R.layout.buzzvil_native_ad_card
    }

  // Fixed inventory-box height (dp) per exact size. Width comes from the JS
  // `style`. NOTE: under Fabric the host frame is ultimately driven by the
  // shadow node, so this height is a best-effort hint — see CLAUDE notes / PR.
  private fun heightDpFor(variant: String): Int =
    when (variant) {
      "320x50" -> 50
      "320x100" -> 100
      "320x130" -> 130
      "300x250" -> 250
      "320x480" -> 480
      else -> 250
    }

  private fun bindLoadedAd(buzz: BuzzNative) {
    val adView =
      LayoutInflater
        .from(context)
        .inflate(layoutResFor(layoutVariant), this, false) as BuzzAdView
    removeAllViews()
    addView(adView)

    // Pin the host to the inventory-box height (px from dp); width stays from style.
    val density = resources.displayMetrics.density
    val heightPx = (heightDpFor(layoutVariant) * density).toInt()
    layoutParams =
      (
        layoutParams ?: FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.MATCH_PARENT,
          heightPx,
        )
      ).apply { height = heightPx }

    val media = adView.findViewById<BuzzMediaView>(R.id.buzz_media)
    val icon = adView.findViewById<ImageView>(R.id.buzz_icon)
    val title = adView.findViewById<TextView>(R.id.buzz_title)
    val desc = adView.findViewById<TextView>(R.id.buzz_desc)
    val cta = adView.findViewById<DefaultBuzzCtaView>(R.id.buzz_cta)

    binder =
      BuzzNativeViewBinder
        .Builder()
        .buzzNativeAdView(adView)
        .buzzMediaView(media)
        .iconImageView(icon)
        .titleTextView(title)
        .descriptionTextView(desc)
        .buzzCtaView(cta)
        .build()
    // bind() takes the BuzzNative loader, not the loaded BuzzNativeAd.
    binder?.bind(buzz)

    // Emit the REAL measured size, not the pre-layout {0,0}. doOnLayout fires
    // once on the next layout pass (it self-removes), so this emits exactly once
    // per load with non-zero dimensions.
    doOnLayout {
      if (disposed) return@doOnLayout
      // getWidth()/getHeight() are physical pixels; RN's coordinate system is
      // DP/points, so divide by display density to match iOS (which emits
      // UIKit points). Same `displayMetrics.density` used for the fixed-height
      // calc above.
      val density = resources.displayMetrics.density
      val payload = Arguments.createMap()
      payload.putDouble("width", width / density.toDouble())
      payload.putDouble("height", height / density.toDouble())
      emit("topAdLoaded", payload)
    }
  }

  private fun emit(
    eventName: String,
    payload: WritableMap,
  ) {
    val reactContext = context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id) ?: return
    dispatcher.dispatchEvent(BuzzvilAdEvent(surfaceId, id, eventName, payload))
  }

  fun cleanup() {
    disposed = true
    binder?.unbind()
    binder?.dispose()
    binder = null
    buzzNative = null
    // Clear the reload guard for recycle symmetry with iOS (prepareForRecycle):
    // a reused view must be able to load again.
    loadedKey = null
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
