import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  BuzzvilNativeAdView,
  initialize,
  login,
  type BuzzvilNativeAdLayout,
} from '@dongminyu/react-native-buzzvil';

// These come from the Buzzvil admin and are REQUIRED for an ad to load.
// Replace the placeholders with your real values before running on a device.
const BUZZVIL_APP_ID = 'YOUR_APP_ID';
const BUZZVIL_UNIT_ID = 'YOUR_NATIVE_UNIT_ID';

const LAYOUTS: BuzzvilNativeAdLayout[] = [
  '320x50',
  '320x100',
  '320x130',
  '300x250',
  '320x480',
];

export default function App() {
  const [layout, setLayout] = useState<BuzzvilNativeAdLayout>('300x250');
  const [log, setLog] = useState<string[]>([]);

  const append = (line: string) =>
    setLog((prev) => [...prev, `${new Date().toLocaleTimeString()}  ${line}`]);

  useEffect(() => {
    // login is required before ads will load.
    initialize(BUZZVIL_APP_ID);
    login({ userId: 'smoke-test-user' })
      .then(() => append('login ok'))
      .catch((e: unknown) => append(`login failed: ${String(e)}`));
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.heading}>Buzzvil Native Ad — smoke test</Text>

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
          onAdLoaded={(e) => append(`onAdLoaded {w:${e.width}, h:${e.height}}`)}
          onAdFailed={(e) =>
            append(`onAdFailed {code:${e.code}, message:${e.message}}`)
          }
          onAdClicked={() => append('onAdClicked')}
          onImpressed={() => append('onImpressed')}
          onRewarded={(e) => append(`onRewarded {success:${e.success}}`)}
        />
      </View>

      <Text style={styles.heading}>Event log</Text>
      <ScrollView
        style={styles.logBox}
        contentContainerStyle={styles.logContent}
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
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 64,
    paddingHorizontal: 16,
    gap: 12,
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
  logBox: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
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
