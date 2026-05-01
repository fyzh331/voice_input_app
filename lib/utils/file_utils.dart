import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  /// 保存内容到 Downloads 目录
  static Future<String?> saveToDownload({
    required String content,
    required String fileName,
  }) async {
    try {
      Directory? downloadDir;
      
      // Android 10+ 使用 Downloads 目录
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else {
        downloadDir = await getDownloadsDirectory();
      }
      
      if (downloadDir == null) {
        // 回退到应用文档目录
        downloadDir = await getApplicationDocumentsDirectory();
      }
      
      final file = File('${downloadDir.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);
      return file.path;
      
    } catch (e) {
      print('保存文件失败: $e');
      return null;
    }
  }
  
  /// 获取文件大小（MB）
  static Future<double> getFileSizeInMB(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }
  
  /// 删除文件
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
