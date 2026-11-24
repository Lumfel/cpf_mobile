import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/models/election_models.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/elections_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/animated_entrance.dart';

/// Among Us-inspired Emergency Meeting Elections screen with 2-column nominee
/// cards, Confirm/Cancel vote animation, Adviser Presiding (tie-break only)
/// indicator, and collapsible ephemeral Session Chat.
class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({
    super.key,
    required this.authController,
    required this.electionsService,
  });

  final AuthController authController;
  final ElectionsService electionsService;

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  final TextEditingController _chatInputController = TextEditingController();

  ActiveElectionOverview? _overview;
  bool _isLoading = true;
  String? _errorMessage;

  int? _armedCandidateId;
  bool _isCastingVote = false;
  bool _isNominating = false;

  bool _chatExpanded = false;
  bool _isSendingChat = false;
  List<ElectionLiveChatMessage> _chatMessages =
      const <ElectionLiveChatMessage>[];
  Timer? _chatPollTimer;

  @override
  void initState() {
    super.initState();
    _loadElection();
  }

  @override
  void dispose() {
    _stopChatPolling();
    _chatInputController.dispose();
    super.dispose();
  }

  void _stopChatPolling() {
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
  }

  void _syncChatPolling() {
    final active = _overview?.activeElection;
    final shouldPoll = _chatExpanded &&
        active != null &&
        active.status == 'open' &&
        active.liveChatEnabled;

    if (!shouldPoll) {
      _stopChatPolling();
      return;
    }

    _chatPollTimer ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchLiveChatSilently(),
    );
  }

  Future<void> _loadElection() async {
    setState(() {
      _isLoading = _overview == null;
      _errorMessage = null;
    });

    try {
      final res = await widget.electionsService.fetchActiveElection();
      if (!mounted) return;
      final hasActive = res.activeElection != null &&
          res.activeElection!.status == 'open';

      setState(() {
        _overview = res;
        _isLoading = false;
        if (!hasActive) {
          _chatExpanded = false;
          _chatMessages = const <ElectionLiveChatMessage>[];
          _armedCandidateId = null;
        }
      });
      _syncChatPolling();
      if (hasActive && _chatExpanded) {
        await _fetchLiveChatSilently();
      }
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

  Future<void> _fetchLiveChatSilently() async {
    final active = _overview?.activeElection;
    if (active == null || !mounted) return;

    try {
      final msgs = await widget.electionsService.fetchLiveChat(active.id);
      if (!mounted) return;
      setState(() => _chatMessages = msgs);
    } on ApiException catch (e) {
      if (e.statusCode == 422 || e.statusCode == 403) {
        // Election session closed -> wipe ephemeral messages immediately!
        _stopChatPolling();
        if (mounted) {
          setState(() {
            _chatExpanded = false;
            _chatMessages = const <ElectionLiveChatMessage>[];
          });
          _loadElection();
        }
      }
    } catch (_) {
      // Silent retry on next poll tick.
    }
  }

  Future<void> _toggleChatSheet() async {
    final nextExpanded = !_chatExpanded;
    setState(() => _chatExpanded = nextExpanded);
    _syncChatPolling();
    if (nextExpanded) {
      await _fetchLiveChatSilently();
    }
  }

  Future<void> _sendChatMessage() async {
    final active = _overview?.activeElection;
    final text = _chatInputController.text.trim();
    if (active == null || text.isEmpty || _isSendingChat) return;

    setState(() => _isSendingChat = true);
    try {
      final msg = await widget.electionsService.sendLiveChat(
        electionId: active.id,
        messageBody: text,
      );
      if (!mounted) return;
      _chatInputController.clear();
      setState(() {
        final next = List<ElectionLiveChatMessage>.from(_chatMessages)..add(msg);
        _chatMessages =
            next.length > 100 ? next.sublist(next.length - 100) : next;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(
              error,
              currentBaseUrl: widget.authController.apiConfig.baseUrl,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingChat = false);
      }
    }
  }

  Future<void> _confirmVote(
    ActiveElectionSession session,
    ElectionNominee nominee,
  ) async {
    if (_isCastingVote) return;
    setState(() => _isCastingVote = true);

    try {
      await HapticFeedback.mediumImpact();
      await widget.electionsService.castVote(
        electionId: session.id,
        candidateId: nominee.id,
        position: session.currentPosition,
      );
      if (!mounted) return;
      setState(() => _armedCandidateId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote locked in for ${nominee.name}!')),
      );
      await _loadElection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(
              error,
              currentBaseUrl: widget.authController.apiConfig.baseUrl,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCastingVote = false);
      }
    }
  }

  Future<void> _promptSelfNomination(ActiveElectionSession session) async {
    final user = widget.authController.profile?.user;
    if (user == null || _isNominating) return;

    final platformController = TextEditingController();
    final p = context.cpf;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nominate Yourself • ${session.currentPositionLabel ?? 'Officer'}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: p.text,
          ),
        ),
        content: TextField(
          controller: platformController,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Short Platform / Vision (Optional)',
            hintText: 'Share your peer support goals...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit Nomination'),
          ),
        ],
      ),
    );

    final platformText = platformController.text;
    platformController.dispose();

    if (submitted != true || !mounted) return;

    setState(() => _isNominating = true);
    try {
      await widget.electionsService.nominate(
        electionId: session.id,
        nomineeUserId: user.id,
        platform: platformText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomination submitted!')),
      );
      await _loadElection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(
              error,
              currentBaseUrl: widget.authController.apiConfig.baseUrl,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isNominating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    if (_isLoading && _overview == null) {
      return Center(child: CircularProgressIndicator(color: p.primary));
    }

    if (_errorMessage != null && _overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: p.muted),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadElection,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final overview = _overview!;
    final active = overview.activeElection;
    final showSessionChat =
        active != null && active.status == 'open' && active.liveChatEnabled;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: p.primary,
            onRefresh: _loadElection,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (active == null)
                  FadeSlideIn(child: _buildNoActiveSessionCard(p, overview))
                else ...[
                  FadeSlideIn(child: _buildMeetingHeader(p, active)),
                  const SizedBox(height: 10),
                  _buildAdviserPresidingBar(p, active),
                  if (active.canNominate) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor:
                            p.themeId.isDark ? p.bg : Colors.white,
                      ),
                      onPressed: _isNominating
                          ? null
                          : () => _promptSelfNomination(active),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        'Self-Nominate for ${active.currentPositionLabel ?? 'Seat'}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildAmongUsVotingGrid(p, active),
                  const SizedBox(height: 18),
                  _buildSeatSlateCard(p, overview.seats),
                ],
              ],
            ),
          ),
        ),
        if (showSessionChat) _buildCollapsibleSessionChat(p, active),
      ],
    );
  }

  Widget _buildNoActiveSessionCard(
    CpfPalette p,
    ActiveElectionOverview overview,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.heroCard,
            borderRadius: BorderRadius.circular(22),
            border: p.themeId.isDark ? Border.all(color: p.border) : null,
          ),
          child: Column(
            children: [
              Icon(Icons.how_to_vote_outlined, size: 46, color: p.accent),
              const SizedBox(height: 12),
              Text(
                'No Active Election Session',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.heroText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When your Club Adviser opens an official CPF chapter election, floor voting cards and ephemeral session chat unlock here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.heroMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (overview.seats.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSeatSlateCard(p, overview.seats),
        ],
      ],
    );
  }

  Widget _buildMeetingHeader(CpfPalette p, ActiveElectionSession active) {
    final phaseLabel = switch (active.currentPhase) {
      'nomination' => 'NOMINATION FLOOR',
      'tie_breaker' => 'TIE-BREAKER RUNOFF • ROUND ${active.roundNumber}',
      _ => 'EMERGENCY VOTE • ROUND ${active.roundNumber}',
    };
    final phaseColor = active.isTieBreaker
        ? p.error
        : active.isNominationPhase
            ? p.accent
            : p.success;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.heroCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: phaseColor.withValues(alpha: 0.65),
          width: 1.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_rounded, size: 15, color: phaseColor),
                    const SizedBox(width: 5),
                    Text(
                      phaseLabel,
                      style: TextStyle(
                        color: p.heroText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'AY ${active.academicYear}',
                style: TextStyle(
                  color: p.heroMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'WHO WILL SERVE AS ${(active.currentPositionLabel ?? 'OFFICER').toUpperCase()}?',
            style: TextStyle(
              color: p.heroText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            active.hasVotedCurrentRound
                ? 'Your ballot for this round is locked in.'
                : active.canVote
                    ? 'Tap a nominee card below, then tap the green check to confirm your vote.'
                    : active.isNominationPhase
                        ? 'Nominations are open before floor voting begins.'
                        : 'Observing live floor tally.',
            style: TextStyle(color: p.heroMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviserPresidingBar(
    CpfPalette p,
    ActiveElectionSession active,
  ) {
    final highlightColor = active.isTieBreaker ? p.accent : p.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlightColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlightColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel_rounded, size: 18, color: highlightColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              active.isTieBreaker
                  ? 'Adviser Presiding: Tie-breaker active — Adviser breaks deadlocks if runoff ties.'
                  : 'Adviser Presiding: Club Adviser chairs session (tie-break vote only).',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmongUsVotingGrid(
    CpfPalette p,
    ActiveElectionSession active,
  ) {
    final candidates = active.currentPositionNominees.isNotEmpty
        ? active.currentPositionNominees
        : active.nominees
            .where((n) => n.position == active.currentPosition)
            .toList();

    if (candidates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border),
        ),
        child: Text(
          'No nominees on the board yet for ${active.currentPositionLabel ?? 'this seat'}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 700
            ? 3
            : maxWidth < 310
                ? 1
                : 2;
        const spacing = 10.0;
        final cardWidth =
            (maxWidth - (spacing * (columns - 1))) / columns;

        final swatchColors = <Color>[
          p.primary,
          p.accent,
          p.success,
          const Color(0xFF8B5CF6),
          const Color(0xFFEC4899),
          const Color(0xFF0EA5E9),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < candidates.length; i++)
              SizedBox(
                width: cardWidth,
                child: _CrewmateVoteCard(
                  nominee: candidates[i],
                  suitColor: swatchColors[i % swatchColors.length],
                  isMyVote:
                      active.myCurrentVoteCandidateId == candidates[i].id,
                  isArmed: _armedCandidateId == candidates[i].id,
                  canArm: active.canVote &&
                      !active.hasVotedCurrentRound &&
                      candidates[i].isAccepted &&
                      (!active.isTieBreaker || candidates[i].isTieContender),
                  isSubmitting: _isCastingVote,
                  onTapCard: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _armedCandidateId = _armedCandidateId == candidates[i].id
                          ? null
                          : candidates[i].id;
                    });
                  },
                  onConfirm: () => _confirmVote(active, candidates[i]),
                  onCancel: () => setState(() => _armedCandidateId = null),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSeatSlateCard(CpfPalette p, List<ElectionSeat> seats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parliamentary Seat Order',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          const SizedBox(height: 8),
          for (final seat in seats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    seat.isElected
                        ? Icons.check_circle_rounded
                        : seat.isCurrent
                            ? Icons.play_circle_fill_rounded
                            : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: seat.isElected
                        ? p.success
                        : seat.isCurrent
                            ? p.accent
                            : p.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      seat.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: seat.isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: seat.isCurrent ? p.text : p.muted,
                      ),
                    ),
                  ),
                  if (seat.winnerName?.isNotEmpty == true)
                    Flexible(
                      child: Text(
                        seat.winnerName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.success,
                        ),
                      ),
                    )
                  else if (seat.isSkipped)
                    Text(
                      'Skipped',
                      style: TextStyle(fontSize: 11.5, color: p.muted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSessionChat(
    CpfPalette p,
    ActiveElectionSession active,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.themeId.isDark ? 0.35 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _toggleChatSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: p.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Chat (${_chatMessages.length})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        Text(
                          'Session-only chat • Clears when voting ends',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _chatExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: p.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_chatExpanded) ...[
            const Divider(height: 1),
            SizedBox(
              height: 190,
              child: _chatMessages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No live messages yet. Messages stay in temporary RAM cache only and auto-wipe when this election closes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.text,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${msg.senderName}: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: p.primary,
                                    ),
                                  ),
                                  TextSpan(text: msg.messageBody),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      enabled: !_isSendingChat,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendChatMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Say something to the floor...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSendingChat ? null : _sendChatMessage,
                    icon: _isSendingChat
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CrewmateVoteCard extends StatelessWidget {
  const _CrewmateVoteCard({
    required this.nominee,
    required this.suitColor,
    required this.isMyVote,
    required this.isArmed,
    required this.canArm,
    required this.isSubmitting,
    required this.onTapCard,
    required this.onConfirm,
    required this.onCancel,
  });

  final ElectionNominee nominee;
  final Color suitColor;
  final bool isMyVote;
  final bool isArmed;
  final bool canArm;
  final bool isSubmitting;
  final VoidCallback onTapCard;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final borderColor = isMyVote
        ? p.success
        : isArmed
            ? p.accent
            : p.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: (isMyVote || isArmed) ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: (isMyVote || isArmed) ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canArm ? onTapCard : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Crewmate visor avatar badge
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: suitColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 22,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF4FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedScale(
                      scale: isMyVote ? 1.0 : 0.92,
                      duration: const Duration(milliseconds: 200),
                      child: isMyVote
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: p.error,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'I VOTED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${nominee.votes} vote${nominee.votes == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.text,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  nominee.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nominee.courseYearSection,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: p.muted,
                  ),
                ),
                if (nominee.platform?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${nominee.platform}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: p.muted,
                    ),
                  ),
                ],
                if (!nominee.isAccepted) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Awaiting nominee acceptance',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: isArmed
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: isSubmitting ? null : onConfirm,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: p.success,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSubmitting ? null : onCancel,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: p.error,
                                    side: BorderSide(color: p.error),
                                    minimumSize: const Size(0, 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
