/**
 * Public, friendly types for the Buzzvil wrapper. These are the types
 * consumers see; the native spec (`./NativeBuzzvil`) uses primitives only and
 * the wrapper (`./buzzvil.native.tsx`) maps between the two.
 */

/** Optional demographic hint used by Buzzvil for ad targeting. */
export type BuzzvilGender = 'MALE' | 'FEMALE';

/** A Buzzvil user. Only `userId` is required; the rest improve targeting. */
export interface BuzzvilUser {
  /** Non-identifiable, persistent user id. ASCII, max 255 chars. */
  userId: string;
  gender?: BuzzvilGender;
  /** 4-digit birth year, e.g. `1990`. */
  birthYear?: number;
}

/**
 * Interstitial presentation style. `'dialog'` → `BuzzInterstitial.buildDialog()`;
 * `'bottomSheet'` → `.buildBottomSheet()`. Carried to native as a plain string.
 */
export type InterstitialType = 'dialog' | 'bottomSheet';

/**
 * Named BenefitHub pages. Pass via `BenefitHubOptions.page` or use the
 * corresponding convenience function (`showLuckyBox()`).
 *
 * - `'luckyBox'`    → `BuzzBenefitHubPage.LUCKY_BOX` (Android) / `.luckyBox` (iOS)
 * - `'missionPack'` → `BuzzBenefitHubPage.MISSION_PACK` / `.missionPack`
 * - `'history'`     → `BuzzBenefitHubPage.HISTORY` / `.history`
 *   (equivalent to `showHistory: true`)
 */
export type BenefitHubPage = 'luckyBox' | 'missionPack' | 'history';

/** Options for presenting the BenefitHub (offerwall). */
export interface BenefitHubOptions {
  /** BenefitHub page number from the Buzzvil admin (advanced routing). */
  routePath?: string;
  /**
   * Open directly on the history/earnings page. Equivalent to the newer
   * `page: 'history'`.
   */
  showHistory?: boolean;
  /**
   * Open directly on a named BenefitHub page. Takes precedence over
   * `routePath` and `showHistory` when provided.
   */
  page?: BenefitHubPage;
}

/** Supported Native-ad layout sizes (width x height in dp). */
export type BuzzvilNativeAdLayout =
  | '320x50'
  | '320x100'
  | '320x130'
  | '300x250'
  | '320x480';

/** Supported BuzzBanner sizes. */
export type BannerSize = 'W320XH50' | 'W320XH100';

/** Friendly props for the `BuzzBanner` (`BuzzBannerView`) Fabric component. */
export interface BuzzBannerProps {
  placementId: string;
  size: BannerSize;
  style?: import('react-native').StyleProp<import('react-native').ViewStyle>;
  onLoaded?: () => void;
  onFailed?: (e: { code: string; message: string }) => void;
  onClicked?: () => void;
}

/** Friendly props for the `BuzzFlexAdView` Fabric component. */
export interface BuzzFlexAdProps {
  unitId: string;
  primaryColor?: import('react-native').ColorValue;
  style?: import('react-native').StyleProp<import('react-native').ViewStyle>;
  onLoaded?: () => void;
  onFailed?: (e: { code: string; message: string }) => void;
  onClicked?: () => void;
}

/** Friendly props for the `BuzzvilNativeAdView` Fabric component. */
export interface BuzzvilNativeAdViewProps {
  unitId: string;
  layout?: BuzzvilNativeAdLayout;
  style?: import('react-native').StyleProp<import('react-native').ViewStyle>;
  onAdLoaded?: (e: { width: number; height: number }) => void;
  onAdFailed?: (e: { code: string; message: string }) => void;
  onAdClicked?: () => void;
  onImpressed?: () => void;
  onRewarded?: (e: { success: boolean }) => void;
}
