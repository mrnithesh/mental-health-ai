import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioOutput {
  bool initialized = false;
  AudioSource? stream;
  SoundHandle? handle;
  final int sampleRate = 24000;
  final Channels channels = Channels.mono;
  final BufferType format = BufferType.s16le;

  Future<void> init() async {
    if (initialized) return;

    await SoLoud.instance.init(sampleRate: sampleRate, channels: channels);
    initialized = true;
    debugPrint('AudioOutput: SoLoud initialized');
  }

  Future<void> dispose() async {
    if (initialized) {
      await SoLoud.instance.disposeAllSources();
      SoLoud.instance.deinit();
      initialized = false;
    }
  }

  AudioSource? _setupNewStream() {
    if (!SoLoud.instance.isInitialized) return null;

    stream = SoLoud.instance.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0,
      sampleRate: sampleRate,
      channels: channels,
      format: format,
      onBuffering: (isBuffering, handle, time) {
        debugPrint('AudioOutput buffering: $isBuffering, time: $time');
      },
    );
    return stream;
  }

  Future<AudioSource?> playStream() async {
    final newStream = _setupNewStream();
    if (!SoLoud.instance.isInitialized || newStream == null) return null;

    handle = await SoLoud.instance.play(newStream);
    stream = newStream;
    debugPrint('AudioOutput: stream playback started');
    return stream;
  }

  void addData(Uint8List audioChunk) {
    final currentStream = stream;
    if (currentStream != null) {
      SoLoud.instance.addAudioDataStream(currentStream, audioChunk);
    }
  }

  Future<void> stopStream() async {
    final currentStream = stream;
    final currentHandle = handle;

    if (currentStream == null ||
        currentHandle == null ||
        !SoLoud.instance.getIsValidVoiceHandle(currentHandle)) {
      return;
    }

    SoLoud.instance.setDataIsEnded(currentStream);
    await SoLoud.instance.stop(currentHandle);
    debugPrint('AudioOutput: stream stopped');
  }
}
