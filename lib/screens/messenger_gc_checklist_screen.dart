import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/models/membership_payment.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/membership_payment_service.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/animated_entrance.dart';

enum _GcFilter { all, inGc, pendingGc }

/// Officer A–Z Messenger GC Checklist screen with live search filter and
/// 1-tap toggle syncing to `PATCH /api/v1/membership/{id}/toggle-gc`.
class MessengerGcChecklistScreen extends StatefulWidget {
  const MessengerGcChecklistScreen({
    super.key,
    required this.service,
    required this.baseUrl,
  });

  final MembershipPaymentService service;
  final String baseUrl;

  @override
  State<MessengerGcChecklistScreen> createState() =>
      _MessengerGcChecklistScreenState();
}

class _MessengerGcChecklistScreenState
    extends State<MessengerGcChecklistScreen> {
  final TextEditingController _searchController = TextEditingController();
  RosterResponse? _data;
  bool _isLoading = true;
  String? _errorMessage;
  _GcFilter _filter = _GcFilter.all;
  final Set<int> _togglingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoading = _data == null;
      _errorMessage = null;
    });

    try {
      final response = await widget.service.fetchRoster();
      if (!mounted) return;
      setState(() {
        _data = response;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            extractErrorMessage(error, currentBaseUrl: widget.baseUrl);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMemberGc(RosterMember member) async {
    final current = _data;
    if (current == null ||
        !current.canConfirmMessengerGc ||
        _togglingIds.contains(member.id)) {
      return;
    }

    final optimisticState = !member.isInMessengerGc;
    setState(() {
      _togglingIds.add(member.id);
      _data = RosterResponse(
        campusName: current.campusName,
        gcGroupName: current.gcGroupName,
        canConfirmMessengerGc: current.canConfirmMessengerGc,
        canValidatePayments: current.canValidatePayments,
        roster: current.roster
            .map(
              (m) => m.id == member.id
                  ? m.copyWith(isInMessengerGc: optimisticState)
                  : m,
            )
            .toList(),
      );
    });

    try {
      await HapticFeedback.selectionClick();
      final confirmed = await widget.service.toggleMessengerGc(member.id);
      if (!mounted) return;
      final latest = _data;
      if (latest != null) {
        setState(() {
          _data = RosterResponse(
            campusName: latest.campusName,
            gcGroupName: latest.gcGroupName,
            canConfirmMessengerGc: latest.canConfirmMessengerGc,
            canValidatePayments: latest.canValidatePayments,
            roster: latest.roster
                .map(
                  (m) => m.id == member.id
                      ? m.copyWith(isInMessengerGc: confirmed)
                      : m,
                )
                .toList(),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      final latest = _data;
      if (latest != null) {
        setState(() {
          _data = RosterResponse(
            campusName: latest.campusName,
            gcGroupName: latest.gcGroupName,
            canConfirmMessengerGc: latest.canConfirmMessengerGc,
            canValidatePayments: latest.canValidatePayments,
            roster: latest.roster
                .map(
                  (m) => m.id == member.id
                      ? m.copyWith(isInMessengerGc: member.isInMessengerGc)
                      : m,
                )
                .toList(),
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(error, currentBaseUrl: widget.baseUrl),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(member.id));
      }
    }
  }

  List<RosterMember> _visibleRoster(List<RosterMember> all) {
    final query = _searchController.text.trim().toLowerCase();
    return all.where((m) {
      final matchesFilter = switch (_filter) {
        _GcFilter.all => true,
        _GcFilter.inGc => m.isInMessengerGc,
        _GcFilter.pendingGc => !m.isInMessengerGc,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return m.fullNameLastFirstMi.toLowerCase().contains(query) ||
          (m.courseYearSection?.toLowerCase().contains(query) ?? false) ||
          m.roleLabel.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Messenger GC Checklist'),
        actions: [
          IconButton(
            tooltip: 'Refresh roster',
            onPressed: _loadRoster,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(p),
      ),
    );
  }

  Widget _buildBody(CpfPalette p) {
    if (_isLoading && _data == null) {
      return Center(
        child: CircularProgressIndicator(color: p.primary),
      );
    }

    if (_errorMessage != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 46, color: p.muted),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loadRoster,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final all = data.roster;
    final inGcCount = all.where((m) => m.isInMessengerGc).length;
    final visible = _visibleRoster(all);
    final progress = all.isEmpty ? 0.0 : inGcCount / all.length;

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _loadRoster,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.heroCard,
                borderRadius: BorderRadius.circular(20),
                border: p.themeId.isDark ? Border.all(color: p.border) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.forum_rounded, color: p.accent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.gcGroupName ?? 'Official Campus Peer GC',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.heroText,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.success.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$inGcCount / ${all.length} In GC',
                          style: TextStyle(
                            color: p.heroText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: p.heroCardElevated,
                      color: p.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.canConfirmMessengerGc
                        ? 'Tap any member switch to confirm or unconfirm Messenger GC presence.'
                        : 'Read-only A–Z roster view (Adviser, President, VP, Secretary, or PIO can toggle GC).',
                    style: TextStyle(color: p.heroMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search A–Z name, course, or role...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: 'All (${all.length})',
                  selected: _filter == _GcFilter.all,
                  onTap: () => setState(() => _filter = _GcFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'In GC ($inGcCount)',
                  selected: _filter == _GcFilter.inGc,
                  onTap: () => setState(() => _filter = _GcFilter.inGc),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Not Yet in GC (${all.length - inGcCount})',
                  selected: _filter == _GcFilter.pendingGc,
                  onTap: () => setState(() => _filter = _GcFilter.pendingGc),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: Text(
                'No approved members match this filter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted),
              ),
            )
          else
            for (final member in visible) ...[
              _RosterMemberTile(
                member: member,
                canToggle: data.canConfirmMessengerGc,
                isToggling: _togglingIds.contains(member.id),
                onToggle: () => _toggleMemberGc(member),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: p.primary.withValues(alpha: 0.18),
      backgroundColor: p.card,
      side: BorderSide(color: selected ? p.primary : p.border),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? p.primary : p.text,
      ),
    );
  }
}

class _RosterMemberTile extends StatelessWidget {
  const _RosterMemberTile({
    required this.member,
    required this.canToggle,
    required this.isToggling,
    required this.onToggle,
  });

  final RosterMember member;
  final bool canToggle;
  final bool isToggling;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final initial = member.fullNameLastFirstMi.isNotEmpty
        ? member.fullNameLastFirstMi[0].toUpperCase()
        : 'P';

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canToggle && !isToggling ? onToggle : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: member.isInMessengerGc
                  ? p.success.withValues(alpha: 0.45)
                  : p.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: p.primary.withValues(alpha: 0.14),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: p.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullNameLastFirstMi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (member.courseYearSection?.isNotEmpty == true)
                          Text(
                            member.courseYearSection!,
                            style: TextStyle(fontSize: 12, color: p.muted),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            member.roleLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: p.muted,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (member.hasPaidDues ? p.success : p.accent)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            member.hasPaidDues ? 'Dues Paid' : 'Dues Unpaid',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: member.hasPaidDues ? p.success : p.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isToggling)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.primary,
                  ),
                )
              else if (canToggle)
                Switch.adaptive(
                  value: member.isInMessengerGc,
                  activeTrackColor: p.success,
                  onChanged: (_) => onToggle(),
                )
              else
                Icon(
                  member.isInMessengerGc
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: member.isInMessengerGc ? p.success : p.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
