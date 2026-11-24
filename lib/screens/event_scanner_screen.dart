import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cpf_mobile/models/campus_event.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/events_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

enum _ScannerMode { qrCamera, manualChecklist }

/// Screen 3B: Officer-only 2-Stage QR Attendance Scanner (Check-In / Check-Out)
/// using `mobile_scanner`, plus Manual Checklist fallback.
class EventScannerScreen extends StatefulWidget {
  const EventScannerScreen({
    super.key,
    required this.event,
    required this.eventsService,
    required this.storage,
    required this.baseUrl,
  });

  final CampusEvent event;
  final EventsService eventsService;
  final SecureStorageService storage;
  final String baseUrl;

  @override
  State<EventScannerScreen> createState() => _EventScannerScreenState();
}

class _EventScannerScreenState extends State<EventScannerScreen> {
  late CampusEvent _event;
  late final MobileScannerController _scannerController;
  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _scanType = 'login'; // 'login' (Check-In) or 'logout' (Check-Out)
  _ScannerMode _mode = _ScannerMode.qrCamera;
  bool _isPaused = false;
  bool _isSubmitting = false;

  String? _lastScannedPayload;
  String? _lastScannedType;
  DateTime? _lastScannedAt;

  _ScanFeedback? _feedback;
  List<ManualChecklistEntry> _checklist = const <ManualChecklistEntry>[];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1200,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    _loadChecklist();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChecklist() async {
    final entries = await widget.storage.readEventChecklist(_event.id);
    if (!mounted) return;
    setState(() {
      _checklist = entries;
    });
  }

  Color _stageColor(CpfPalette p) =>
      _scanType == 'login' ? p.success : p.accent;

  String get _stageLabel => _scanType == 'login' ? 'Check-In' : 'Check-Out';

  Future<void> _togglePause() async {
    try {
      if (_isPaused) {
        await _scannerController.start();
      } else {
        await _scannerController.stop();
      }
      if (!mounted) return;
      setState(() {
        _isPaused = !_isPaused;
      });
    } catch (_) {
      // Ignore camera lifecycle errors when hardware is unavailable.
    }
  }

