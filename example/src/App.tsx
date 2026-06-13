import { useEffect, useState, type ReactNode } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  BuzzBanner,
  BuzzFlexAd,
  BuzzvilNativeAdView,
  addInterstitialClosedListener,
  initialize,
  loadEntryPoints,
  loadInterstitial,
  login,
  showEntryPointBottomSheet,
  showEntryPointPopup,
  showInterstitial,
  showLuckyBox,
  type BannerSize,
  type BuzzvilNativeAdLayout,
  type InterstitialType,
} from 'react-native-buzzvil-ad';

// These come from the Buzzvil admin and are REQUIRED for an ad to load.
// Replace the placeholders with your real values before running on a device.
const BUZZVIL_APP_ID = 'YOUR_APP_ID';
// from Buzzvil admin; required only for BuzzBanner (Android).
const BUZZVIL_APP_SECRET = 'YOUR_BUZZVIL_APP_SECRET';
const BUZZVIL_UNIT_ID = 'YOUR_NATIVE_UNIT_ID';
// Interstitial uses its own unit id, distinct from the native-ad unit above.
const BUZZVIL_INTERSTITIAL_UNIT_ID = 'YOUR_INTERSTITIAL_UNIT_ID';
// BuzzBanner placement id from the Buzzvil admin (distinct from the unit ids above).
const BUZZVIL_BANNER_PLACEMENT_ID = 'YOUR_BANNER_PLACEMENT_ID';
// FlexAd uses its own unit id, distinct from the unit ids above.
const BUZZVIL_FLEX_AD_UNIT_ID = 'YOUR_FLEX_AD_UNIT_ID';

const LAYOUTS: BuzzvilNativeAdLayout[] = [
  '320x50',
  '320x100',
  '320x130',
  '300x250',
  '320x480',
];

const INTERSTITIAL_TYPES: InterstitialType[] = ['dialog', 'bottomSheet'];

const BANNER_SIZES: BannerSize[] = ['W320XH50', 'W320XH100'];

/** A visually distinct, titled card grouping one feature's smoke test. */
function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.heading}>{title}</Text>
      {children}
    </View>
  );
}

