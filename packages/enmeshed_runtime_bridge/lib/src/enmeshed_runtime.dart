import 'dart:async';
import 'dart:io';

import 'package:enmeshed_runtime_bridge/enmeshed_runtime_bridge.dart';
import 'package:enmeshed_runtime_bridge/src/crypto_bridge.dart';
import 'package:enmeshed_types/enmeshed_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

import 'data_view_expander.dart';
import 'filesystem_adapter.dart';
import 'javascript_handlers.dart';
import 'services/services.dart';
import 'string_processor.dart';
import 'webview_constants.dart' as webview_constants;

typedef RuntimeConfig = ({
  String baseUrl,
  String clientId,
  String clientSecret,
  String applicationId,
  bool useAppleSandbox,
  String databaseFolder,
  Color? androidNotificationColor,
  Map<String, dynamic>? deciderModuleConfig,
});

class EnmeshedRuntime with WidgetsBindingObserver {
  bool _isReady = false;

  bool get isReady => _isReady;

  final RuntimeConfig runtimeConfig;

  late final HeadlessInAppWebView _headlessWebView;
  late final InAppWebViewController _controller;

  final _filesystemAdapter = FilesystemAdapter();
  final _jsToUIBridge = JsToUIBridge();

  final VoidCallback? _runtimeReadyCallback;
  final Future<String?> Function() getPushTokenCallback;

  late final AccountServices _accountServices;
  AccountServices get accountServices => _accountServices;

  late final AnonymousServices _anonymousServices;
  AnonymousServices get anonymousServices => _anonymousServices;

  late final CryptoHandler _cryptoHandler;
  CryptoHandler get cryptoHandler => _cryptoHandler;

  late final StringProcessor _stringProcessor;
  StringProcessor get stringProcessor {
    assert(_isReady, 'Runtime not ready');

    return _stringProcessor;
  }

  final Logger _logger;
  final _runtimeReadyCompleter = Completer();

  final EventBus eventBus;

  String? _runtimeVersion;
  String get runtimeVersion {
    if (_runtimeVersion == null) throw Exception('Runtime version not available');
    return _runtimeVersion!;
  }

  EnmeshedRuntime({
    Logger? logger,
    VoidCallback? runtimeReadyCallback,
    required this.getPushTokenCallback,
    required this.runtimeConfig,
    EventBus? eventBus,
  }) : _logger = logger ?? Logger(printer: SimplePrinter(colors: false)),
       _runtimeReadyCallback = runtimeReadyCallback,
       eventBus = eventBus ?? EventBus() {
    if (runtimeConfig.baseUrl.isEmpty) throw Exception('Missing runtimeConfig value: baseUrl');
    if (runtimeConfig.clientId.isEmpty) throw Exception('Missing runtimeConfig value: clientId');
    if (runtimeConfig.clientSecret.isEmpty) throw Exception('Missing runtimeConfig value: clientSecret');
    if (runtimeConfig.applicationId.isEmpty) throw Exception('Missing runtimeConfig value: applicationId');

    PlatformInAppWebViewController.debugLoggingSettings.excludeFilter.addAll([
      RegExp(r'onConsoleMessage'),
      RegExp(r'handleRuntimeEvent'),
      RegExp(r'runtimeReady'),
      RegExp(r'onReceivedServerTrustAuthRequest'),
      RegExp(r'getRuntimeConfig'),
      RegExp(r'getAppLanguage'),
      RegExp(r'uibridge_'),
      RegExp(r'notifications_'),
      RegExp(r'.*File'),
    ]);

    _headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(isInspectable: kDebugMode),
      initialData: webview_constants.initialData,
      onWebViewCreated: (controller) async {
        _controller = controller;
        _jsToUIBridge.controller = controller;
        await _addJavaScriptHandlers(controller);
        _logger.i('WebView created');
      },
      onConsoleMessage: (_, consoleMessage) {
        _logger.i('js runtime: ${consoleMessage.message}');
      },
      onLoadStop: (controller, _) async {
        await _loadLibs(controller);
      },
    );