  Future<void> _safeToggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flashlight is not available on this device.'),
        ),
      );
    }
  }

  Future<void> _safeSwitchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to switch camera on this device.'),
        ),
      );
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_mode != _ScannerMode.qrCamera || _isPaused || _isSubmitting) return;
    if (capture.barcodes.isEmpty) return;

    final raw = capture.barcodes.first.rawValue?.trim() ?? '';
    if (raw.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedPayload == raw &&
        _lastScannedType == _scanType &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!) < const Duration(seconds: 3)) {
      return;
    }

    _lastScannedPayload = raw;
    _lastScannedType = _scanType;
    _lastScannedAt = now;

    _submitScan(identifier: raw, scanType: _scanType, clearManualInput: false);
  }

  Future<void> _submitScan({
    required String identifier,
    required String scanType,
    required bool clearManualInput,
  }) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await widget.eventsService.scanAttendance(
        eventId: _event.id,
        qrPayload: trimmed,
        scanType: scanType,
      );

      await HapticFeedback.mediumImpact();

      final nextLoggedInCount = result.isFreshCheckIn
          ? _event.loggedInCount + 1
          : _event.loggedInCount;
      final nextLoggedOutCount = result.isFreshCheckOut
          ? _event.loggedOutCount + 1
          : _event.loggedOutCount;

      final updatedList = _mergeChecklistEntry(trimmed, result);
      await widget.storage.writeEventChecklist(_event.id, updatedList);

      if (!mounted) return;
      if (clearManualInput) {
        _manualInputController.clear();
      }
      setState(() {
        _event = _event.copyWith(
          loggedInCount: nextLoggedInCount,
          loggedOutCount: nextLoggedOutCount,
        );
        _checklist = updatedList;
        _feedback = _ScanFeedback(
          isError: false,
          isDuplicate: result.isDuplicate,
          title: '${result.statusLabel}: ${result.memberName}',
          subtitle: result.courseYearSection?.isNotEmpty == true
              ? result.courseYearSection!
              : trimmed,
        );
      });
    } catch (error) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _feedback = _ScanFeedback(
          isError: true,
          isDuplicate: false,
          title: 'Scan Rejected',
          subtitle: extractErrorMessage(
            error,
            currentBaseUrl: widget.baseUrl,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  List<ManualChecklistEntry> _mergeChecklistEntry(
    String identifier,
    ScanResult result,
  ) {
    final next = List<ManualChecklistEntry>.from(_checklist);
    final index = next.indexWhere(
      (e) =>
          e.identifier == identifier ||
          (result.memberName.isNotEmpty && e.memberName == result.memberName),
    );

    final record = result.attendance;
    final existing = index >= 0 ? next[index] : null;
    final entry = ManualChecklistEntry(
      identifier: existing?.identifier ?? identifier,
      memberName: result.memberName,
      courseYearSection:
          result.courseYearSection ?? existing?.courseYearSection,
      loggedInAt: record?.loggedInAt ?? existing?.loggedInAt,
      loggedOutAt: record?.loggedOutAt ?? existing?.loggedOutAt,
      lastStatus: result.status,
    );

    if (index >= 0) {
      next.removeAt(index);
    }
    next.insert(0, entry);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Attendance Scanner'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildEventHeader(p),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  _buildStageToggle(p),
                  const SizedBox(height: 10),
                  _buildModeTabs(p),
                ],
              ),
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _FeedbackCard(
                  feedback: _feedback!,
                  onDismiss: () => setState(() => _feedback = null),
                ),
              ),
            Expanded(
              child: _mode == _ScannerMode.qrCamera
                  ? _buildCameraView(p)
                  : _buildManualChecklistView(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventHeader(CpfPalette p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.heroCard,
        borderRadius: BorderRadius.circular(18),
        border: p.themeId.isDark ? Border.all(color: p.border) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.heroText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_event.location} • ${_event.startTime}–${_event.endTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.heroMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HeaderCountBadge(
            label: 'In',
            count: _event.loggedInCount,
            color: p.success,
          ),
          const SizedBox(width: 6),
          _HeaderCountBadge(
            label: 'Out',
            count: _event.loggedOutCount,
            color: p.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildStageToggle(CpfPalette p) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StageButton(
              icon: Icons.login_rounded,
              label: 'Check-In (Log In)',
              selected: _scanType == 'login',
              activeColor: p.success,
              onTap: () => setState(() => _scanType = 'login'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StageButton(
              icon: Icons.logout_rounded,
              label: 'Check-Out (Log Out)',
              selected: _scanType == 'logout',
              activeColor: p.accent,
              onTap: () => setState(() => _scanType = 'logout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs(CpfPalette p) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'QR Camera',
              selected: _mode == _ScannerMode.qrCamera,
              onTap: () => setState(() => _mode = _ScannerMode.qrCamera),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeTabButton(
              icon: Icons.checklist_rounded,
              label: 'Manual Checklist',
              selected: _mode == _ScannerMode.manualChecklist,
              onTap: () =>
                  setState(() => _mode = _ScannerMode.manualChecklist),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(CpfPalette p) {
    final stageColor = _stageColor(p);
    final onStage = p.themeId.isDark ? p.bg : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
                    errorBuilder: (context, error) {
                      return Container(
                        color: p.heroCard,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off_rounded,
                              size: 48,
                              color: p.accent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Camera Unavailable',
                              style: TextStyle(
                                color: p.heroText,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              error.errorDetails?.message ??
                                  'Grant camera permission in Android Settings or switch to Manual Checklist.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: p.heroMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => setState(
                                () => _mode = _ScannerMode.manualChecklist,
                              ),
                              icon: const Icon(Icons.checklist_rounded),
                              label: const Text('Use Manual Checklist'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: stageColor,
                            width: 3.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: stageColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isSubmitting
                              ? 'Recording $_stageLabel...'
                              : _isPaused
                                  ? 'Scanner Paused'
                                  : 'Ready for $_stageLabel QR',
                          style: TextStyle(
                            color: onStage,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isRunning ? _safeToggleTorch : null,
                      icon: Icon(
                        torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                      label: Text(torchOn ? 'Flash On' : 'Flash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isRunning ? _safeSwitchCamera : null,
                      icon: const Icon(Icons.cameraswitch_rounded),
                      label: const Text('Flip'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _togglePause,
                      icon: Icon(
                        _isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(_isPaused ? 'Resume' : 'Pause'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManualChecklistView(CpfPalette p) {
    final stageColor = _stageColor(p);
    final onStage = p.themeId.isDark ? p.bg : Colors.white;
    final query = _searchController.text.trim().toLowerCase();
    final visibleEntries = query.isEmpty
        ? _checklist
        : _checklist.where((e) {
            return e.memberName.toLowerCase().contains(query) ||
                e.identifier.toLowerCase().contains(query) ||
                (e.courseYearSection?.toLowerCase().contains(query) ?? false);
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manual $_stageLabel Entry',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter Member ID (e.g. CPF-ALIJIS-2026-0019) or paste signed QR payload.',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _manualInputController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (value) => _submitScan(
                  identifier: value,
                  scanType: _scanType,
                  clearManualInput: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Member ID or QR Payload',
                  hintText: 'CPF-ALIJIS-2026-0019',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: stageColor,
                  foregroundColor: onStage,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _submitScan(
                          identifier: _manualInputController.text,
                          scanType: _scanType,
                          clearManualInput: true,
                        ),
                icon: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onStage,
                        ),
                      )
                    : Icon(
                        _scanType == 'login'
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                      ),
                label: Text('Record $_stageLabel'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Event Attendance Checklist',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
            const Spacer(),
            Text(
              '${_checklist.length} recorded',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Filter checklist by name, course, or ID...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (visibleEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'No scanned or manually recorded peers yet for this event.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          )
        else
          for (final entry in visibleEntries) ...[
            _ChecklistRowCard(
              entry: entry,
              isSubmitting: _isSubmitting,
              onCheckIn: () => _submitScan(
                identifier: entry.identifier,
                scanType: 'login',
                clearManualInput: false,
              ),
              onCheckOut: () => _submitScan(
                identifier: entry.identifier,
                scanType: 'logout',
                clearManualInput: false,
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ScanFeedback {
  const _ScanFeedback({
    required this.isError,
    required this.isDuplicate,
    required this.title,
    required this.subtitle,
  });

  final bool isError;
  final bool isDuplicate;
  final String title;
  final String subtitle;
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.feedback,
    required this.onDismiss,
  });

  final _ScanFeedback feedback;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final Color color = feedback.isError
        ? p.error
        : feedback.isDuplicate
            ? p.primary
            : p.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            feedback.isError
                ? Icons.error_outline_rounded
                : feedback.isDuplicate
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  feedback.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.text,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _HeaderCountBadge extends StatelessWidget {
  const _HeaderCountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: p.heroText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final onActive = p.themeId.isDark ? p.bg : Colors.white;

    return Material(
      color: selected ? activeColor : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? onActive : p.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? onActive : p.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Material(
      color: selected ? p.card : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? p.primary : p.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? p.primary : p.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistRowCard extends StatelessWidget {
  const _ChecklistRowCard({
    required this.entry,
    required this.isSubmitting,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final ManualChecklistEntry entry;
  final bool isSubmitting;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final onAction = p.themeId.isDark ? p.bg : Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.memberName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.courseYearSection?.isNotEmpty == true
                      ? entry.courseYearSection!
                      : entry.identifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _MiniStatusBadge(
                      label: entry.isCheckedIn ? 'Checked In' : 'Not In',
                      color: entry.isCheckedIn ? p.success : p.muted,
                    ),
                    _MiniStatusBadge(
                      label: entry.isCheckedOut ? 'Checked Out' : 'Not Out',
                      color: entry.isCheckedOut ? p.accent : p.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              if (!entry.isCheckedIn)
                FilledButton(
                  onPressed: isSubmitting ? null : onCheckIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.success,
                    foregroundColor: onAction,
                    minimumSize: const Size(92, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Check In', style: TextStyle(fontSize: 12)),
                )
              else if (!entry.isCheckedOut)
                FilledButton(
                  onPressed: isSubmitting ? null : onCheckOut,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: onAction,
                    minimumSize: const Size(92, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child:
                      const Text('Check Out', style: TextStyle(fontSize: 12)),
                )
              else
                Icon(
                  Icons.verified_rounded,
                  color: p.success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  const _MiniStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
