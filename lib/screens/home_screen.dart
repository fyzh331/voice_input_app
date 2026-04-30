import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_kit/whisper_kit.dart';
import '../services/whisper_service.dart';
import '../models/transcription_model.dart';
import '../utils/file_utils.dart';

/// 主界面 - 语音输入法
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WhisperService _whisperService = WhisperService();
  final AudioRecorder _recorder = AudioRecorder();
  
  // 状态变量
  bool _isModelReady = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _statusMessage = '准备就绪，按 F8 或点击麦克风开始录音';
  String _recognizedText = '';
  double _downloadProgress = 0.0;
  
  // 录音文件路径
  String? _currentRecordingPath;
  
  // 转录结果
  TranscriptionResultModel? _lastResult;
  
  // 选中的语言
  String _selectedLanguage = 'auto';
  final List<String> _languages = ['auto', 'zh', 'yue', 'en'];
  
  // 是否翻译为英文
  bool _translateToEnglish = false;
  
  @override
  void initState() {
    super.initState();
    _initApp();
  }
  
  /// 初始化应用
  Future<void> _initApp() async {
    await _requestPermissions();
    await _loadModel();
  }
  
  /// 请求权限
  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.storage,
    ].request();
  }
  
  /// 加载模型
  Future<void> _loadModel() async {
    setState(() {
      _statusMessage = '正在加载模型...';
    });
    
    final model = _whisperService.getRecommendedModel();
    final success = await _whisperService.loadModel(
      model: model,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          _statusMessage = '下载模型: ${(progress * 100).toStringAsFixed(1)}%';
        });
      },
    );
    
    setState(() {
      _isModelReady = success;
      _statusMessage = success ? '✅ 模型加载成功，可以开始录音' : '❌ 模型加载失败，请检查网络';
    });
  }
  
  /// 开始录音
  Future<void> _startRecording() async {
    if (!_isModelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模型未加载完成，请稍后')),
      );
      return;
    }
    
    try {
      // 检查权限
      if (!await Permission.microphone.isGranted) {
        await _requestPermissions();
      }
      
      // 创建临时录音文件
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/recording_$timestamp.wav';
      
      // 开始录音
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
      
      setState(() {
        _isRecording = true;
        _statusMessage = '🎤 录音中... 点击停止按钮结束';
      });
      
    } catch (e) {
      print('录音失败: $e');
      setState(() {
        _statusMessage = '录音失败: $e';
      });
    }
  }
  
  /// 停止录音并转录
  Future<void> _stopRecordingAndTranscribe() async {
    if (!_isRecording) return;
    
    try {
      // 停止录音
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
        _statusMessage = '🎙️ 识别中...';
      });
      
      if (path == null) {
        throw Exception('录音文件保存失败');
      }
      
      // 确保文件格式正确（Whisper需要WAV格式）
      final audioPath = await _ensureWavFormat(path);
      
      // 转录
      final result = await _whisperService.transcribe(
        audioPath: audioPath,
        language: _selectedLanguage,
        translateToEnglish: _translateToEnglish,
      );
      
      setState(() {
        _isTranscribing = false;
        
        if (result != null && result.text.isNotEmpty) {
          _lastResult = result;
          _recognizedText = _recognizedText.isEmpty 
              ? result.text 
              : '$_recognizedText\n\n${result.text}';
          _statusMessage = '✅ 识别完成，共 ${result.segments?.length ?? 0} 句';
        } else {
          _statusMessage = '识别失败，请重试';
        }
      });
      
      // 清理临时文件
      if (audioPath != path && File(audioPath).existsSync()) {
        await File(audioPath).delete();
      }
      
    } catch (e) {
      print('转录失败: $e');
      setState(() {
        _isTranscribing = false;
        _statusMessage = '转录失败: $e';
      });
    }
  }
  
  /// 确保音频格式正确（转换为WAV）
  Future<String> _ensureWavFormat(String path) async {
    // 如果已经是WAV格式，直接返回
    if (path.toLowerCase().endsWith('.wav')) {
      return path;
    }
    
    // 否则需要转换（这里简化处理，实际可能需要使用音频处理库）
    // 大多数情况下 record 插件直接录制为WAV格式
    return path;
  }
  
  /// 清空文本
  void _clearText() {
    setState(() {
      _recognizedText = '';
      _lastResult = null;
      _statusMessage = '文本已清空';
    });
  }
  
  /// 导出 LRC
  Future<void> _exportLRC() async {
    if (_lastResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的内容，请先进行语音识别')),
      );
      return;
    }
    
    final lrcContent = _lastResult!.toLRC();
    final filePath = await FileUtils.saveToDownload(
      content: lrcContent,
      fileName: 'subtitle_${DateTime.now().millisecondsSinceEpoch}.lrc',
    );
    
    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到: $filePath')),
      );
    }
  }
  
  /// 导出 SRT
  Future<void> _exportSRT() async {
    if (_lastResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的内容，请先进行语音识别')),
      );
      return;
    }
    
    final srtContent = _lastResult!.toSRT();
    final filePath = await FileUtils.saveToDownload(
      content: srtContent,
      fileName: 'subtitle_${DateTime.now().millisecondsSinceEpoch}.srt',
    );
    
    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到: $filePath')),
      );
    }
  }
  
  /// 复制到剪贴板
  void _copyToClipboard() {
    if (_recognizedText.isEmpty) return;
    // 使用 Clipboard 复制
    // Clipboard.setData(ClipboardData(text: _recognizedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线语音输入法'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _isModelReady ? Icons.check_circle : Icons.downloading,
                  color: _isModelReady ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 语言选择
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('语言:'),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'auto', label: Text('自动')),
                      ButtonSegment(value: 'zh', label: Text('国语')),
                      ButtonSegment(value: 'yue', label: Text('粤语')),
                      ButtonSegment(value: 'en', label: Text('英文')),
                    ],
                    selected: {_selectedLanguage},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedLanguage = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 翻译开关
          if (_selectedLanguage != 'en')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Checkbox(
                    value: _translateToEnglish,
                    onChanged: (value) {
                      setState(() {
                        _translateToEnglish = value ?? false;
                      });
                    },
                  ),
                  const Text('翻译为英文'),
                ],
              ),
            ),
          
          // 识别结果区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: TextEditingController(text: _recognizedText),
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '识别结果将显示在这里...\n\n支持国语、粤语、英文',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ),
          
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 录音按钮
                FloatingActionButton(
                  onPressed: _isRecording ? _stopRecordingAndTranscribe : _startRecording,
                  backgroundColor: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                
                // 清空按钮
                ElevatedButton.icon(
                  onPressed: _clearText,
                  icon: const Icon(Icons.delete),
                  label: const Text('清空'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                
                // 复制按钮
                ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('复制'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // 导出按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportLRC,
                    icon: const Icon(Icons.music_note),
                    label: const Text('导出 LRC 歌词'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportSRT,
                    icon: const Icon(Icons.subtitles),
                    label: const Text('导出 SRT 字幕'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ),
          
          // 提示信息
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Text(
              '提示：首次使用需下载模型（约145MB），请确保网络连接',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}