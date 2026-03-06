import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'inji_flutter_sdk_platform_interface.dart';

/// An implementation of [InjiFlutterSdkPlatform] that uses method channels.
class MethodChannelInjiFlutterSdk extends InjiFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('inji_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
