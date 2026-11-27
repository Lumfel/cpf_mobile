import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/models/campus_event.dart';
import 'package:cpf_mobile/screens/event_scanner_screen.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/events_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

enum _EventFilter { all, active, upcoming, other }

/// Screen 3A: Same-campus Events & Activities list with personal attendance
/// status and Officer-only entry into the 2-stage QR Attendance Scanner.
class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.authController,
    required this.eventsService,
    required this.storage,
  });

  final AuthController authController;
  final EventsService eventsService;
  final SecureStorageService storage;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  EventsResponse? _response;
  bool _isLoading = true;
  String? _errorMessage;
  _EventFilter _filter = _EventFilter.all;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = _response == null;
      _errorMessage = null;
    });

    try {
      final result = await widget.eventsService.fetchEvents();
      if (!mounted) return;
      setState(() {
        _response = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = extractErrorMessage(
          error,
          currentBaseUrl: widget.authController.apiConfig.baseUrl,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanner(CampusEvent event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventScannerScreen(
          event: event,
          eventsService: widget.eventsService,
          storage: widget.storage,
          baseUrl: widget.authController.apiConfig.baseUrl,
        ),
      ),
    );
    if (mounted) {
      await _loadEvents();
    }
  }

  List<CampusEvent> _filteredEvents(List<CampusEvent> all) {
    return switch (_filter) {
      _EventFilter.all => all,
      _EventFilter.active =>
        all.where((e) => e.effectiveStatus.toLowerCase() == 'active').toList(),
      _EventFilter.upcoming => all.where((e) {
          final status = e.effectiveStatus.toLowerCase();
          return status == 'upcoming' || status == 'scheduled';
        }).toList(),
      _EventFilter.other => all.where((e) {
          final status = e.effectiveStatus.toLowerCase();
          return status != 'active' &&
              status != 'upcoming' &&
              status != 'scheduled';
        }).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final profile = widget.authController.profile;
    final canOfficerScanGlobal = (_response?.canScanEvents ?? false) &&
        (profile?.canScanEvents ?? false);

    if (_isLoading && _response == null) {
      return Center(
        child: CircularProgressIndicator(color: p.primary),
      );
    }

    if (_errorMessage != null && _response == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: p.muted,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: p.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final response = _response;
    final allEvents = response?.events ?? const <CampusEvent>[];
    final filtered = _filteredEvents(allEvents);

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _loadEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          _buildCampusBanner(p, response, canOfficerScanGlobal),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipItem(
                  label: 'All (${allEvents.length})',
                  selected: _filter == _EventFilter.all,
                  onSelected: () => setState(() => _filter = _EventFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Active',
                  selected: _filter == _EventFilter.active,
                  onSelected: () =>
                      setState(() => _filter = _EventFilter.active),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Upcoming',
                  selected: _filter == _EventFilter.upcoming,
                  onSelected: () =>
                      setState(() => _filter = _EventFilter.upcoming),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Past / Other',
                  selected: _filter == _EventFilter.other,
                  onSelected: () =>
                      setState(() => _filter = _EventFilter.other),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: p.error,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 40,
                    color: p.muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No campus events match this filter.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pull down to refresh the latest schedule.',
                    style: TextStyle(fontSize: 12.5, color: p.muted),
                  ),
                ],
              ),
            )
          else
            for (final event in filtered) ...[
              _EventCard(
                event: event,
                showScanButton:
                    canOfficerScanGlobal && event.canScan && event.isActive,
                onScanTap: () => _openScanner(event),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildCampusBanner(
    CpfPalette p,
    EventsResponse? response,
    bool canOfficerScan,
  ) {
    final campusName = response?.campus?.name ??
        widget.authController.profile?.campus?.name ??
        'Campus Events';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.heroCard,
        borderRadius: BorderRadius.circular(16),
        border: p.themeId.isDark ? Border.all(color: p.border) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.heroCardElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: p.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campusName,
                  style: TextStyle(
                    color: p.heroText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canOfficerScan
                      ? 'Officer QR Scanner enabled on active events'
                      : 'Present your Peer QR ID at active campus events',
                  style: TextStyle(
                    color: p.heroMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: p.primary.withValues(alpha: 0.18),
      backgroundColor: p.card,
      side: BorderSide(
        color: selected ? p.primary : p.border,
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: selected ? p.primary : p.text,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.showScanButton,
    required this.onScanTap,
  });

  final CampusEvent event;
  final bool showScanButton;
  final VoidCallback onScanTap;

  Color _effectiveStatusColor(CpfPalette p, String effectiveStatus) {
    return switch (effectiveStatus.toLowerCase()) {
      'active' => p.success,
      'upcoming' || 'scheduled' => p.primary,
      'cancelled' => p.error,
      _ => p.muted,
    };
  }

  Color _myAttendanceColor(CpfPalette p, String status) {
    return switch (status) {
      'logged_in' => p.primary,
      'completed' => p.success,
      _ => p.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final statusColor = _effectiveStatusColor(p, event.effectiveStatus);
    final myAttColor = _myAttendanceColor(p, event.myAttendance.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: event.isActive
              ? p.success.withValues(alpha: 0.5)
              : p.border,
          width: event.isActive ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(
                label: event.effectiveStatus.toUpperCase(),
                color: statusColor,
              ),
              if (event.isPendingApproval) ...[
                const SizedBox(width: 6),
                _StatusPill(
                  label: 'PENDING APPROVAL',
                  color: p.accent,
                ),
              ],
              const Spacer(),
              _StatusPill(
                label: event.myAttendance.label,
                color: myAttColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          if (event.description != null &&
              event.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: p.muted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: p.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${event.eventDateLabel.isNotEmpty ? event.eventDateLabel : event.eventDate} • ${event.startTime}–${event.endTime}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 16,
                color: p.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ),
          if (event.isCancelled &&
              event.cancellationReason != null &&
              event.cancellationReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Cancelled: ${event.cancellationReason}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _CountChip(
                icon: Icons.login_rounded,
                color: p.success,
                label: '${event.loggedInCount} In',
              ),
              const SizedBox(width: 8),
              _CountChip(
                icon: Icons.logout_rounded,
                color: p.accent,
                label: '${event.loggedOutCount} Out',
              ),
              const Spacer(),
              if (showScanButton)
                FilledButton.icon(
                  onPressed: onScanTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.success,
                    foregroundColor: p.themeId.isDark ? p.bg : Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text(
                    'Scan Attendance',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }
}
