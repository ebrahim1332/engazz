import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config_service.dart';

enum UpdateDownloadState {
  initial,
  downloading,
  completed,
  error,
}

class AppUpdateDialog extends StatefulWidget {
  final UpdateInfo update;

  const AppUpdateDialog({super.key, required this.update});

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  UpdateDownloadState _state = UpdateDownloadState.initial;
  double _progress = 0.0;
  String _downloadedSizeStr = '0 MB';
  String _totalSizeStr = '...';
  String _errorMessage = '';
  String? _downloadedFilePath;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = UpdateDownloadState.downloading;
      _progress = 0.0;
      _downloadedSizeStr = '0 MB';
      _totalSizeStr = '...';
      _errorMessage = '';
    });

    try {
      // طلب إذن تثبيت التطبيقات في أندرويد إذا لزم الأمر
      if (Platform.isAndroid) {
        final installPermission = await Permission.requestInstallPackages.status;
        if (installPermission.isDenied) {
          await Permission.requestInstallPackages.request();
        }
      }

      // تحديد مسار حفظ الملف
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final savePath = '${dir.path}/engazz_update_${widget.update.latestVersionCode}.apk';

      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      _cancelToken = CancelToken();

      await dio.download(
        widget.update.downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() {
              _progress = received / total;
              _downloadedSizeStr = '${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
              _totalSizeStr = '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
            });
          } else {
            setState(() {
              _downloadedSizeStr = '${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _state = UpdateDownloadState.completed;
        _progress = 1.0;
        _downloadedFilePath = savePath;
      });

      // فتح حزمة التثبيت تلقائياً
      await _installApk(savePath);
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;

      setState(() {
        _state = UpdateDownloadState.error;
        _errorMessage = 'تعذر تحميل التحديث: ${e.toString()}';
      });
    }
  }

  Future<void> _installApk(String path) async {
    try {
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && mounted) {
        debugPrint('OpenFilex result: ${result.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر فتح ملف التثبيت: $e';
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (widget.update.downloadUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.update.downloadUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.update.isMandatory && _state != UpdateDownloadState.downloading,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF071911),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: const Color(0xFF1ED760).withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة التحديث
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _state == UpdateDownloadState.completed
                        ? [const Color(0xFF1ED760), const Color(0xFF00E676)]
                        : _state == UpdateDownloadState.error
                            ? [Colors.orange.shade800, Colors.deepOrange]
                            : [const Color(0xFF0F9B58), const Color(0xFF1ED760)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_state == UpdateDownloadState.error
                              ? Colors.deepOrange
                              : const Color(0xFF1ED760))
                          .withValues(alpha: 0.45),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _state == UpdateDownloadState.completed
                      ? Icons.check_circle_rounded
                      : _state == UpdateDownloadState.error
                          ? Icons.error_outline_rounded
                          : Icons.system_update_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // عنوان التحديث
              Text(
                widget.update.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // رقم الإصدار
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E3827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'الإصدار الجديد: ${widget.update.latestVersionName}',
                  style: const TextStyle(
                    color: Color(0xFF1ED760),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // تفاصيل التحديث
              if (_state == UpdateDownloadState.initial) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFF1ED760), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'ما الجديد في هذا التحديث:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.update.releaseNotes,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // شريط تقدم التحميل
              if (_state == UpdateDownloadState.downloading) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1ED760).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'جاري التحميل...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF1ED760),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 10,
                          backgroundColor: const Color(0xFF0E3827),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1ED760)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_downloadedSizeStr / $_totalSizeStr',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            'يرجى عدم إغلاق التطبيق',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // اكتمال التحميل
              if (_state == UpdateDownloadState.completed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ED760).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1ED760).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1ED760)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'اكتمل التحميل، جاري فتح التثبيت...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'يرجى تأكيد التثبيت من نافذة النظام',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // حالة الخطأ
              if (_state == UpdateDownloadState.error) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage.isNotEmpty
                              ? _errorMessage
                              : 'حدث خطأ غير متوقع أثناء التحميل.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // الأزرار التفاعلية حسب الحالة
              if (_state == UpdateDownloadState.initial) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1ED760),
                      foregroundColor: const Color(0xFF071911),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _startDownload,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'تحديث التطبيق الآن',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_state == UpdateDownloadState.completed) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1ED760),
                      side: const BorderSide(color: Color(0xFF1ED760), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (_downloadedFilePath != null) {
                        _installApk(_downloadedFilePath!);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'إعادة فتح نافذة التثبيت',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_state == UpdateDownloadState.error) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1ED760),
                            foregroundColor: const Color(0xFF071911),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _startDownload,
                          child: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _openInBrowser,
                          child: const Text(
                            'عبر المتصفح',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
