import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef OnSendVoice = void Function(String audioUrl);

class VoiceRecorderSection extends StatefulWidget {
  final OnSendVoice onSend;

  const VoiceRecorderSection({super.key, required this.onSend});

  @override
  State<VoiceRecorderSection> createState() => _VoiceRecorderSectionState();
}

class _VoiceRecorderSectionState extends State<VoiceRecorderSection> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(), path: path);
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (mounted) setState(() {_isRecording = false; _isUploading = true;});

    if (path == null) {
      if (mounted) setState(() => _isUploading = false);
      return;
    }

    try {
      final bytes = await File(path).readAsBytes();
      final fileName =
          'voice_messages/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final client = Supabase.instance.client;
      await client.storage.from('run-interactions').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'audio/m4a'),
      );
      final url = client.storage
          .from('run-interactions')
          .getPublicUrl(fileName);
      widget.onSend(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du vocal')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() {_isRecording = false; _seconds = 0;});
  }

  String get _formattedSeconds {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isRecording) {
      return Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18),
          const SizedBox(width: 6),
          Text(_formattedSeconds),
          const Spacer(),
          TextButton(
            onPressed: _cancel,
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _stopAndSend,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Envoyer'),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic),
      label: const Text('Enregistrer un vocal'),
    );
  }
}
