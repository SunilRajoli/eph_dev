// // lib/screens/competition_register_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../theme/app_theme.dart';
// import '../widgets/custom_button.dart';
// import '../services/api_service.dart';
//
// class CompetitionRegisterScreen extends StatefulWidget {
//   const CompetitionRegisterScreen({super.key});
//
//   @override
//   State<CompetitionRegisterScreen> createState() => _CompetitionRegisterScreenState();
// }
//
// class _CompetitionRegisterScreenState extends State<CompetitionRegisterScreen> {
//   final _formKey = GlobalKey<FormState>();
//
//   // Basic fields
//   String competitionId = '';
//   String competitionTitle = '';
//
//   String registrationType = 'individual'; // 'individual' or 'team'
//   final teamNameCtrl = TextEditingController();
//   final memberEmailCtrl = TextEditingController();
//   List<String> members = []; // list of member emails (excluding leader)
//   final abstractCtrl = TextEditingController();
//
//   bool agree = false;
//   bool loading = false;
//   String errorMsg = '';
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     final args = ModalRoute.of(context)?.settings.arguments;
//     if (args is Map<String, dynamic>) {
//       competitionId = args['competitionId']?.toString() ?? '';
//       competitionTitle = args['competitionTitle']?.toString() ?? '';
//     }
//   }
//
//   @override
//   void dispose() {
//     teamNameCtrl.dispose();
//     memberEmailCtrl.dispose();
//     abstractCtrl.dispose();
//     super.dispose();
//   }
//
//   String? _validateTeamName(String? v) {
//     if (registrationType == 'team') {
//       if (v == null || v.trim().isEmpty) return 'Team name is required';
//       if (v.trim().length < 3) return 'Team name must be at least 3 characters';
//     }
//     return null;
//   }
//
//   String? _validateMemberEmail(String? v) {
//     if (v == null || v.trim().isEmpty) return 'Email required';
//     final re = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
//     if (!re.hasMatch(v.trim())) return 'Enter a valid email';
//     return null;
//   }
//
//   String? _validateAbstract(String? v) {
//     if (v == null || v.trim().isEmpty) return 'Short abstract is required';
//     if (v.trim().length < 20) return 'Abstract must be at least 20 characters';
//     if (v.trim().length > 500) return 'Abstract cannot exceed 500 characters';
//     return null;
//   }
//
//   void _addMember() {
//     final text = memberEmailCtrl.text.trim();
//     final err = _validateMemberEmail(text);
//     if (err != null) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
//       return;
//     }
//     if (members.contains(text)) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member already added')));
//       return;
//     }
//     setState(() {
//       members.add(text);
//       memberEmailCtrl.clear();
//     });
//   }
//
//   void _removeMember(String email) {
//     setState(() {
//       members.remove(email);
//     });
//   }
//
//   Future<void> _submitRegistration() async {
//     setState(() {
//       errorMsg = '';
//     });
//
//     // Validate form fields
//     final isValid = _formKey.currentState?.validate() ?? false;
//     if (!isValid) return;
//
//     if (!agree) {
//       setState(() => errorMsg = 'Please agree to the terms before registering.');
//       return;
//     }
//
//     // Build payload
//     final payload = <String, dynamic>{
//       'competitionId': competitionId,
//       'type': registrationType,
//       'team_name': registrationType == 'team' ? (teamNameCtrl.text.trim()) : null,
//       'members': registrationType == 'team' ? members : null,
//       'abstract': abstractCtrl.text.trim(),
//     };
//
//     try {
//       setState(() => loading = true);
//
//       final res = await ApiService.registerForCompetition(payload);
//       if (res['success'] == true) {
//         // show success dialog
//         if (!mounted) return;
//         showDialog(
//           context: context,
//           builder: (_) => AlertDialog(
//             title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Registered')]),
//             content: Text(res['message'] ?? 'Registration successful.'),
//             actions: [
//               TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
//             ],
//           ),
//         ).then((_) {
//           // navigate back to competitions or details
//           Navigator.popUntil(context, ModalRoute.withName('/competitions'));
//         });
//       } else {
//         setState(() => errorMsg = res['message'] ?? 'Registration failed');
//       }
//     } catch (e) {
//       setState(() => errorMsg = 'Network error: ${e.toString()}');
//     } finally {
//       if (mounted) setState(() => loading = false);
//     }
//   }
//
//   Widget _buildHeader() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(competitionTitle.isNotEmpty ? competitionTitle : 'Competition Registration', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
//         const SizedBox(height: 6),
//         Text('Fill required details to submit your registration.', style: TextStyle(color: Colors.white.withOpacity(0.8))),
//         const SizedBox(height: 12),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width * 0.92;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Register for Competition'),
//         leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
//       ),
//       body: Container(
//         decoration: const BoxDecoration(gradient: AppTheme.gradient),
//         width: double.infinity,
//         height: double.infinity,
//         child: SafeArea(
//           child: Center(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(vertical: 20),
//               child: Container(
//                 width: width,
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.04),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.white.withOpacity(0.06)),
//                 ),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       _buildHeader(),
//                       // Registration type toggle
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ChoiceChip(
//                               label: const Text('Individual'),
//                               selected: registrationType == 'individual',
//                               onSelected: (v) {
//                                 setState(() {
//                                   registrationType = 'individual';
//                                   members.clear();
//                                   teamNameCtrl.clear();
//                                 });
//                               },
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ChoiceChip(
//                               label: const Text('Team'),
//                               selected: registrationType == 'team',
//                               onSelected: (v) {
//                                 setState(() {
//                                   registrationType = 'team';
//                                 });
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//
//                       // Team name only if team
//                       if (registrationType == 'team') ...[
//                         TextFormField(
//                           controller: teamNameCtrl,
//                           style: const TextStyle(color: Colors.white),
//                           validator: _validateTeamName,
//                           decoration: InputDecoration(
//                             hintText: 'Team name',
//                             hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//                             prefixIcon: const Icon(Icons.group, color: Colors.white70),
//                             filled: true,
//                             fillColor: Colors.white.withOpacity(0.02),
//                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                           ),
//                         ),
//                         const SizedBox(height: 10),
//                         // members input
//                         Row(
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: memberEmailCtrl,
//                                 keyboardType: TextInputType.emailAddress,
//                                 style: const TextStyle(color: Colors.white),
//                                 decoration: InputDecoration(
//                                   hintText: 'Add team member email',
//                                   hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//                                   prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
//                                   filled: true,
//                                   fillColor: Colors.white.withOpacity(0.02),
//                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             ElevatedButton(
//                               onPressed: _addMember,
//                               child: const Text('Add'),
//                             )
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (members.isNotEmpty)
//                           Align(
//                             alignment: Alignment.centerLeft,
//                             child: Wrap(
//                               spacing: 8,
//                               runSpacing: 6,
//                               children: members
//                                   .map((m) => Chip(
//                                 backgroundColor: Colors.white.withOpacity(0.06),
//                                 label: Text(m, style: const TextStyle(color: Colors.white70)),
//                                 onDeleted: () => _removeMember(m),
//                               ))
//                                   .toList(),
//                             ),
//                           ),
//                         const SizedBox(height: 12),
//                       ],
//
//                       // Abstract / short description
//                       TextFormField(
//                         controller: abstractCtrl,
//                         style: const TextStyle(color: Colors.white),
//                         validator: _validateAbstract,
//                         maxLines: 6,
//                         maxLength: 500,
//                         decoration: InputDecoration(
//                           hintText: 'Short abstract (what is your project / solution?)',
//                           hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//                           alignLabelWithHint: true,
//                           filled: true,
//                           fillColor: Colors.white.withOpacity(0.02),
//                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                         ),
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       // Terms checkbox
//                       Row(
//                         children: [
//                           Checkbox(
//                             value: agree,
//                             onChanged: (v) => setState(() => agree = v ?? false),
//                           ),
//                           Expanded(
//                             child: Text(
//                               'I confirm that the information is accurate and I agree to the competition rules.',
//                               style: TextStyle(color: Colors.white.withOpacity(0.85)),
//                             ),
//                           )
//                         ],
//                       ),
//
//                       if (errorMsg.isNotEmpty) ...[
//                         const SizedBox(height: 8),
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(10),
//                           decoration: BoxDecoration(color: Colors.red.shade800.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
//                           child: Text(errorMsg, style: const TextStyle(color: Colors.redAccent)),
//                         ),
//                         const SizedBox(height: 8),
//                       ],
//
//                       // Buttons
//                       Row(
//                         children: [
//                           Expanded(
//                             child: CustomButton(
//                               text: loading ? 'Submitting...' : 'Submit Registration',
//                               onPressed: loading ? null : _submitRegistration,
//                               enabled: !loading,
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: OutlinedButton(
//                               style: OutlinedButton.styleFrom(
//                                 foregroundColor: Colors.white,
//                                 side: BorderSide(color: Colors.white.withOpacity(0.06)),
//                               ),
//                               onPressed: loading ? null : () => Navigator.pop(context),
//                               child: const Text('Cancel'),
//                             ),
//                           ),
//                         ],
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