    final anonymousEvaluator = Evaluator.anonymous(this);
    _accountServices = AccountServices(anonymousEvaluator);
    _anonymousServices = AnonymousServices(anonymousEvaluator);
    _stringProcessor = StringProcessor(anonymousEvaluator);
    _cryptoHandler = CryptoHandler();
  }

  Session getSession(String accountReference) => Session(Evaluator.account(this, accountReference));

  Future<void> selectAccount(String accountReference) async {
    final result = await _evaluateJavaScript(
      'await runtime.selectAccount(accountReference, password)',
      arguments: {'accountReference': accountReference, 'password': ''},
    );
    result.throwOnError();
  }

  Future<void> _addJavaScriptHandlers(InAppWebViewController controller) async {
    _controller.addJavaScriptHandler(
      handlerName: 'notifications_getPushToken',
      callback: (_) async {
        try {
          final token = await getPushTokenCallback();

          if (token == null) {
            _logger.w('Push token is null');
            return {'ok': false, 'error': 'No Push token is available'};
          }

          return {'ok': true, 'token': token};
        } catch (e) {
          _logger.e('Error getting push token: $e');
          return {'ok': false, 'error': e.toString()};
        }
      },
    );

    controller.addJavaScriptHandler(handlerName: 'handleRuntimeEvent', callback: (args) => handleRuntimeEventCallback(args, eventBus, _logger));

    controller.addJavaScriptHandler(handlerName: 'handleCryptoEvent', callback: (args) => _cryptoHandler.handleCall(args));

    controller.addFilesystemJavaScriptHandlers(_filesystemAdapter);

    controller.addJavaScriptHandler(
      handlerName: 'runtimeReady',
      callback: (_) {
        _isReady = true;

        _loadRuntimeVersion();

        _runtimeReadyCallback?.call();
        _runtimeReadyCompleter.complete();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'runtimeInitFailed',
      callback: (e) {
        print('Runtime init failed: $e');
        _runtimeReadyCompleter.completeError(Exception('Runtime init failed'));
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getRuntimeConfig',
      callback: (_) async => {
        'applicationId': runtimeConfig.applicationId,
        if (Platform.isIOS || Platform.isMacOS) 'applePushEnvironment': runtimeConfig.useAppleSandbox ? 'Development' : 'Production',
        if (Platform.isIOS || Platform.isMacOS) 'pushService': 'apns' else if (Platform.isAndroid) 'pushService': 'fcm' else 'pushService': 'none',
        'transportLibrary': {
          'baseUrl': runtimeConfig.baseUrl,
          'platformClientId': runtimeConfig.clientId,
          'platformClientSecret': runtimeConfig.clientSecret,
        },
        'databaseFolder': runtimeConfig.databaseFolder,
        'modules': {
          if (Platform.isWindows) 'pushNotification': {'enabled': false},
          if (Platform.isWindows) 'sse': {'enabled': true},
          'decider': ?runtimeConfig.deciderModuleConfig,
        },
        'calStoragePath': (await _filesystemAdapter.getDirectoryForStorage('cal')).path,
      },
    );

    controller.addJavaScriptHandler(handlerName: 'getAppLanguage', callback: (_) => WidgetsBinding.instance.platformDispatcher.locale.languageCode);

    await controller.addLocalNotificationsJavaScriptHandlers(runtimeConfig.androidNotificationColor);
  }

  /// Register the [UIBridge] to communicate with the native UI.
  /// This must be called after the runtime is ready.
  Future<void> registerUIBridge(UIBridge uiBridge) async {
    if (!_isReady) {
      throw Exception('Runtime not ready');
    }

    final isFirstRegistration = !_jsToUIBridge.isRegistered;

    _jsToUIBridge.register(uiBridge);

    if (isFirstRegistration) await _evaluateJavaScript('window.registerUIBridge()');
  }

  Future<void> _loadLibs(InAppWebViewController controller) async {
    final assetsFolder = 'packages/enmeshed_runtime_bridge/assets';

    await controller.injectJavascriptFileFromAsset(assetFilePath: '$assetsFolder/loki.js');
    await controller.injectJavascriptFileFromAsset(assetFilePath: '$assetsFolder/index.js');
  }

  Future<VoidResult> run() async {
    WidgetsBinding.instance.addObserver(this);

    try {
      await _headlessWebView.run();
      await _runtimeReadyCompleter.future;

      return VoidResult.success();
    } catch (error) {
      return VoidResult.failure(RuntimeError(message: error.toString(), code: 'error.app.runtimeInitFailed'));
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);

    _isReady = false;
    _controller.dispose();
    await _headlessWebView.dispose();
  }

  Future<CallAsyncJavaScriptResult> _evaluateJavaScript(String source, {Map<String, dynamic> arguments = const <String, dynamic>{}}) async {
    if (!_isReady) {
      throw Exception('Runtime not ready');
    }

    final resultOrNull = await _controller.callAsyncJavaScript(functionBody: source, arguments: arguments);

    if (resultOrNull == null) {
      throw Exception('result is null');
    }

    final result = resultOrNull;
    if (result.value is Map<String, dynamic> || result.value is List<Map<String, dynamic>>) return result;

    if (result.value is Map) result.value = _transformValue(result.value as Map);
    if (result.value is List) result.value = _transformList(result.value as List);

    return result;
  }

  Map<String, dynamic> _transformValue(Map value) {
    final transformedValue = Map<String, dynamic>.from(value);
    for (final entry in transformedValue.entries) {
      if (entry.value is Map) {
        transformedValue[entry.key] = _transformValue(entry.value as Map);
      } else if (entry.value is List) {
        transformedValue[entry.key] = _transformList(entry.value as List);
      }
    }

    return transformedValue;
  }

  List<dynamic> _transformList(List value) {
    return value
        .map(
          (e) => switch (e) {
            final Map m => _transformValue(m),
            final List l => _transformList(l),
            _ => e,
          },
        )
        .toList();
  }

  Future<void> _loadRuntimeVersion() async {
    final result = await _evaluateJavaScript('return window.runtimeVersion');

    if (result.value is String) {
      _runtimeVersion = result.value as String;
    } else {
      _logger.e('error loading runtime version');
    }
  }

  Future<void> triggerRemoteNotificationRegistrationEvent(String token) async {
    assert(_isReady, 'Runtime not ready');

    final result = await _evaluateJavaScript('window.triggerRemoteNotificationRegistrationEvent(token)', arguments: {'token': token});
    result.throwOnError();
  }

  Future<void> triggerRemoteNotificationEvent({
    required Map<String, dynamic> content,
    String? id,
    bool? foreground,
    String? limitedProcessingTime,
  }) async {
    assert(_isReady, 'Runtime not ready');

    final result = await _evaluateJavaScript(
      'window.triggerRemoteNotificationEvent(notification)',
      arguments: {
        'notification': {'content': content, 'id': id, 'foreground': foreground, 'limitedProcessingTime': limitedProcessingTime},
      },
    );
    result.throwOnError();
  }

  Future<List<String>> getEditableAttributes() async {
    assert(_isReady, 'Runtime not ready');

    final result = await _evaluateJavaScript('return window.NMSHDContent.AttributeValues.Identity.Editable.TYPE_NAMES');
    result.throwOnError();

    return List<String>.from(result.value);
  }

  Future<Result<GetHintsResponse>> getHints(String valueType) async {
    final result = await _evaluateJavaScript(
      '''const result = window.getHints(valueType)
      if (result.isError) return { error: { message: result.error.message, code: result.error.code } }
      return { value: result.value }''',
      arguments: {'valueType': valueType},
    );

    final json = result.valueToMap();
    return Result.fromJson(json, (value) => GetHintsResponse.fromJson(value));
  }

  @override
  @protected
  void didChangeLocales(List<Locale>? locales) async {
    if (_isReady || locales == null || locales.isEmpty) return;

    final result = await _evaluateJavaScript('window.triggerAppLanguageChangedEvent(language)', arguments: {'language': locales.first.languageCode});
    result.throwOnError();
  }
}

class Evaluator extends AbstractEvaluator {
  final EnmeshedRuntime _runtime;

  final String? _accountReference;
  final bool _isAnonymous;

  String get sessionEvaluation => (_accountReference == null) ? 'null' : 'await runtime.getOrCreateSession("$_accountReference")';
  String get sessionStorage => _isAnonymous ? '' : 'const session = $sessionEvaluation;\n';

  Evaluator._(this._runtime, {String? accountReference, bool isAnonymous = false}) : _accountReference = accountReference, _isAnonymous = isAnonymous;

  Evaluator.account(EnmeshedRuntime runtime, String accountReference) : this._(runtime, accountReference: accountReference);
  Evaluator.anonymous(EnmeshedRuntime runtime) : this._(runtime, isAnonymous: true);

  @override
  Future<CallAsyncJavaScriptResult> evaluateJavaScript(String source, {Map<String, dynamic> arguments = const <String, dynamic>{}}) async {
    return _runtime._evaluateJavaScript('$sessionStorage$source', arguments: arguments);
  }
}

class Session {
  final TransportServices _transportServices;
  TransportServices get transportServices => _transportServices;

  final ConsumptionServices _consumptionServices;
  ConsumptionServices get consumptionServices => _consumptionServices;

  final DataViewExpander _expander;
  DataViewExpander get expander => _expander;

  Session(AbstractEvaluator evaluator)
    : _transportServices = TransportServices(evaluator),
      _consumptionServices = ConsumptionServices(evaluator),
      _expander = DataViewExpander(evaluator);
}