export default function App() {
  const [layout, setLayout] = useState<BuzzvilNativeAdLayout>('300x250');
  const [interstitialType, setInterstitialType] =
    useState<InterstitialType>('dialog');
  const [bannerSize, setBannerSize] = useState<BannerSize>('W320XH50');
  const [log, setLog] = useState<string[]>([]);

  const append = (line: string) => {
    console.debug(line);
    return setLog((prev) => [
      ...prev,
      `${new Date().toLocaleTimeString()}  ${line}`,
    ]);
  };

  useEffect(() => {
    // login is required before ads will load.
    initialize(BUZZVIL_APP_ID, BUZZVIL_APP_SECRET);
    login({
      userId: '9cfe5338-ea71-4208-b622-6ceb0df3d44b',
      gender: 'MALE',
      birthYear: 1994,
    })
      .then(() => append('login ok'))
      .catch((e: unknown) => append(`login failed: ${String(e)}`));
  }, []);

  useEffect(() => {
    const sub = addInterstitialClosedListener(
      BUZZVIL_INTERSTITIAL_UNIT_ID,
      () => append('onInterstitialClosed')
    );
    return sub.remove;
  }, []);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.container}>
      <Section title="Buzzvil Native Ad — smoke test">
        <View style={styles.picker}>
          {LAYOUTS.map((value) => {
            const selected = value === layout;
            return (
              <Pressable
                key={value}
                onPress={() => setLayout(value)}
                style={[styles.chip, selected && styles.chipSelected]}
              >
                <Text
                  style={[styles.chipText, selected && styles.chipTextSelected]}
                >
                  {value}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.adArea}>
          <BuzzvilNativeAdView
            // Remount on layout change so a fresh load runs per size.
            key={layout}
            unitId={BUZZVIL_UNIT_ID}
            layout={layout}
            onAdLoaded={(e) =>
              append(`onAdLoaded {w:${e.width}, h:${e.height}}`)
            }
            onAdFailed={(e) =>
              append(`onAdFailed {code:${e.code}, message:${e.message}}`)
            }
            onAdClicked={() => append('onAdClicked')}
            onImpressed={() => append('onImpressed')}
            onRewarded={(e) => append(`onRewarded {success:${e.success}}`)}
          />
        </View>
      </Section>

      <Section title="Interstitial — smoke test">
        <View style={styles.picker}>
          {INTERSTITIAL_TYPES.map((value) => {
            const selected = value === interstitialType;
            return (
              <Pressable
                key={value}
                onPress={() => setInterstitialType(value)}
                style={[styles.chip, selected && styles.chipSelected]}
              >
                <Text
                  style={[styles.chipText, selected && styles.chipTextSelected]}
                >
                  {value}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.buttonRow}>
          <Pressable
            style={styles.button}
            onPress={() =>
              loadInterstitial(BUZZVIL_INTERSTITIAL_UNIT_ID, interstitialType)
                .then(() => append('interstitial loaded'))
                .catch((e: unknown) =>
                  append(`interstitial load failed: ${String(e)}`)
                )
            }
          >
            <Text style={styles.buttonText}>Load</Text>
          </Pressable>
          <Pressable
            style={styles.button}
            onPress={() => {
              append('interstitial show requested');
              showInterstitial(BUZZVIL_INTERSTITIAL_UNIT_ID);
            }}
          >
            <Text style={styles.buttonText}>Show</Text>
          </Pressable>
        </View>
      </Section>

      <Section title="BuzzBanner — smoke test">
        <View style={styles.picker}>
          {BANNER_SIZES.map((value) => {
            const selected = value === bannerSize;
            return (
              <Pressable
                key={value}
                onPress={() => setBannerSize(value)}
                style={[styles.chip, selected && styles.chipSelected]}
              >
                <Text
                  style={[styles.chipText, selected && styles.chipTextSelected]}
                >
                  {value}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.adArea}>
          <BuzzBanner
            // Remount on size change so a fresh load runs per size.
            key={bannerSize}
            placementId={BUZZVIL_BANNER_PLACEMENT_ID}
            size={bannerSize}
            style={
              bannerSize === 'W320XH50'
                ? styles.bannerW320XH50
                : styles.bannerW320XH100
            }
            onLoaded={() => append('banner onLoaded')}
            onFailed={(e) =>
              append(`banner onFailed {code:${e.code}, message:${e.message}}`)
            }
            onClicked={() => append('banner onClicked')}
          />
        </View>
      </Section>

      <Section title="FlexAd — smoke test">
        <View style={styles.adArea}>
          <BuzzFlexAd
            unitId={BUZZVIL_FLEX_AD_UNIT_ID}
            style={styles.flexAd}
            onLoaded={() => append('flexAd onLoaded')}
            onFailed={(e) =>
              append(`flexAd onFailed {code:${e.code}, message:${e.message}}`)
            }
            onClicked={() => append('flexAd onClicked')}
          />
        </View>
      </Section>

      <Section title="LuckyBox — smoke test">
        <View style={styles.buttonRow}>
          <Pressable
            style={styles.button}
            onPress={() => {
              append('luckyBox show requested');
              showLuckyBox();
            }}
          >
            <Text style={styles.buttonText}>Open LuckyBox</Text>
          </Pressable>
        </View>
      </Section>

      <Section title="EntryPoint — smoke test">
        <View style={styles.buttonRow}>
          <Pressable
            style={styles.button}
            onPress={() =>
              loadEntryPoints()
                .then((types) =>
                  append(`entryPoints loaded: [${types.join(', ')}]`)
                )
                .catch((e: unknown) =>
                  append(`entryPoints load failed: ${String(e)}`)
                )
            }
          >
            <Text style={styles.buttonText}>Load</Text>
          </Pressable>
          <Pressable
            style={styles.button}
            onPress={() => {
              append('entryPoint popup show requested');
              showEntryPointPopup();
            }}
          >
            <Text style={styles.buttonText}>Popup</Text>
          </Pressable>
          <Pressable
            style={styles.button}
            onPress={() => {
              append('entryPoint bottomSheet show requested');
              showEntryPointBottomSheet();
            }}
          >
            <Text style={styles.buttonText}>BottomSheet</Text>
          </Pressable>
        </View>
      </Section>

      <Section title="Event log">
        <ScrollView
          style={styles.logBox}
          contentContainerStyle={styles.logContent}
          nestedScrollEnabled
        >
          {log.length === 0 ? (
            <Text style={styles.logEmpty}>No events yet.</Text>
          ) : (
            log.map((line, i) => (
              <Text key={i} style={styles.logLine}>
                {line}
              </Text>
            ))
          )}
        </ScrollView>
      </Section>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    paddingTop: 64,
    paddingHorizontal: 16,
    paddingBottom: 32,
    gap: 16,
  },
  section: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 12,
    padding: 12,
    gap: 10,
    backgroundColor: '#fafafa',
  },
  heading: {
    fontSize: 16,
    fontWeight: '600',
  },
  picker: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#888',
  },
  chipSelected: {
    backgroundColor: '#222',
    borderColor: '#222',
  },
  chipText: {
    color: '#222',
  },
  chipTextSelected: {
    color: '#fff',
  },
  adArea: {
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 60,
  },
  bannerW320XH50: {
    width: 320,
    height: 50,
  },
  bannerW320XH100: {
    width: 320,
    height: 100,
  },
  // FlexAd content is 16:9; the SDK auto-adds 54 of chrome below (≈20 divider +
  // 34 CTA), so height = width*9/16 + 54 (see docs/specs/buzzvil-sdk-api-mapping.md).
  flexAd: {
    width: 320,
    height: 320 * (9 / 16) + 54,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: '#222',
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
  },
  logBox: {
    // Fixed height (not flex) so the log scrolls independently inside the
    // outer page ScrollView instead of collapsing to zero height.
    height: 200,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    backgroundColor: '#fff',
  },
  logContent: {
    padding: 8,
  },
  logEmpty: {
    color: '#999',
  },
  logLine: {
    fontFamily: 'Courier',
    fontSize: 12,
  },
});
