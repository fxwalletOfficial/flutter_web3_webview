# flutter_web3_webview

A webview which support wallet connect to web3 DApp in Flutter.
Now support **EVM chain**, **Solana**.

## Getting Started

### Import
```yaml
dependencies
  ...
  flutter_web3_webview: ^1.0.0
  ...
```

### Use
```dart
/// Init provider js asset before use.
await Web3Webview.initJs();

/// Use
Web3Webview();
```
