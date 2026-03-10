import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_gradient_button.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _photosGranted = false;
  bool _storageGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool sGranted = false;
    
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        sGranted = await Permission.manageExternalStorage.isGranted;
      } else {
        sGranted = await Permission.storage.isGranted;
      }
    } else {
      sGranted = await Permission.storage.isGranted;
    }

    // PhotoManager has its own way of checking authorization state
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    
    if (mounted) {
      setState(() {
        _storageGranted = sGranted;
        _photosGranted = state.isAuth == true;
      });
    }
  }

  Future<void> _requestPhotos() async {
    if (_photosGranted || _isRequesting) return;
    setState(() => _isRequesting = true);
    
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    
    if (mounted) {
      setState(() {
        _photosGranted = state.isAuth == true;
        _isRequesting = false;
      });
    }
  }

  Future<void> _requestStorage() async {
    if (_storageGranted || _isRequesting) return;
    setState(() => _isRequesting = true);
    
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // On Android 13+, "Files" access for non-media (PDFs, Docs) is often 
        // gated behind manageExternalStorage or just isn't a single permission.
        // For LifeSearch to index documents, we request manageExternalStorage.
        status = await Permission.manageExternalStorage.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.storage.request();
    }
    
    if (mounted) {
      setState(() {
        _storageGranted = status.isGranted;
        _isRequesting = false;
      });
    }
  }

  Future<void> _onContinue() async {
    if (_photosGranted || _storageGranted) {
      // Clear limited mode since user is providing full access now
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('limited_mode', false);
      
      if (!mounted) return;
      context.go('/indexing');
    } else {
      // Nothing granted yet — request photos first
      await _requestPhotos();
      // After attempt, check again
      if (_photosGranted || _storageGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('limited_mode', false);
        if (!mounted) return;
        context.go('/indexing');
      }
    }
  }

  void _enterLimitedMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('limited_mode', true);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 64,
                    color: AppColors.deepIndigo,
                  ),
                ).animate().fadeIn().scale(),
                const SizedBox(height: 48),
                Text(
                  'Your privacy is\nour priority',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                const SizedBox(height: 16),
                Text(
                  'Everything stays on your device. We just need to know where to look.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 48),
                _PermissionCard(
                  icon: Icons.image_rounded,
                  title: 'Photos & Screenshots',
                  description: 'To find memories in your gallery.',
                  isGranted: _photosGranted,
                  onTap: _requestPhotos,
                ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
                const SizedBox(height: 16),
                _PermissionCard(
                  icon: Icons.folder_rounded,
                  title: 'Files & Documents',
                  description: 'To index your saved PDFs and receipts.',
                  isGranted: _storageGranted,
                  onTap: _requestStorage,
                ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1),
                const Spacer(),
                PrimaryGradientButton(
                  onPressed: _onContinue,
                  child: Text(
                    _photosGranted || _storageGranted ? 'Start Indexing' : 'Give Access',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ).animate().fadeIn(delay: 1.seconds),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _enterLimitedMode,
                  child: const Text(
                    'Not now — use limited mode',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ).animate().fadeIn(delay: 1200.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 400.ms,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isGranted ? AppColors.success.withValues(alpha: 0.05) : AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isGranted ? AppColors.success.withValues(alpha: 0.3) : AppColors.cardBorder,
            width: isGranted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted 
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.deepIndigo.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGranted ? Icons.check_circle_rounded : icon,
                color: isGranted ? AppColors.success : AppColors.deepIndigo,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      color: isGranted ? AppColors.success.withValues(alpha: 0.8) : null,
                    ),
                  ),
                  Text(
                    isGranted ? 'Access Granted' : description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: isGranted ? AppColors.success.withValues(alpha: 0.6) : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
