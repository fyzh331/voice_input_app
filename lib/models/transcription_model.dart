import 'package:whisper_kit/whisper_kit.dart';

/// 转录结果模型
class TranscriptionResultModel {
  final String text;
  final List<TranscriptionSegment>? segments;
  final DateTime timestamp;
  
  TranscriptionResultModel({
    required this.text,
    this.segments,
    required this.timestamp,
  });
  
  /// 从 Whisper 响应创建
  factory TranscriptionResultModel.fromWhisperResponse(
    WhisperTranscribeResponse response,
  ) {
    return TranscriptionResultModel(
      text: response.text,
      segments: response.segments?.map((s) => TranscriptionSegment(
        text: s.text,
        startTime: s.fromTs.inMilliseconds / 1000.0,
        endTime: s.toTs.inMilliseconds / 1000.0,
      )).toList(),
      timestamp: DateTime.now(),
    );
  }
  
  /// 生成 SRT 字幕
  String toSRT() {
    if (segments == null || segments!.isEmpty) {
      return _generateFallbackSRT();
    }
    
    final buffer = StringBuffer();
    for (int i = 0; i < segments!.length; i++) {
      final seg = segments![i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSRTTime(seg.startTime)} --> ${_formatSRTTime(seg.endTime)}');
      buffer.writeln('${seg.text}\n');
    }
    return buffer.toString();
  }
  
  String _generateFallbackSRT() {
    // 如果没有时间戳，按句子分割估算时间
    final sentences = text.split(RegExp(r'[。！？；]')).where((s) => s.trim().isNotEmpty).toList();
    if (sentences.isEmpty) return '';
    
    final durationPerSentence = 2.5; // 每句2.5秒
    final buffer = StringBuffer();
    
    for (int i = 0; i < sentences.length; i++) {
      final start = i * durationPerSentence;
      final end = start + durationPerSentence;
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSRTTime(start)} --> ${_formatSRTTime(end)}');
      buffer.writeln('${sentences[i].trim()}。\n');
    }
    return buffer.toString();
  }
  
  String _formatSRTTime(double seconds) {
    final hours = (seconds ~/ 3600).toInt();
    final minutes = ((seconds % 3600) ~/ 60).toInt();
    final secs = (seconds % 60).toInt();
    final millis = ((seconds - secs) * 1000).toInt();
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }
  
  /// 生成 LRC 歌词
  String toLRC() {
    if (segments == null || segments!.isEmpty) {
      return _generateFallbackLRC();
    }
    
    final buffer = StringBuffer();
    buffer.writeln('[ti:语音识别结果]');
    buffer.writeln('[ar:离线语音输入法]');
    buffer.writeln('[al:语音转写]');
    buffer.writeln('[by:AI生成]');
    buffer.writeln('[offset:0]\n');
    
    for (final seg in segments!) {
      buffer.writeln('${_formatLRCTime(seg.startTime)}${seg.text}');
    }
    
    final totalDuration = segments!.last.endTime;
    buffer.writeln('\n[length:${totalDuration.toInt()}]');
    return buffer.toString();
  }
  
  String _generateFallbackLRC() {
    final sentences = text.split(RegExp(r'[。！？；]')).where((s) => s.trim().isNotEmpty).toList();
    if (sentences.isEmpty) return '';
    
    final durationPerSentence = 2.5;
    final buffer = StringBuffer();
    buffer.writeln('[ti:语音识别结果]');
    buffer.writeln('[ar:离线语音输入法]\n');
    
    for (int i = 0; i < sentences.length; i++) {
      buffer.writeln('${_formatLRCTime(i * durationPerSentence)}${sentences[i].trim()}。');
    }
    return buffer.toString();
  }
  
  String _formatLRCTime(double seconds) {
    final minutes = (seconds ~/ 60).toInt();
    final secs = seconds % 60;
    return '[${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(3).padLeft(6, '0')}]';
  }
}

/// 转录片段（带时间戳）
class TranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;
  
  TranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

/// 录音状态枚举
enum RecordingState {
  idle,
  recording,
  transcribing,
  completed,
  error,
}

/// 模型状态枚举
enum ModelState {
  notLoaded,
  downloading,
  loaded,
  error,
}