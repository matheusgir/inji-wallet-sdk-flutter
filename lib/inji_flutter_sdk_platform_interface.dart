import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'inji_flutter_sdk_method_channel.dart';

abstract class InjiFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a InjiFlutterSdkPlatform.
  InjiFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static InjiFlutterSdkPlatform _instance = MethodChannelInjiFlutterSdk();

  /// The default instance of [InjiFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelInjiFlutterSdk].
  static InjiFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [InjiFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(InjiFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
