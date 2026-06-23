import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../backend/backend.dart';
import '../store/app_store.dart';

class VoiceRecorderWidget extends StatefulWidget {
  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
  });

  final Function({
    required String audioUrl,
    required String transcript,
    required String translatedText,
  }) onSend;

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isCancelled = false;
  DateTime? _recordStartTime;
  Timer? _timer;
  String _timeStr = '00:00';
  late AnimationController _waveController;
  double _dragPositionX = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _timer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        setState(() {
          _isRecording = true;
          _isCancelled = false;
          _dragPositionX = 0;
          _recordStartTime = DateTime.now();
          _timeStr = '00:00';
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final diff = DateTime.now().difference(_recordStartTime!);
          if (diff.inSeconds >= 120) {
            _stopAndSendRecording();
          } else {
            final mins = diff.inMinutes.toString().padLeft(2, '0');
            final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
            setState(() {
              _timeStr = '$mins:$secs';
            });
          }
        });

        await _recorder.start(
          RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Start recording error: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _timer?.cancel();
    if (!_isRecording) return;

    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (_isCancelled || path == null) {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      return;
    }

    // Process file
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Show loader dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Transcribing & Translating...'),
                ],
              ),
            ),
          ),
        ),
      );

      final url = await Backend.I.uploadVoiceMessage(filename, bytes);
      final stt = await Backend.I.transcribeAudio(bytes);

      if (mounted) Navigator.pop(context); // close loader

      widget.onSend(
        audioUrl: url,
        transcript: stt['transcript'] ?? '',
        translatedText: stt['translatedText'] ?? '',
      );
    } catch (e) {
      if (kDebugMode) print('Upload & Transcription error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black.withOpacity(0.05),
        child: Row(
          children: [
            // Timer + anim wave
            Text(
              _timeStr,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 40,
                child: CustomPaint(
                  painter: _WavePainter(
                    animationValue: _waveController.value,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            // Cancel Drag Area
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragPositionX += details.primaryDelta ?? 0;
                  if (_dragPositionX < -100) {
                    _isCancelled = true;
                  }
                });
              },
              onHorizontalDragEnd: (_) {
                if (_isCancelled) {
                  _stopAndSendRecording();
                }
              },
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isCancelled ? 0.3 : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                    Text(
                      _isCancelled
                          ? store.getTranslated('delete_voice')
                          : store.getTranslated('voice_cancel_drag'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Release to send
            GestureDetector(
              onTapUp: (_) => _stopAndSendRecording(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopAndSendRecording(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 24),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.animationValue, required this.color});

  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    path.moveTo(0, midY);
    for (double x = 0; x < width; x++) {
      final y = midY +
          math.sin((x / width * 4 * math.pi) + (animationValue * 2 * math.pi)) *
              10 *
              (0.5 + 0.5 * math.sin(x / width * math.pi));
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.transcript,
    this.translatedText,
  });

  final String audioUrl;
  final String? transcript;
  final String? translatedText;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  iconSize: 36,
                  color: primaryColor,
                  onPressed: _togglePlayback,
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 100,
                    value: math.min(
                      _position.inMilliseconds.toDouble(),
                      _duration.inMilliseconds.toDouble() > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 100,
                    ),
                    onChanged: (val) async {
                      await _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Text(
                  '${_position.inSeconds}s',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (widget.transcript != null && widget.transcript!.isNotEmpty)
                  IconButton(
                    icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                  ),
              ],
            ),
          ),
          if (_expanded && widget.transcript != null && widget.transcript!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  Text(
                    store.getTranslated('transcription'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  Text(
                    widget.transcript!,
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  if (widget.translatedText != null && widget.translatedText!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      store.getTranslated('translation'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Text(
                      widget.translatedText!,
                      style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SpeakerTtsButton extends StatefulWidget {
  const SpeakerTtsButton({
    super.key,
    required this.text,
    required this.language,
  });

  final String text;
  final String language;

  @override
  State<SpeakerTtsButton> createState() => _SpeakerTtsButtonState();
}

class _SpeakerTtsButtonState extends State<SpeakerTtsButton> {
  final _player = AudioPlayer();
  bool _speaking = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_speaking) {
      await _player.stop();
      setState(() => _speaking = false);
      return;
    }

    setState(() => _speaking = true);
    try {
      final code = switch (widget.language.toLowerCase()) {
        'kannada' => 'kn-IN',
        'hindi' => 'hi-IN',
        'telugu' => 'te-IN',
        'tamil' => 'ta-IN',
        'malayalam' => 'ml-IN',
        'marathi' => 'mr-IN',
        'gujarati' => 'gu-IN',
        'bengali' => 'bn-IN',
        'punjabi' => 'pa-IN',
        'odia' => 'or-IN',
        'assamese' => 'as-IN',
        'urdu' => 'ur-IN',
        _ => 'en-US',
      };

      final bytes = await Backend.I.synthesizeSpeech(widget.text, code);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);

      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _speaking = false);
      });

      await _player.play(DeviceFileSource(file.path));
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _speaking ? Icons.volume_up : Icons.volume_mute,
        size: 20,
        color: _speaking ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      onPressed: _speak,
    );
  }
}
