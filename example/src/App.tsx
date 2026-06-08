import { useEffect } from 'react';
import { Button, StyleSheet, View } from 'react-native';
import { initialize, showBenefitHub } from '@dongminyu/react-native-buzzvil';

// Replace with your Buzzvil app id (from help@buzzvil.com).
const BUZZVIL_APP_ID = 'YOUR_APP_ID';

export default function App() {
  useEffect(() => {
    initialize(BUZZVIL_APP_ID);
  }, []);

  return (
    <View style={styles.container}>
      <Button title="Open BenefitHub" onPress={() => showBenefitHub()} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
