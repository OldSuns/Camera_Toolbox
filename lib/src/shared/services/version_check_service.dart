import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 版本信息模型
class VersionInfo {
  final String tagName;
  final String name;
  final String body;
  final DateTime publishedAt;
  final String htmlUrl;

  VersionInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.htmlUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      publishedAt: DateTime.parse(
        json['published_at'] ?? DateTime.now().toIso8601String(),
      ),
      htmlUrl: json['html_url'] ?? '',
    );
  }
}

/// 版本更新状态模型
class VersionUpdateStatus {
  final String currentVersion;
  final VersionInfo? latestVersion;
  final bool hasUpdate;

  VersionUpdateStatus({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
  });
}

/// 版本检查服务
class VersionCheckService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/OldSuns/Camera_Toolbox/releases/latest';
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

  /// 检查是否有新版本
  static Future<VersionInfo?> checkForUpdates() async {
    try {
      // 使用重试机制获取最新版本信息
      final latestVersion = await _fetchLatestVersionWithRetry();
      if (latestVersion == null) {
        return null;
      }

      // 始终返回最新版本信息，无论是否有更新
      return latestVersion;
    } catch (e) {
      // 网络错误或其他异常，静默处理
      // 在生产环境中不输出错误信息，避免影响用户体验
    }

    return null;
  }

  /// 检查是否有新版本（仅在有更新时返回）
  static Future<VersionInfo?> checkForUpdatesOnly() async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 使用重试机制获取最新版本信息
      final latestVersion = await _fetchLatestVersionWithRetry();
      if (latestVersion == null) {
        return null;
      }

      // 比较版本号
      if (isNewerVersion(latestVersion.tagName, currentVersion)) {
        return latestVersion;
      }
    } catch (e) {
      // 网络错误或其他异常，静默处理
      // 在生产环境中不输出错误信息，避免影响用户体验
    }

    return null;
  }

  /// 使用重试机制获取最新版本信息
  static Future<VersionInfo?> _fetchLatestVersionWithRetry() async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // 创建带超时的HTTP客户端
        final client = http.Client();

        try {
          final response = await client
              .get(
                Uri.parse(_githubApiUrl),
                headers: {
                  'Accept': 'application/vnd.github.v3+json',
                  'User-Agent': 'Camera_Toolbox_App',
                },
              )
              .timeout(_timeout);

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            return VersionInfo.fromJson(data);
          } else if (response.statusCode >= 400 && response.statusCode < 500) {
            // 客户端错误（如404），不需要重试
            return null;
          }
        } finally {
          client.close();
        }
      } on SocketException {
        // 网络连接错误
        if (attempt == _maxRetries) {
          return null;
        }
      } on HttpException {
        // HTTP协议错误
        if (attempt == _maxRetries) {
          return null;
        }
      } on FormatException {
        // JSON解析错误，不需要重试
        return null;
      } catch (e) {
        // 其他错误
        if (attempt == _maxRetries) {
          return null;
        }
      }

      // 如果不是最后一次尝试，等待递增的间隔时间
      if (attempt < _maxRetries) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    return null;
  }

  /// 比较版本号，判断是否有新版本
  static bool isNewerVersion(String latest, String current) {
    // 移除版本号前缀的'v'字符
    final latestVersion = latest.replaceFirst(RegExp(r'^v'), '');
    final currentVersion = current.replaceFirst(RegExp(r'^v'), '');

    // 分割版本号
    final latestParts = latestVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();

    // 补齐版本号位数
    while (latestParts.length < 3) {
      latestParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    // 比较版本号
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  /// 检查版本更新状态
  static Future<VersionUpdateStatus> checkVersionStatus() async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 获取最新版本信息
      final latestVersion = await _fetchLatestVersionWithRetry();
      if (latestVersion == null) {
        return VersionUpdateStatus(
          currentVersion: currentVersion,
          latestVersion: null,
          hasUpdate: false,
        );
      }

      // 比较版本号
      final hasUpdate = isNewerVersion(latestVersion.tagName, currentVersion);

      return VersionUpdateStatus(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      // 网络错误或其他异常，静默处理
      return VersionUpdateStatus(
        currentVersion: '',
        latestVersion: null,
        hasUpdate: false,
      );
    }
  }
}
