import 'package:flutter/material.dart';
import '../../services/report_user_service.dart';

class ReportUserDialog extends StatefulWidget {
  final String reportedUserId;

  const ReportUserDialog({Key? key, required this.reportedUserId}) : super(key: key);

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  final ReportUserService _reportUserService = ReportUserService();
  final List<String> _reasons = [
    'Spam',
    'Harassment or bullying',
    'Hate speech or symbols',
    'Nudity or sexual activity',
    'Violence or dangerous organizations',
    'False information',
    'Scam or fraud',
    'Intellectual property violation',
    'Suicide or self-injury',
    'Other',
  ];
  String? _selectedReason;
  String _customReason = '';
  bool _isSubmitting = false;

  void _submitReport() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);
    try {
      await _reportUserService.reportUser(
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason!,
        details: _selectedReason == 'Other' ? _customReason : null,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report User',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ..._reasons.map((reason) => RadioListTile<String>(
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) => setState(() => _selectedReason = value),
                  title: Text(reason, style: const TextStyle(color: Colors.white)),
                  activeColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                )),
            if (_selectedReason == 'Other')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  onChanged: (val) => setState(() => _customReason = val),
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue...',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _selectedReason == null || (_selectedReason == 'Other' && _customReason.trim().isEmpty)
                    ? null
                    : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 