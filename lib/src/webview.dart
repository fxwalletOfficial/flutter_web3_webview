import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_web3_webview/src/config/type.dart';
import 'package:flutter_web3_webview/src/config/params.dart';
import 'package:flutter_web3_webview/src/models/js_add_eth_chain.dart';
import 'package:flutter_web3_webview/src/models/js_callback_data.dart';
import 'package:flutter_web3_webview/src/models/js_transaction.dart';
import 'package:flutter_web3_webview/src/models/settings.dart';
import 'package:uuid/uuid.dart';

class Web3Webview extends StatefulWidget {
  final int? windowId;

  final Web3Settings? settings;

  final WebviewType? type;
  final URLRequest? initialUrlRequest;
  final InAppWebViewSettings? initialSettings;
  final PullToRefreshController? pullToRefreshController;
  final void Function(InAppWebViewController)? onWebViewCreated;
  final Future<PermissionResponse?> Function(InAppWebViewController controller, PermissionRequest request)? onPermissionRequest;
  final void Function(InAppWebViewController controller, int value)? onProgressChanged;
  final void Function(InAppWebViewController controller, String? value)? onTitleChanged;
  final void Function(InAppWebViewController controller, WebUri? uri, bool? isReload)? onUpdateVisitedHistory;
  final void Function(InAppWebViewController controller, WebUri? uri)? onLoadStart;
  final void Function(InAppWebViewController controller, WebUri? uri)? onLoadStop;
  final void Function(InAppWebViewController controller, WebResourceRequest request, WebResourceError error)? onReceivedError;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;
  final void Function(InAppWebViewController controller, ConsoleMessage message)? onConsoleMessage;
  final Future<bool> Function(InAppWebViewController controller, CreateWindowAction action)? onCreateWindow;
  final Future<NavigationActionPolicy?> Function(InAppWebViewController, NavigationAction action)? shouldOverrideUrlLoading;

  final Future<List<String>> Function()? ethAccounts;
  final Future<int> Function()? ethChainId;
  final Future<String> Function(JsTransactionObject data)? ethSendTransaction;
  final Future<String> Function(String data)? ethSign;
  final Future<String> Function(String data)? ethPersonalSign;
  final Future<String> Function(String data)? ethSignTypedData;
  final Future<bool> Function(JsAddEthereumChain data)? walletSwitchEthereumChain;
  final Future<String> Function()? solAccount;
  final Future<String> Function(JsCallBackData data)? solSignTransaction;
  final Future<String> Function(JsCallBackData data)? solSignMessage;
  final Future<dynamic> Function(JsCallBackData data)? onDefaultCallback;

  const Web3Webview({
    super.key,
    this.settings,
    this.windowId,
    this.type = WebviewType.WEB3,
    this.initialUrlRequest,
    this.initialSettings,
    this.pullToRefreshController,
    this.onWebViewCreated,
    this.onPermissionRequest,
    this.onProgressChanged,
    this.onTitleChanged,
    this.onUpdateVisitedHistory,
    this.onLoadStart,
    this.onLoadStop,
    this.onReceivedError,
    this.gestureRecognizers,
    this.onConsoleMessage,
    this.onCreateWindow,
    this.shouldOverrideUrlLoading,

    this.ethAccounts,
    this.ethChainId,
    this.ethSendTransaction,
    this.ethSign,
    this.ethPersonalSign,
    this.ethSignTypedData,
    this.walletSwitchEthereumChain,

    this.solAccount,
    this.solSignTransaction,
    this.solSignMessage,

    this.onDefaultCallback
  });

  @override
  Web3WebviewState createState() => Web3WebviewState();
}

class Web3WebviewState extends State<Web3Webview> {
  /// EIP-6369 uuid.
  String _uuid = '';
  String get uuid {
    if (_uuid.isEmpty) _uuid = const Uuid().v4();
    return _uuid;
  }

