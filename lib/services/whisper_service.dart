import 'dart:io';
import 'package:whisper_kit/whisper_kit.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transcription_model.dart';

/// Whisper 离线语音识别服务
class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();
  
  Whisper? _whisper;
  String? _modelPath;
  bool _isModelLoaded = false;
  double _downloadProgress = 0.0;
  
  /// 检查模型是否已加载
  bool get isModelLoaded => _isModelLoaded;
  
  /// 下载进度（0.0 - 1.0）
  double get downloadProgress => _downloadProgress;
  
  /// 获取模型存储目录
  Future<Directory> _getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/whisper_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }
  
  /// 下载并加载模型
  /// [model] 模型大小：tiny, base, small, medium
  /// [onProgress] 进度回调
  Future<bool> loadModel({
    required WhisperModel model,
    Function(double progress)? onProgress,
  }) async {
    try {
      _downloadProgress = 0.0;
      onProgress?.call(0.0);
      
      final modelsDir = await _getModelsDirectory();
      final modelFileName = _getModelFileName(model);
      _modelPath = '${modelsDir.path}/$modelFileName';
      
      // 检查模型是否已存在
      final modelFile = File(_modelPath!);
      if (await modelFile.exists()) {
        print('模型已存在: $_modelPath');
        return await _initializeWhisper(model);
      }
      
      // 创建 Whisper 实例（自动下载模型）
      _whisper = Whisper(
        model: model,
        modelDir: modelsDir.path,
        onDownloadProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            onProgress?.call(_downloadProgress);
            print('下载进度: ${(_downloadProgress * 100).toStringAsFixed(1)}%');
          }
        },
      );
      
      // 调用 getVersion 确保初始化完成
      await _whisper?.getVersion();
      
      _isModelLoaded = true;
      onProgress?.call(1.0);
      return true;
      
    } catch (e) {
      print('加载模型失败: $e');
      _isModelLoaded = false;
      return false;
    }
  }
  
  /// 初始化 Whisper（模型已存在时）
  Future<bool> _initializeWhisper(WhisperModel model) async {
    try {
      final modelsDir = await _getModelsDirectory();
      _whisper = Whisper(
        model: model,
        modelDir: modelsDir.path,
      );
      await _whisper?.getVersion();
      _isModelLoaded = true;
      return true;
    } catch (e) {
      print('初始化 Whisper 失败: $e');
      return false;
    }
  }
  
  /// 获取模型文件名
  String _getModelFileName(WhisperModel model) {
    switch (model) {
      case WhisperModel.tiny:
        return 'ggml-tiny.bin';
      case WhisperModel.base:
        return 'ggml-base.bin';
      case WhisperModel.small:
        return 'ggml-small.bin';
      case WhisperModel.medium:
        return 'ggml-medium.bin';
      case WhisperModel.none:
        return '';
    }
  }
  
  /// 转录音频文件
  /// [audioPath] 音频文件路径（WAV格式，16kHz，16bit mono）
  /// [language] 语言代码（'zh', 'yue', 'en', 'auto'）
  /// [translateToEnglish] 是否翻译为英文
  Future<TranscriptionResultModel?> transcribe({
    required String audioPath,
    String language = 'auto',
    bool translateToEnglish = false,
  }) async {
    if (!_isModelLoaded || _whisper == null) {
      throw Exception('模型未加载');
    }
    
    try {
      final request = TranscribeRequest(
        audio: audioPath,
        language: language == 'auto' ? 'auto' : language,
        isTranslate: translateToEnglish,
        isNoTimestamps: false,
        splitOnWord: true,
        threads: 4,
      );
      
      final response = await _whisper!.transcribe(transcribeRequest: request);
      return TranscriptionResultModel.fromWhisperResponse(response);
      
    } catch (e) {
      print('转录失败: $e');
      return null;
    }
  }
  
  /// 获取 Whisper 版本
  Future<String?> getVersion() async {
    if (_whisper == null) return null;
    return await _whisper!.getVersion();
  }
  
  /// 获取推荐的模型大小（根据设备性能）
  WhisperModel getRecommendedModel() {
    // 安卓设备：根据可用内存推荐
    // 通常 base 或 small 模型在手机上运行良好
    return WhisperModel.base; // 约145MB，速度和准确率的平衡
  }
  
  /// 释放资源
  void dispose() {
    _whisper = null;
    _isModelLoaded = false;
  }
}