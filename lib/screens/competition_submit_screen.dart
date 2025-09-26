// lib/screens/competition_submit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class CompetitionSubmitScreen extends StatefulWidget {
  const CompetitionSubmitScreen({super.key});

  @override
  State<CompetitionSubmitScreen> createState() => _CompetitionSubmitScreenState();
}

class _CompetitionSubmitScreenState extends State<CompetitionSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController();
  final summaryCtrl = TextEditingController();
  final repoCtrl = TextEditingController();
  final driveCtrl = TextEditingController();

  File? _video;
  File? _zip;
  List<File> _attachments = [];
  bool _submitting = false;
  String? _error;

  String competitionId = '';
  String? competitionTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read competitionId from arguments if present
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final id = args['competitionId']?.toString();
      if (id != null && id.isNotEmpty) competitionId = id;
      competitionTitle = args['competitionTitle']?.toString();
    }
  }

  Future<void> _pickVideo() async {
    try {
      final res = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
          dialogTitle: 'Select Video File'
      );
      if (res != null && res.files.single.path != null) {
        setState(() {
          _video = File(res.files.single.path!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Video file selected successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Error selecting video: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _pickZip() async {
    try {
      final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
          allowMultiple: false,
          dialogTitle: 'Select ZIP File'
      );
      if (res != null && res.files.single.path != null) {
        setState(() {
          _zip = File(res.files.single.path!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('ZIP file selected successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Error selecting ZIP: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _pickAttachments() async {
    try {
      final res = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          dialogTitle: 'Select Additional Files'
      );
      if (res != null) {
        setState(() {
          _attachments.addAll(res.files.where((f) => f.path != null).map((f) => File(f.path!)));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.attach_file, color: Colors.white),
                const SizedBox(width: 8),
                Text('${res.files.length} files added to attachments'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Error selecting attachments: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _removeAttachment(int idx) {
    setState(() {
      _attachments.removeAt(idx);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _submit() async {
    if (_video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.video_library, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select a video file to submit'),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      final res = await ApiService.uploadSubmission(
        video: _video!,
        competitionId: competitionId.isNotEmpty ? competitionId : null,
        title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null,
        summary: summaryCtrl.text.trim().isNotEmpty ? summaryCtrl.text.trim() : null,
        repoUrl: repoCtrl.text.trim().isNotEmpty ? repoCtrl.text.trim() : null,
        driveUrl: driveCtrl.text.trim().isNotEmpty ? driveCtrl.text.trim() : null,
        attachments: _attachments,
        zip: _zip,
        token: token,
      );

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.cloud_upload, color: Colors.white),
                SizedBox(width: 8),
                Text('Project submitted successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
        // Pop back to competitions screen and notify parent that a submission occurred
        if (mounted) Navigator.pop(context, {'submitted': true});
      } else {
        final msg = res['message'] ?? 'Upload failed';
        setState(() => _error = msg.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text(msg.toString()),
              ],
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 8),
              Text('Network error: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _topHeaderContent() {
    final title = competitionTitle ?? 'Submit Project';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(gradient: AppTheme.gradient, shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.upload_file, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    summaryCtrl.dispose();
    repoCtrl.dispose();
    driveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make page full width/height so gradient covers entire screen
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const SizedBox.shrink(),
        leading: Container(),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Top translucent card header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: _topHeaderContent(),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Title
                        Row(
                          children: [
                            const Icon(Icons.title, size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            const Text('Project Title', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                            const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: titleCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter your project title',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.02),
                            prefixIcon: const Icon(Icons.edit, color: Colors.white70),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) return 'Title must be at least 3 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Project Summary
                        Row(
                          children: [
                            const Icon(Icons.description, size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            const Text('Project Summary', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            const Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: summaryCtrl,
                          minLines: 3,
                          maxLines: 6,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Describe your project, what it does, how it works, key features...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.02),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(top: 12, left: 12),
                              child: Icon(Icons.notes, color: Colors.white70),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Repository URL
                        Row(
                          children: [
                            const Icon(Icons.code, size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            const Text('Repository URL', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            const Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: repoCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'https://github.com/username/project',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.02),
                            prefixIcon: const Icon(Icons.link, color: Colors.white70),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Drive URL
                        Row(
                          children: [
                            const Icon(Icons.cloud, size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            const Text('Drive/Cloud URL', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            const Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: driveCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'https://drive.google.com/...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.02),
                            prefixIcon: const Icon(Icons.cloud_download, color: Colors.white70),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // File Uploads Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.folder_open, size: 20, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  const Text('File Uploads', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Video File (Required)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _video != null ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.01)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.video_library,
                                          color: _video != null ? Colors.white70 : Colors.white70,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Project Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _pickVideo,
                                          icon: Icon(_video != null ? Icons.change_circle : Icons.video_library_outlined, size: 16, color: Colors.white),
                                          label: Text(_video != null ? 'Change Video' : 'Select Video', style: const TextStyle(color: Colors.white)),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.06),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_video != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.file_present, size: 16, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _video!.path.split('/').last,
                                              style: const TextStyle(color: Colors.white70),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatFileSize(_video!.lengthSync()),
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Demo video of your project (required)',
                                        style: TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ZIP File (Optional)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.01)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.archive, color: Colors.white70, size: 20),
                                        const SizedBox(width: 8),
                                        const Text('Project Archive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 4),
                                        const Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _pickZip,
                                          icon: Icon(_zip != null ? Icons.change_circle : Icons.archive, size: 16, color: Colors.white),
                                          label: Text(_zip != null ? 'Change ZIP' : 'Select ZIP', style: const TextStyle(color: Colors.white)),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.06),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_zip != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.file_present, size: 16, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _zip!.path.split('/').last,
                                              style: const TextStyle(color: Colors.white70),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatFileSize(_zip!.lengthSync()),
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Compressed archive of source code or additional files',
                                        style: TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Additional Attachments
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.01)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.attach_file, color: Colors.white70, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Attachments (${_attachments.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 4),
                                        const Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _pickAttachments,
                                          icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                                          label: const Text('Add Files', style: TextStyle(color: Colors.white)),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.06),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_attachments.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: List.generate(_attachments.length, (i) {
                                          final f = _attachments[i];
                                          // translucent pill instead of bright Chip
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.02),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white.withOpacity(0.01)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.insert_drive_file, size: 16, color: Colors.white70),
                                                const SizedBox(width: 8),
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 160),
                                                  child: Text(
                                                    f.path.split('/').last,
                                                    style: const TextStyle(color: Colors.white70),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () => _removeAttachment(i),
                                                  child: const Icon(Icons.close, size: 16, color: Colors.white70),
                                                )
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Screenshots, documentation, or other supporting files',
                                        style: TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Submit Button (subtle translucent style)
                        TextButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.upload, size: 18, color: Colors.white),
                          label: Text(_submitting ? 'Submitting Project...' : 'Submit Project', style: const TextStyle(color: Colors.white)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.06),
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
                            label: const Text('Back to Competition', style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
