import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import '../services/constant.dart';

/// Preloader and initializer for desktop Linux libmpv audio engine
class LinuxAudioInit {
  LinuxAudioInit._();

  static bool _initialized = false;

  static const List<String> _deps = [
    'liblua5.2.so.0',
    'liblua5.2-c++.so.0',
    'libmujs.so.3',
    'libsndio.so.7.3',
    'libsixel.so.1.0.0',
    'libXpresent.so.1.0.0',
    'libXss.so.1.0.0',
    'libopenal.so.1.25.1',
    'libjack.so.0.1.0',
    'libjackserver.so.0.1.0',
    'libjacknet.so.0.1.0',
    'libdc1394.so.25.0.0',
    'libva-wayland.so.2.2300.0',
    'libavdevice.so.62.1.100',
    'libmpv.so.2.5.0',
  ];

  static void ensureInitialized() {
    if (_initialized || !Constant.isDesktop) return;

    if (!Platform.isLinux) {
      try {
        JustAudioMediaKit.ensureInitialized(
          linux: false,
          windows: true,
        );
        JustAudioMediaKit.title = 'Villupaatukaran';
        JustAudioMediaKit.protocolWhitelist = ['http', 'https', 'file'];
        _initialized = true;
      } catch (e) {
        debugPrint('[AudioInit] Windows/Desktop init note: $e');
      }
      return;
    }

    try {
      String? exeDir;
      try {
        exeDir = File(Platform.resolvedExecutable).parent.path;
      } catch (_) {}

      final candidates = [
        if (exeDir != null) '$exeDir/lib/libmpv.so',
        if (exeDir != null) '$exeDir/lib/libmpv.so.2',
        '/home/gokul/Dev/Github/self/villupaatukaaran/linux/lib/libmpv.so',
        '/home/gokul/Dev/Github/self/villupaatukaaran/linux/lib/libmpv.so.2',
        'linux/lib/libmpv.so',
        '/usr/lib/x86_64-linux-gnu/libmpv.so',
        '/usr/lib/x86_64-linux-gnu/libmpv.so.2',
      ];

      String? mpvPath;
      for (final p in candidates) {
        if (File(p).existsSync()) {
          mpvPath = p;
          break;
        }
      }

      if (mpvPath != null) {
        final libDir = File(mpvPath).parent.path;
        for (final dep in _deps) {
          final p = '$libDir/$dep';
          if (File(p).existsSync()) {
            try {
              DynamicLibrary.open(p);
            } catch (e) {
              debugPrint('[LinuxAudioInit] Note preloading $dep: $e');
            }
          }
        }
      }

      debugPrint('[LinuxAudioInit] Initializing JustAudioMediaKit with libmpv: $mpvPath');
      JustAudioMediaKit.ensureInitialized(
        linux: true,
        windows: true,
        libmpv: mpvPath,
      );
      JustAudioMediaKit.title = 'Villupaatukaran';
      JustAudioMediaKit.protocolWhitelist = ['http', 'https', 'file'];
      _initialized = true;
    } catch (e) {
      debugPrint('[LinuxAudioInit] JustAudioMediaKit init note: $e');
    }
  }
}

