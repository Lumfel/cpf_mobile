import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/models/cpf_role.dart';
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

  int? _lastObservedOpenOrPausedElectionId;
  int? _lastSyncedCompletedElectionId;
  bool _didInitialResolvedSlateSync = false;
  String? _lastSyncedWonSeatKey;

  bool get _isGuidanceCounselorOnly =>
      widget.authController.profile?.isGuidanceCounselorOnly == true;

  bool get _isAlumni => widget.authController.profile?.isAlumni == true;

  bool get _isClubAdviser {
    final profile = widget.authController.profile;
    if (profile == null) return false;
    return profile.verifiedRole == CpfRole.adviser ||
        profile.permissions.isClubAdviser;
  }

  @override
  void initState() {
    super.initState();
    if (_isGuidanceCounselorOnly) {
      _isLoading = false;
    } else {
      _loadElection();
    }
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

  void _clearAndStopLiveChat() {
    _stopChatPolling();
    _chatExpanded = false;
    _chatMessages = const <ElectionLiveChatMessage>[];
    _chatInputController.clear();
  }

  bool _canNominateForSession(
    ActiveElectionOverview overview,
    ActiveElectionSession active,
  ) {
    if (!active.isActivelyOpen || !active.isNominationPhase) return false;
    if (!active.canNominate) return false;
    if (_isGuidanceCounselorOnly || _isAlumni || _isClubAdviser) return false;
    if (active.hasOptedOut) return false;

    final userId = widget.authController.profile?.user.id;
    if (overview.isUserAlreadyElected(userId)) return false;
    if (userId != null &&
        active.candidatesForCurrentSeat
            .any((c) => c.userId == userId && !c.isDeclined)) {
      return false;
    }
    return true;
  }

  bool _canVoteInSession(ActiveElectionSession active) {
    if (!active.isActivelyOpen || !active.isVotingPhase) return false;
    if (!active.canVote || active.hasVotedCurrentRound) return false;
    if (_isGuidanceCounselorOnly || _isAlumni) return false;
    if (_isClubAdviser && !active.isTieBreaker) return false;
    return true;
  }

  bool _canArmNominee(
    ActiveElectionOverview overview,
    ActiveElectionSession active,
    ElectionNominee nominee,
  ) {
    if (!_canVoteInSession(active)) return false;
    return active.isCandidateEligibleForCurrentRound(
      nominee,
      lockedWinnerUserIds: overview.electedUserIds,
    );
  }

  void _syncChatPolling() {
    final active = _overview?.activeElection;
    final sessionSupportsLiveChat = !_isGuidanceCounselorOnly &&
        active != null &&
        active.isActivelyOpen &&
        active.liveChatEnabled;

    if (!sessionSupportsLiveChat) {
      _clearAndStopLiveChat();
      return;
    }

    if (!_chatExpanded) {
      _stopChatPolling();
      return;
    }

    _chatPollTimer ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchLiveChatSilently(),
    );
  }

  void _maybeSyncAuthRoleOnCompletion(ActiveElectionOverview nextOverview) {
    final active = nextOverview.activeElection;
    final completed = nextOverview.completedElection;

    if (completed != null) {
      if (_lastSyncedCompletedElectionId != completed.id) {
        _lastSyncedCompletedElectionId = completed.id;
        _lastObservedOpenOrPausedElectionId = null;
        unawaited(widget.authController.refreshProfileSilently());
      }
      return;
    }

    if (_lastObservedOpenOrPausedElectionId != null && active == null) {
      final finishedId = _lastObservedOpenOrPausedElectionId!;
      _lastObservedOpenOrPausedElectionId = null;
      if (_lastSyncedCompletedElectionId != finishedId) {
        _lastSyncedCompletedElectionId = finishedId;
        unawaited(widget.authController.refreshProfileSilently());
      }
      return;
    }

    if (active != null && (active.isActivelyOpen || active.isPaused)) {
      _lastObservedOpenOrPausedElectionId = active.id;

      final currentUserId = widget.authController.profile?.user.id;
      final currentRoleApi =
          widget.authController.profile?.verifiedRole?.apiValue;
      if (currentUserId != null && currentUserId > 0) {
        for (final seat in nextOverview.seats) {
          if (seat.isElected &&
              seat.winnerUserId == currentUserId &&
              seat.key.isNotEmpty &&
              seat.key != currentRoleApi &&
              _lastSyncedWonSeatKey != seat.key) {
            _lastSyncedWonSeatKey = seat.key;
            unawaited(widget.authController.refreshProfileSilently());
            break;
          }
        }
      }
      return;
    }

    if (active == null &&
        !_didInitialResolvedSlateSync &&
        nextOverview.seats.any((seat) => seat.isResolved)) {
      _didInitialResolvedSlateSync = true;
      unawaited(widget.authController.refreshProfileSilently());
    }
  }

  Future<void> _loadElection() async {
    if (_isGuidanceCounselorOnly) {
      setState(() {
        _isLoading = false;
        _overview = null;
        _armedCandidateId = null;
        _clearAndStopLiveChat();
      });
      return;
    }

    setState(() {
      _isLoading = _overview == null;
      _errorMessage = null;
    });

    try {
      final res = await widget.electionsService.fetchActiveElection();
      if (!mounted) return;

      final active = res.activeElection;
      final isActivelyOpen = active != null && active.isActivelyOpen;
      final supportsChat = isActivelyOpen && active.liveChatEnabled;

      _maybeSyncAuthRoleOnCompletion(res);

      setState(() {
        _overview = res;
        _isLoading = false;
        if (!supportsChat) {
          _clearAndStopLiveChat();
        }
        if (!isActivelyOpen) {
          _armedCandidateId = null;
        } else if (_armedCandidateId != null) {
          final armedStillValid = active.candidatesForCurrentSeat.any(
            (n) =>
                n.id == _armedCandidateId &&
                _canArmNominee(res, active, n),
          );
          if (!armedStillValid) {
            _armedCandidateId = null;
          }
        }
      });

      _syncChatPolling();
      if (supportsChat && _chatExpanded) {
        await _fetchLiveChatSilently();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is ApiException &&
            (error.statusCode == 401 ||
                error.statusCode == 403 ||
                error.statusCode == 422)) {
          _clearAndStopLiveChat();
          _armedCandidateId = null;
        }
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
    if (!mounted) return;
    if (_isGuidanceCounselorOnly ||
        active == null ||
        !active.isActivelyOpen ||
        !active.liveChatEnabled) {
      setState(_clearAndStopLiveChat);
      return;
    }

    try {
      final msgs = await widget.electionsService.fetchLiveChat(active.id);
      if (!mounted) return;
      final latestActive = _overview?.activeElection;
      if (latestActive == null ||
          !latestActive.isActivelyOpen ||
          !latestActive.liveChatEnabled) {
        setState(_clearAndStopLiveChat);
        return;
      }
      setState(() => _chatMessages = msgs);
    } on ApiException catch (e) {
      if (e.statusCode == 422 || e.statusCode == 403 || e.statusCode == 404) {
        // Election paused, closed, or completed -> stop polling & wipe chat immediately.
        if (mounted) {
          setState(_clearAndStopLiveChat);
          await _loadElection();
        } else {
          _stopChatPolling();
        }
      }
    } catch (_) {
      // Silent retry on next poll tick while session remains open.
    }
  }

  Future<void> _toggleChatSheet() async {
    final active = _overview?.activeElection;
    if (_isGuidanceCounselorOnly ||
        active == null ||
        !active.isActivelyOpen ||
        !active.liveChatEnabled) {
      setState(_clearAndStopLiveChat);
      return;
    }

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
    if (_isGuidanceCounselorOnly ||
        active == null ||
        !active.isActivelyOpen ||
        !active.liveChatEnabled) {
      setState(_clearAndStopLiveChat);
      return;
    }
    if (text.isEmpty || _isSendingChat) return;

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
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 422 ||
          error.statusCode == 403 ||
          error.statusCode == 404) {
        setState(_clearAndStopLiveChat);
        unawaited(_loadElection());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
    ActiveElectionOverview overview,
    ActiveElectionSession session,
    ElectionNominee nominee,
  ) async {
    if (_isCastingVote || !_canArmNominee(overview, session, nominee)) return;
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
      await _loadElection();
    } finally {
      if (mounted) {
        setState(() => _isCastingVote = false);
      }
    }
  }

  Future<void> _promptSelfNomination(
    ActiveElectionOverview overview,
    ActiveElectionSession session,
  ) async {
    final user = widget.authController.profile?.user;
    if (user == null ||
        _isNominating ||
        !_canNominateForSession(overview, session)) {
      return;
    }

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
      await _loadElection();
    } finally {
      if (mounted) {
        setState(() => _isNominating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    if (_isGuidanceCounselorOnly) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_outlined, size: 42, color: p.primary),
                const SizedBox(height: 10),
                Text(
                  'Coordination-Only Access',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chapter elections are reserved for verified CPF student members and the presiding Club Adviser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
    final completedSession = (active != null && active.isCompleted)
        ? active
        : overview.completedElection;
    final showSessionChat = active != null &&
        active.isActivelyOpen &&
        active.liveChatEnabled &&
        !_isGuidanceCounselorOnly;

    final userId = widget.authController.profile?.user.id;
    final isCurrentUserAlreadyElected = overview.isUserAlreadyElected(userId);
    final canNominateNow =
        active != null && _canNominateForSession(overview, active);

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
                if (completedSession != null &&
                    (active == null || active.isCompleted))
                  FadeSlideIn(
                    child: _buildCompletedSessionCard(
                      p,
                      overview,
                      completedSession,
                    ),
                  )
                else if (active == null)
                  FadeSlideIn(child: _buildNoActiveSessionCard(p, overview))
                else if (active.isPaused) ...[
                  FadeSlideIn(child: _buildMeetingHeader(p, overview, active)),
                  const SizedBox(height: 12),
                  _buildPausedNoticeCard(p, active),
                  const SizedBox(height: 18),
                  _buildSeatSlateCard(
                    p,
                    overview.seats,
                    isSessionActivelyOpen: false,
                  ),
                ] else ...[
                  FadeSlideIn(child: _buildMeetingHeader(p, overview, active)),
                  const SizedBox(height: 10),
                  _buildAdviserPresidingBar(p, active),
                  if (active.isNominationPhase &&
                      isCurrentUserAlreadyElected &&
                      !_isClubAdviser) ...[
                    const SizedBox(height: 10),
                    _buildAlreadyElectedBanner(p),
                  ],
                  if (canNominateNow) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor:
                            p.themeId.isDark ? p.bg : Colors.white,
                      ),
                      onPressed: _isNominating
                          ? null
                          : () => _promptSelfNomination(overview, active),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        'Self-Nominate for ${active.currentPositionLabel ?? 'Seat'}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildAmongUsVotingGrid(p, overview, active),
                  const SizedBox(height: 18),
                  _buildSeatSlateCard(
                    p,
                    overview.seats,
                    isSessionActivelyOpen: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showSessionChat) _buildCollapsibleSessionChat(p),
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
          _buildSeatSlateCard(
            p,
            overview.seats,
            isSessionActivelyOpen: false,
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedSessionCard(
    CpfPalette p,
    ActiveElectionOverview overview,
    ActiveElectionSession completed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: p.heroCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: p.success.withValues(alpha: 0.65),
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
                      color: p.success.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: p.success,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ELECTION COMPLETED',
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
                  if (completed.academicYear.isNotEmpty)
                    Text(
                      'AY ${completed.academicYear}',
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
                completed.title,
                style: TextStyle(
                  color: p.heroText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'This chapter election has concluded, ephemeral session chat has been cleared, and newly elected officer roles are active.',
                style: TextStyle(
                  color: p.heroMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (overview.seats.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSeatSlateCard(
            p,
            overview.seats,
            isSessionActivelyOpen: false,
          ),
        ],
      ],
    );
  }

  Widget _buildPausedNoticeCard(CpfPalette p, ActiveElectionSession active) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pause_circle_filled_rounded, size: 26, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Floor Paused by Presiding Adviser',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nominations, voting, and ephemeral session chat are temporarily suspended for ${active.currentPositionLabel ?? 'the current seat'}. Pull down to refresh once the session resumes.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: p.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyElectedBanner(CpfPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 18, color: p.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Officer seat locked: you have already been elected in this session and cannot run for another seat.',
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

  Widget _buildMeetingHeader(
    CpfPalette p,
    ActiveElectionOverview overview,
    ActiveElectionSession active,
  ) {
    final canVoteNow = _canVoteInSession(active);
    final phaseLabel = active.isPaused
        ? 'SESSION PAUSED'
        : switch (active.currentPhase) {
            'nomination' => 'NOMINATION FLOOR',
            'tie_breaker' || 'adviser_tie_breaker' =>
              'TIE-BREAKER • ROUND ${active.roundNumber}',
            'runoff' => 'RUNOFF VOTE • ROUND ${active.roundNumber}',
            _ => active.hasRunoffContenders
                ? 'RUNOFF VOTE • ROUND ${active.roundNumber}'
                : 'EMERGENCY VOTE • ROUND ${active.roundNumber}',
          };

    final phaseColor = active.isPaused
        ? p.accent
        : (active.isTieBreaker || active.hasRunoffContenders)
            ? p.error
            : active.isNominationPhase
                ? p.accent
                : p.success;

    final phaseIcon = active.isPaused
        ? Icons.pause_circle_filled_rounded
        : Icons.campaign_rounded;

    final String statusSubtitle;
    if (active.isPaused) {
      statusSubtitle = 'Session is paused — floor actions are temporarily locked.';
    } else if (active.hasVotedCurrentRound) {
      statusSubtitle = 'Your ballot for this round is locked in.';
    } else if (canVoteNow) {
      statusSubtitle = (active.isTieBreaker && _isClubAdviser)
          ? 'Tie-breaker deadlock: tap a tied contender below to cast the deciding Adviser vote.'
          : 'Tap a nominee card below, then tap the green check to confirm your vote.';
    } else if (active.isNominationPhase) {
      statusSubtitle = _canNominateForSession(overview, active)
          ? 'Nominations are open before floor voting begins.'
          : 'Floor nominations are in progress.';
    } else if (_isClubAdviser && !active.isTieBreaker) {
      statusSubtitle =
          'Presiding over live student tally (Adviser votes only on tie-breakers).';
    } else {
      statusSubtitle = 'Observing live floor tally.';
    }

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
                    Icon(phaseIcon, size: 15, color: phaseColor),
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
              if (active.academicYear.isNotEmpty)
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
            statusSubtitle,
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
                  ? 'Adviser Presiding: Tie-breaker active — Adviser casts the deciding vote on deadlocks.'
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
    ActiveElectionOverview overview,
    ActiveElectionSession active,
  ) {
    final candidates = active.candidatesForCurrentSeat;

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

    final lockedUserIds = overview.electedUserIds;
    final runoffFilterActive = active.isTieBreaker || active.hasRunoffContenders;

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
                  canArm: _canArmNominee(overview, active, candidates[i]),
                  isRunoffRound: runoffFilterActive,
                  isAlreadyElectedElsewhere: candidates[i].userId > 0 &&
                      lockedUserIds.contains(candidates[i].userId),
                  isSubmitting: _isCastingVote,
                  onTapCard: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _armedCandidateId = _armedCandidateId == candidates[i].id
                          ? null
                          : candidates[i].id;
                    });
                  },
                  onConfirm: () =>
                      _confirmVote(overview, active, candidates[i]),
                  onCancel: () => setState(() => _armedCandidateId = null),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSeatSlateCard(
    CpfPalette p,
    List<ElectionSeat> seats, {
    required bool isSessionActivelyOpen,
  }) {
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
                        : seat.isVacant
                            ? Icons.person_off_outlined
                            : seat.isSkipped
                                ? Icons.remove_circle_outline_rounded
                                : (seat.isCurrent && isSessionActivelyOpen)
                                    ? Icons.play_circle_fill_rounded
                                    : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: seat.isElected
                        ? p.success
                        : seat.isVacant
                            ? p.accent
                            : (seat.isCurrent && isSessionActivelyOpen)
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
                        fontWeight: (seat.isCurrent && isSessionActivelyOpen)
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: (seat.isCurrent && isSessionActivelyOpen) ||
                                seat.isElected
                            ? p.text
                            : p.muted,
                      ),
                    ),
                  ),
                  if (seat.isElected)
                    Flexible(
                      child: Text(
                        (seat.winnerName != null &&
                                seat.winnerName!.trim().isNotEmpty)
                            ? seat.winnerName!
                            : 'Elected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.success,
                        ),
                      ),
                    )
                  else if (seat.isVacant)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Vacant',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.accent,
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

  Widget _buildCollapsibleSessionChat(CpfPalette p) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: p.themeId.isDark ? 0.35 : 0.1),
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
                          'Session-only chat • Clears when paused or closed',
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
                          'No live messages yet. Messages stay in temporary RAM cache only and auto-wipe when this election pauses or closes.',
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
    required this.isRunoffRound,
    required this.isAlreadyElectedElsewhere,
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
  final bool isRunoffRound;
  final bool isAlreadyElectedElsewhere;
  final bool isSubmitting;
  final VoidCallback onTapCard;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final notInRunoff = isRunoffRound && !nominee.isTieContender;
    final isDimmed = notInRunoff || isAlreadyElectedElsewhere;

    final borderColor = isMyVote
        ? p.success
        : isArmed
            ? p.accent
            : (isRunoffRound && nominee.isTieContender)
                ? p.error.withValues(alpha: 0.65)
                : p.border;

    return Opacity(
      opacity: isDimmed ? 0.55 : 1.0,
      child: AnimatedContainer(
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
              color: borderColor.withValues(
                alpha: (isMyVote || isArmed) ? 0.22 : 0.04,
              ),
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
                  if (isRunoffRound && nominee.isTieContender) ...[
                    const SizedBox(height: 6),
                    Text(
                      'RUNOFF CONTENDER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.error,
                      ),
                    ),
                  ] else if (notInRunoff) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Not in runoff round',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.muted,
                      ),
                    ),
                  ] else if (isAlreadyElectedElsewhere) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Already elected to earlier seat',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.success,
                      ),
                    ),
                  ] else if (!nominee.isAccepted) ...[
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
                    child: (isArmed && canArm)
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
      ),
    );
  }
}
