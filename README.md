# react-native-buzzvil

Get started with effective app monetization using the integration guide and API reference provided by Buzzvil, the No. 1 mobile app rewards advertising platform.

## Installation

```sh
npm install @dongminyu/react-native-buzzvil
```

## Usage

```js
import {
  initialize,
  login,
  logout,
  isLoggedIn,
  showBenefitHub,
} from '@dongminyu/react-native-buzzvil';

// Call once at app startup, before any other method:
initialize('YOUR_BUZZVIL_APP_ID');

// Log a user in (gender / birthYear are optional):
await login({ userId: 'user-123', gender: 'MALE', birthYear: 1990 });

// Present the BenefitHub (offerwall):
showBenefitHub();

// Session helpers:
const loggedIn = await isLoggedIn();
logout();
```

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