  bool get isWeb3 => widget.type == WebviewType.WEB3;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      windowId: widget.windowId,
      initialUrlRequest: widget.initialUrlRequest,
      initialSettings: widget.initialSettings ?? DEFAULT_SETTINGS,
      pullToRefreshController: widget.pullToRefreshController,
      onWebViewCreated: widget.onWebViewCreated,
      onPermissionRequest: widget.onPermissionRequest ?? DEFAULT_PERMISSION_REQUEST,
      onProgressChanged: widget.onProgressChanged,
      onTitleChanged: widget.onTitleChanged,
      onUpdateVisitedHistory: widget.onUpdateVisitedHistory,
      onLoadStart: _onLoadStart,
      onLoadStop: _onLoadStop,
      onReceivedError: widget.onReceivedError,
      gestureRecognizers: widget.gestureRecognizers,
      onConsoleMessage: widget.onConsoleMessage,
      onCreateWindow: widget.onCreateWindow,
      shouldOverrideUrlLoading: widget.shouldOverrideUrlLoading
    );
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? uri) {
    _initWeb3(controller, false);
    if (widget.onLoadStart != null) widget.onLoadStart!(controller, uri);
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? uri) {
    _initWeb3(controller, true);
    if (widget.onLoadStop != null) widget.onLoadStop!(controller, uri);
  }

  Future<void> _initWeb3(InAppWebViewController controller, bool reInit) async {
    if (!isWeb3) return;

    await controller.injectJavascriptFileFromAsset(assetFilePath: 'packages/flutter_web3_webview/js/provider.min.js');
    await controller.evaluateJavascript(source: _getInitJs(reInit));

    if (controller.hasJavaScriptHandler(handlerName: 'FxWalletHandler')) return;
    controller.addJavaScriptHandler(handlerName: 'FxWalletHandler', callback: (args) => _onHandleCallback(args, controller));
  }

  String _getInitJs(bool reInit) {
    return '''
      (function() {
        if ($reInit && window.ethereum != null) return;

        const config = {
          ethereum: {
            chainId: ${widget.settings?.eth?.chainId ?? 1},
            isMetamask: false
          },
          solana: {
            cluster: 'mainnet-beta',
            icon: '${widget.settings?.sol?.icon ?? WALLET_ICON}',
            name: '${widget.settings?.name ?? WALLET_NAME}'
          },
          isDebug: false
        };

        fxwallet.ethereum = new fxwallet.Provider(config);
        fxwallet.solana = new window.fxwallet.SolanaProvider(config);

        window.ethereum = fxwallet.ethereum;

        const event = new CustomEvent('eip6963:announceProvider', {
          detail: {
            info: {
              uuid: '$uuid',
              name: '${widget.settings?.name ?? WALLET_NAME}',
              icon: '${widget.settings?.eth?.icon ?? ''}',
              rdns: '${widget.settings?.eth?.rdns ?? ''}'
            },
            provider: fxwallet.ethereum
          }
        });

        window.dispatchEvent(event);
        window.addEventListener('eip6963:requestProvider', () => {
          window.dispatchEvent(event);
        });

      })();
    ''';
  }

  Future<dynamic> _onHandleCallback(List args, InAppWebViewController controller) async {
    final item = JsCallBackData.fromData(args);

    switch (item.method) {
      case 'eth_accounts':
      case 'eth_requestAccounts':
        return _ethAccounts();

      case 'eth_chainId':
        return _ethChainId();

      case 'eth_sendTransaction':
        return _ethSendTransaction(item);

      case 'eth_sign':
        return _ethSign(item);

      case 'personal_sign':
        return _personalSign(item);

      case 'eth_signTypedData':
      case 'eth_signTypedData_v3':
      case 'eth_signTypedData_v4':
        return _ethSignTypedData(item);

      case 'wallet_switchEthereumChain':
      case 'wallet_addEthereumChain':
        return _walletSwitchEthereumChain(item, controller);

      case 'solana_account':
        return _solAccount();

      case 'solana_signTransaction':
        return _solSignTransaction(item);

      case 'solana_signMessage':
        return _solSignMessage(item);

      default:
        return _onDefaultCallback(item);
    }
  }

  Future<List<String>> _ethAccounts() async {
    if (widget.ethAccounts == null) throw Exception('Invalid wallet');
    return widget.ethAccounts!();
  }

  Future<String> _ethChainId() async {
    if (widget.ethChainId == null) throw Exception('Invalid wallet');

    final id = await widget.ethChainId!();
    return '0x${id.toRadixString(16)}';
  }

  Future<String> _ethSendTransaction(JsCallBackData data) async {
    if (widget.ethSendTransaction == null) throw Exception('Invalid wallet');

    final params = data.getTxParams();
    return widget.ethSendTransaction!(params);
  }

  Future<String> _ethSign(JsCallBackData data) async {
    if (widget.ethSign == null) throw Exception('Invalid wallet');

    final params = data.getEthSignMsg();
    return widget.ethSign!(params);
  }

  Future<String> _personalSign(JsCallBackData data) async {
    if (widget.ethPersonalSign == null) throw Exception('Invalid wallet');

    final params = data.getPersonalSignMsg();
    return widget.ethPersonalSign!(params);
  }

  Future<String> _ethSignTypedData(JsCallBackData data) async {
    if (widget.ethSignTypedData == null) throw Exception('Invalid wallet');

    final params = data.getSignTypedDataParams();
    return widget.ethSignTypedData!(params);
  }

  Future<String> _walletSwitchEthereumChain(JsCallBackData data, InAppWebViewController controller) async {
    if (widget.walletSwitchEthereumChain == null) throw Exception('Invalid wallet');

    final params = data.getChainParams();
    final result = await widget.walletSwitchEthereumChain!(params);
    if (!result) throw Exception({'code': 4092});

    await controller.evaluateJavascript(source: 'window.ethereum.emitChainChanged(${params.chainId}})');
    return _ethChainId();
  }

  Future<String> _solAccount() async {
    if (widget.solAccount == null) throw Exception('Invalid wallet');
    return widget.solAccount!();
  }

  Future<String> _solSignTransaction(JsCallBackData data) async {
    if (widget.solSignTransaction == null) throw Exception('Invalid wallet');
    return widget.solSignTransaction!(data);
  }

  Future<String> _solSignMessage(JsCallBackData data) async {
    if (widget.solSignMessage == null) throw Exception('Invalid wallet');
    return widget.solSignMessage!(data);
  }

  Future<dynamic> _onDefaultCallback(JsCallBackData data) async {
    if (widget.onDefaultCallback == null) throw Exception('Invalid wallet');
    return widget.onDefaultCallback!(data);
  }
}
