import 'dart:io';

class FileUtils {
  static const imageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.gif', '.bmp'
  };

  static const videoExtensions = {
    '.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv', '.webm', '.3gp', '.mpg', '.mpeg'
  };

  static bool isImage(String path) {
    final ext = _getExtension(path);
    return imageExtensions.contains(ext);
  }

  static bool isVideo(String path) {
    final ext = _getExtension(path);
    return videoExtensions.contains(ext);
  }

  static bool isImageFile(File file) {
    return isImage(file.path);
  }

  static bool isVideoFile(File file) {
    return isVideo(file.path);
  }

  static String _getExtension(String path) {
    final index = path.lastIndexOf('.');
    return index == -1 ? '' : path.substring(index).toLowerCase();
  }

  static bool canBeLoadedAsImage(String path, String? mimeType) {
    if (mimeType != null && mimeType.startsWith('image/')) return true;
    return isImage(path);
  }
}
