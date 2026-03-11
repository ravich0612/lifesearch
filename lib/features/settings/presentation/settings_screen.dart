import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/indexing_service.dart';
import '../../home/providers/home_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _batteryMode = false;
  bool _indexPhotos = true;
  bool _indexScreenshots = true;
  bool _indexDocs = true;

  int _devTapCount = 0;

  // Smart Suggestions Toggles
  bool _triggerFlight = true;
  bool _triggerReceipt = true;
  bool _triggerPackage = true;
  bool _triggerParking = true;
  bool _triggerOtp = true;
  bool _triggerAddress = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _batteryMode = prefs.getBool('battery_mode') ?? false;
      _indexPhotos = prefs.getBool('index_photos') ?? true;
      _indexScreenshots = prefs.getBool('index_screenshots') ?? true;
      _indexDocs = prefs.getBool('index_docs') ?? true;

      _triggerFlight = prefs.getBool('trigger_flight') ?? true;
      _triggerReceipt = prefs.getBool('trigger_receipt') ?? true;
      _triggerPackage = prefs.getBool('trigger_package') ?? true;
      _triggerParking = prefs.getBool('trigger_parking') ?? true;
      _triggerOtp = prefs.getBool('trigger_otp') ?? true;
      _triggerAddress = prefs.getBool('trigger_address') ?? true;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'battery_mode') _batteryMode = value;
      if (key == 'index_photos') _indexPhotos = value;
      if (key == 'index_screenshots') _indexScreenshots = value;
      if (key == 'index_docs') _indexDocs = value;
      
      if (key == 'trigger_flight') _triggerFlight = value;
      if (key == 'trigger_receipt') _triggerReceipt = value;
      if (key == 'trigger_package') _triggerPackage = value;
      if (key == 'trigger_parking') _triggerParking = value;
      if (key == 'trigger_otp') _triggerOtp = value;
      if (key == 'trigger_address') _triggerAddress = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCountAsync = ref.watch(memoryCountProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SettingsSection(
            title: 'Performance',
            children: [
              _SettingsTile(
                icon: Icons.battery_saver_rounded, 
                title: 'Battery Friendly Mode', 
                subtitle: 'Pause indexing when battery is low',
                trailing: Switch(
                  value: _batteryMode, 
                  onChanged: (v) => _updateSetting('battery_mode', v),
                  activeThumbColor: AppColors.deepIndigo,
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsSection(
            title: 'Indexing Sources',
            children: [
              _SettingsTile(
                icon: Icons.screenshot_rounded, 
                title: 'Screenshots', 
                trailing: Switch(
                  value: _indexScreenshots, 
                  onChanged: (v) => _updateSetting('index_screenshots', v),
                  activeThumbColor: AppColors.deepIndigo,
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.description_rounded, 
                title: 'Documents & PDFs', 
                trailing: Switch(
                  value: _indexDocs, 
                  onChanged: (v) => _updateSetting('index_docs', v),
                  activeThumbColor: AppColors.deepIndigo,
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.image_outlined, 
                title: 'Photos', 
                trailing: Switch(
                  value: _indexPhotos, 
                  onChanged: (v) => _updateSetting('index_photos', v),
                  activeThumbColor: AppColors.deepIndigo,
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsSection(
            title: 'Smart Suggestions',
            children: [
              _SettingsTile(
                icon: Icons.flight_takeoff_rounded, 
                title: 'Flight Detection', 
                trailing: Switch(
                  value: _triggerFlight, 
                  onChanged: (v) => _updateSetting('trigger_flight', v),
                  activeThumbColor: AppColors.deepIndigo, 
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.local_parking_rounded, 
                title: 'Parking Memory', 
                trailing: Switch(
                  value: _triggerParking, 
                  onChanged: (v) => _updateSetting('trigger_parking', v),
                  activeThumbColor: AppColors.deepIndigo, 
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.local_shipping_rounded, 
                title: 'Package Tracking', 
                trailing: Switch(
                  value: _triggerPackage, 
                  onChanged: (v) => _updateSetting('trigger_package', v),
                  activeThumbColor: AppColors.deepIndigo, 
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.receipt_long_rounded, 
                title: 'Receipt Detection', 
                trailing: Switch(
                  value: _triggerReceipt, 
                  onChanged: (v) => _updateSetting('trigger_receipt', v),
                  activeThumbColor: AppColors.deepIndigo, 
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.password_rounded, 
                title: 'OTP Detection', 
                trailing: Switch(
                  value: _triggerOtp, 
                  onChanged: (v) => _updateSetting('trigger_otp', v),
                  activeThumbColor: AppColors.deepIndigo, 
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
              _SettingsTile(
                icon: Icons.map_rounded, 
                title: 'Address Detection', 
                trailing: Switch(
                  value: _triggerAddress, 
                  onChanged: (v) => _updateSetting('trigger_address', v),
                  activeThumbColor: AppColors.deepIndigo, 
                  activeTrackColor: AppColors.deepIndigo.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsSection(
            title: 'Privacy & Trust',
            children: [
              _SettingsTile(
                icon: Icons.shield_rounded, 
                title: 'Transparency Hub', 
                subtitle: 'Verify on-device privacy metrics',
                onTap: () => context.push('/transparency'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsSection(
            title: 'Index Maintenance',
            children: [
              _SettingsTile(
                icon: Icons.storage_rounded, 
                title: 'Current Index Size', 
                subtitle: '${totalCountAsync.value ?? 0} memories mapped',
                trailing: const SizedBox.shrink(),
              ),
              _SettingsTile(
                icon: Icons.refresh_rounded, 
                title: 'Rebuild Index', 
                subtitle: 'Clear and start fresh',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rebuild Index?'),
                      content: const Text('This will delete your current search index. Your files will not be touched.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true), 
                          child: const Text('Rebuild', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref.read(indexingServiceProvider).resetIndexing();
                    if (context.mounted) context.go('/indexing');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 48),
          Center(
            child: GestureDetector(
              onTap: () {
                _devTapCount++;
                if (_devTapCount >= 5) {
                  _devTapCount = 0;
                  context.push('/developer');
                }
              },
              child: const Text(
                'LifeSearch v1.0.0\nAll processing happens on-device',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
               BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.deepIndigo, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
