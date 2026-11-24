import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/models/membership_payment.dart';
import 'package:cpf_mobile/screens/messenger_gc_checklist_screen.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/membership_payment_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/animated_entrance.dart';

enum _PaymentsTab { memberSubmit, treasurerQueue }

/// Dues & Payments tab: Member payment submission + Treasurer validation list,
/// plus quick Officer entry to the A–Z Messenger GC Checklist.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.authController,
    required this.paymentService,
  });

  final AuthController authController;
  final MembershipPaymentService paymentService;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController =
      TextEditingController(text: 'Membership Dues');
  final _amountController = TextEditingController(text: '100');
  final _referenceController = TextEditingController();

  PaymentsOverview? _overview;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  int? _selectedDestinationId;
  _PaymentsTab _activeTab = _PaymentsTab.memberSubmit;
  final Set<int> _validatingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = _overview == null;
      _errorMessage = null;
    });

    try {
      final res = await widget.paymentService.fetchPayments();
      if (!mounted) return;
      setState(() {
        _overview = res;
        if (_selectedDestinationId == null && res.destinations.isNotEmpty) {
          _selectedDestinationId = res.destinations.first.id;
        }
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

  Future<void> _submitPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final destinationId = _selectedDestinationId;
    if (destinationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an approved payment channel.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      await widget.paymentService.submitPayment(
        destinationId: destinationId,
        purpose: _purposeController.text,
        amount: amount,
        referenceNumber: _referenceController.text,
      );
      if (!mounted) return;
      _referenceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted for Treasurer validation.'),
        ),
      );
      await _loadPayments();
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleValidation(
    PaymentSubmissionItem item,
    String status,
  ) async {
    if (_validatingIds.contains(item.id)) return;
    setState(() => _validatingIds.add(item.id));

    try {
      await HapticFeedback.mediumImpact();
      await widget.paymentService.validatePayment(
        paymentId: item.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'validated'
                ? 'Validated payment for ${item.memberName}.'
                : 'Marked payment from ${item.memberName} as rejected.',
          ),
        ),
      );
      await _loadPayments();
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
        setState(() => _validatingIds.remove(item.id));
      }
    }
  }

  void _openGcChecklist() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessengerGcChecklistScreen(
          service: widget.paymentService,
          baseUrl: widget.authController.apiConfig.baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final profile = widget.authController.profile;
    final isOfficer = profile?.isOfficerOrAdviser ?? false;

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
                onPressed: _loadPayments,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final overview = _overview!;
    final showValidationTab =
        overview.canValidatePayments || overview.canAuditFinances;
    final pendingCount =
        overview.validationQueue.where((i) => i.isPending).length;

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _loadPayments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          FadeSlideIn(
            child: _buildSummaryBanner(p, overview, isOfficer),
          ),
          if (showValidationTab) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SubTabPill(
                      label: 'My Dues & Submit',
                      selected: _activeTab == _PaymentsTab.memberSubmit,
                      onTap: () =>
                          setState(() => _activeTab = _PaymentsTab.memberSubmit),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _SubTabPill(
                      label: 'Treasurer List ($pendingCount)',
                      selected: _activeTab == _PaymentsTab.treasurerQueue,
                      onTap: () => setState(
                        () => _activeTab = _PaymentsTab.treasurerQueue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: (_activeTab == _PaymentsTab.treasurerQueue &&
                    showValidationTab)
                ? _buildTreasurerQueue(p, overview)
                : _buildMemberSubmitSection(p, overview),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(
    CpfPalette p,
    PaymentsOverview overview,
    bool isOfficer,
  ) {
    final settled = overview.hasPaidDues;

    return Container(
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.heroCardElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  settled ? Icons.verified_rounded : Icons.payments_outlined,
                  color: settled ? p.success : p.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settled
                          ? 'Chapter Dues Settled'
                          : 'Chapter Dues Pending',
                      style: TextStyle(
                        color: p.heroText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overview.campusName ?? 'CPF Chapter Finance',
                      style: TextStyle(color: p.heroMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isOfficer) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.heroText,
                  backgroundColor: p.heroCardElevated,
                  side: BorderSide(color: p.accent.withValues(alpha: 0.45)),
                ),
                onPressed: _openGcChecklist,
                icon: Icon(Icons.checklist_rtl_rounded, color: p.accent),
                label: const Text('Open Messenger GC A–Z Checklist'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberSubmitSection(CpfPalette p, PaymentsOverview overview) {
    return Column(
      key: const ValueKey<String>('member_submit_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Approved Payment Channels',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: p.text,
          ),
        ),
        const SizedBox(height: 8),
        if (overview.destinations.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'No Adviser-approved payment channels are active yet for this campus.',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          )
        else ...[
          for (final dest in overview.destinations) ...[
            _DestinationCard(
              destination: dest,
              selected: _selectedDestinationId == dest.id,
              onSelect: () => setState(() => _selectedDestinationId = dest.id),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Submit Receipt Reference',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _purposeController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter payment purpose.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountController,
                          enabled: !_isSubmitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (PHP)',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          validator: (v) {
                            final parsed = double.tryParse(v?.trim() ?? '');
                            if (parsed == null || parsed < 1) {
                              return 'Min 1';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _referenceController,
                          enabled: !_isSubmitting,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Reference No.',
                            hintText: 'GCASH-123456',
                            prefixIcon: Icon(Icons.receipt_long_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter reference no.'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitPayment,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.themeId.isDark ? p.bg : Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Submit Payment'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'My Submitted Payments (${overview.mySubmissions.length})',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: p.text,
          ),
        ),
        const SizedBox(height: 8),
        if (overview.mySubmissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'No payment submissions recorded yet.',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          )
        else
          for (final item in overview.mySubmissions) ...[
            _SubmissionCard(item: item, canValidate: false),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildTreasurerQueue(CpfPalette p, PaymentsOverview overview) {
    return Column(
      key: const ValueKey<String>('treasurer_queue_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Campus Payment Validation Queue',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: p.text,
          ),
        ),
        const SizedBox(height: 8),
        if (overview.validationQueue.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'No member payment submissions in the campus queue yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted),
            ),
          )
        else
          for (final item in overview.validationQueue) ...[
            _SubmissionCard(
              item: item,
              canValidate: overview.canValidatePayments && item.isPending,
              isBusy: _validatingIds.contains(item.id),
              onApprove: () => _handleValidation(item, 'validated'),
              onReject: () => _handleValidation(item, 'rejected'),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SubTabPill extends StatelessWidget {
  const _SubTabPill({
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
    return Material(
      color: selected ? p.card : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? p.primary : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.selected,
    required this.onSelect,
  });

  final PaymentChannelDestination destination;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? p.primary : p.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? p.primary : p.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${destination.channel} • ${destination.accountName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.accountNumber,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy account number',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: destination.accountNumber),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied ${destination.accountNumber}'),
                    ),
                  );
                },
                icon: Icon(Icons.copy_rounded, size: 18, color: p.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.item,
    required this.canValidate,
    this.isBusy = false,
    this.onApprove,
    this.onReject,
  });

  final PaymentSubmissionItem item;
  final bool canValidate;
  final bool isBusy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final statusColor = switch (item.status) {
      'validated' => p.success,
      'rejected' => p.error,
      _ => p.accent,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.purpose} • PHP ${item.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ref: ${item.referenceNumber}${item.channel != null ? ' (${item.channel})' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: p.muted,
            ),
          ),
          if (item.treasurerNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'Note: ${item.treasurerNotes}',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ],
          if (canValidate) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.error,
                      side: BorderSide(color: p.error.withValues(alpha: 0.5)),
                      minimumSize: const Size(0, 38),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.success,
                      foregroundColor:
                          p.themeId.isDark ? p.bg : Colors.white,
                      minimumSize: const Size(0, 38),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Validate'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
