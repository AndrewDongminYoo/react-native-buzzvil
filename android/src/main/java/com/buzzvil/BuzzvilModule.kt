package com.buzzvil

import android.app.Application
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil

// The Buzzvil class names and import paths below are verified against the
// resolved `com.buzzvil:buzzvil-sdk` AAR (buzzvil-bom 6.7.x) — this module
// compiles cleanly via `:dongminyu_react-native-buzzvil:compileDebugKotlin`.
import com.buzzvil.buzzbanner.BuzzBanner
import com.buzzvil.buzzbenefit.BuzzBenefitConfig
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHub
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHubConfig
import com.buzzvil.buzzbenefit.benefithub.BuzzBenefitHubPage
import com.buzzvil.buzzbenefit.BuzzAdError
import com.buzzvil.buzzbenefit.interstitial.BuzzInterstitial
import com.buzzvil.buzzbenefit.interstitial.BuzzInterstitialListener
import com.buzzvil.sdk.BuzzvilSdk
import com.buzzvil.sdk.BuzzvilSdkLoginListener
import com.buzzvil.sdk.BuzzvilSdkUser

class BuzzvilModule(
  reactContext: ReactApplicationContext,
) : NativeBuzzvilSpec(reactContext) {
  override fun initialize(
    appId: String,
    appSecret: String,
  ) {
    val application = reactApplicationContext.applicationContext as Application
    val config = BuzzBenefitConfig.Builder(appId).build()
    BuzzvilSdk.initialize(application, config)
    // BuzzBanner needs its own init or the banner view emits
    // onFailed(code="0", "BuzzBanner is not initialized."). The 3-arg init
    // (appId, appSecret, context) is the full one — it both stores the
    // credentials and builds the underlying ad SDK (verified via javap on
    // buzz-banner 6.7.6). Sentinel contract (see NativeBuzzvil.ts): "" appSecret
    // → skip BuzzBanner init (iOS has no separate banner init at all).
    if (appSecret.isNotEmpty()) {
      BuzzBanner().init(appId, appSecret, application)
    }
  }

  override fun login(
    userId: String,
    gender: String,
    birthYear: Double,
    promise: Promise,
  ) {
    // Sentinel contract (see NativeBuzzvil.ts): "" gender / 0 birthYear → unset.
    val user =
      BuzzvilSdkUser(
        userId = userId,
        gender =
          when (gender) {
            "MALE" -> BuzzvilSdkUser.Gender.MALE
            "FEMALE" -> BuzzvilSdkUser.Gender.FEMALE
            else -> BuzzvilSdkUser.Gender.UNKNOWN // sentinel "" → unspecified
          },
        birthYear = if (birthYear > 0) birthYear.toInt() else null,
      )
    BuzzvilSdk.login(
      user,
      object : BuzzvilSdkLoginListener {
        override fun onSuccess() {
          promise.resolve(null)
        }

        override fun onFailure(errorType: BuzzvilSdkLoginListener.ErrorType) {
          promise.reject("buzzvil_login_failed", "Buzzvil login failed: $errorType")
        }
      },
    )
  }

  override fun logout() {
    BuzzvilSdk.logout()
  }

  override fun isLoggedIn(promise: Promise) {
    promise.resolve(BuzzvilSdk.isLoggedIn)
  }

  override fun showBenefitHub(
    routePath: String,
    showHistory: Boolean,
  ) {
    // BenefitHub launches an Activity — must run on the main thread (parity
    // with the iOS dispatch_async(main) path).
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      val configBuilder = BuzzBenefitHubConfig.Builder()
      if (routePath.isNotEmpty()) {
        configBuilder.routePath(routePath)
      }
      if (showHistory) {
        configBuilder.queryParams(BuzzBenefitHubPage.HISTORY.toRedirectQueryParams())
      }
      BuzzBenefitHub.show(activity, configBuilder.build())
    }
  }

  // --- Interstitial ---

  // Design Decision 1: one BuzzInterstitial instance per unitId, so a later
  // showInterstitial(unitId) presents the instance loaded by loadInterstitial.
  private val interstitials = mutableMapOf<String, BuzzInterstitial>()

  override fun loadInterstitial(
    unitId: String,
    type: String,
    promise: Promise,
  ) {
    // Reject a new load while an instance for this unitId already exists — in
    // flight, loaded-and-waiting-to-show, or currently showing (parity with iOS).
    // Overwriting interstitials[unitId] would let the OLD instance's onAdClosed
    // remove the NEW one by unitId, no-op'ing the next show(). The entry is
    // cleared on close/failure, after which a fresh load is allowed.
    if (interstitials.containsKey(unitId)) {
      promise.reject(
        "buzzvil_interstitial_load_failed",
        "An interstitial for this unitId is already loaded or loading; wait for onInterstitialClosed before loading again.",
      )
      return
    }
    // type sentinel: "bottomSheet" → bottom sheet; "dialog"/""/unknown → dialog.
    val builder = BuzzInterstitial.Builder(unitId)
    val interstitial =
      if (type == "bottomSheet") builder.buildBottomSheet() else builder.buildDialog()
    if (interstitial == null) {
      promise.reject(
        "buzzvil_interstitial_load_failed",
        "Failed to build a BuzzInterstitial for unitId=$unitId.",
      )
      return
    }
    // Store from load-start; the guard above keys off its presence, and it's
    // removed on close/failure.
    interstitials[unitId] = interstitial

    // The SDK listener can fire repeatedly; settle the promise exactly once.
    var settled = false
    interstitial.load(
      object : BuzzInterstitialListener() {
        override fun onAdLoaded() {
          if (settled) return
          settled = true
          // Keep the instance in `interstitials` for the later show().
          promise.resolve(null)
        }

        override fun onAdLoadFailed(error: BuzzAdError?) {
          if (settled) return
          settled = true
          interstitials.remove(unitId)
          promise.reject(
            "buzzvil_interstitial_load_failed",
            error?.message ?: error?.type?.toString() ?: "Interstitial load failed.",
          )
        }

        override fun onAdClosed() {
          // New-Arch typed EventEmitter: codegen generates this concrete emit
          // method on the spec base; payload is a flat primitive map.
          emitOnInterstitialClosed(Arguments.createMap().apply { putString("unitId", unitId) })
          // Lifecycle: drop the dismissed instance so the map doesn't retain it
          // (and so a fresh loadInterstitial for this unitId is allowed again).
          interstitials.remove(unitId)
        }
      },
    )
  }

  override fun showInterstitial(unitId: String) {
    // show() presents UI — must run on the main thread (parity with BenefitHub).
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity ?: return@runOnUiThread
      interstitials[unitId]?.show(activity)
    }
  }

  companion object {
    const val NAME = NativeBuzzvilSpec.NAME
  }
}
