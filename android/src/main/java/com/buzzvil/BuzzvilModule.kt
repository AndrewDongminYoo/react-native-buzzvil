package com.buzzvil

import android.app.Application
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil

// The Buzzvil class names and import paths below are verified against the
// resolved `com.buzzvil:buzzvil-sdk` AAR (buzzvil-bom 6.7.x) — this module
// compiles cleanly via `:dongminyu_react-native-buzzvil:compileDebugKotlin`.
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
  override fun initialize(appId: String) {
    val application = reactApplicationContext.applicationContext as Application
    val config = BuzzBenefitConfig.Builder(appId).build()
    BuzzvilSdk.initialize(application, config)
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
    interstitials[unitId] = interstitial

    // The SDK listener can fire repeatedly; settle the promise exactly once.
    var settled = false
    interstitial.load(
      object : BuzzInterstitialListener() {
        override fun onAdLoaded() {
          if (settled) return
          settled = true
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
          // Lifecycle: drop the dismissed instance so the map doesn't retain it.
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
