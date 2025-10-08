import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../widgets/gradient_text.dart';
import '../utils/add_sample_templates.dart';
import '../config/admin_config.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _isLoading = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    
    // Security check - only allow admin users
    if (!_isAdminUser()) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          title: Text(
            'Access Denied',
            style: TextStyle(color: theme.text),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Admin Access Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to access this page.',
                style: TextStyle(
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        title: GradientText(
          text: 'Admin Panel',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          currentThemeIndex: ref.watch(themeIndexProvider),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add standard workout templates for all users',
              style: TextStyle(
                fontSize: 16,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            
            // Add Sample Templates Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.textSecondary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle,
                        color: theme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Add Sample Templates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This will add 4 awesome workout templates:\n'
                    '• Upper Body Workout (60 min)\n'
                    '• Legs Focus Workout (70 min)\n'
                    '• Push Day Workout (65 min)\n'
                    '• Pull Day Workout (65 min)',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addSampleTemplates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Adding templates...'),
                              ],
                            )
                          : const Text(
                              'Add Sample Templates',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Status Message
            if (_status.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.contains('Error') 
                      ? theme.error.withOpacity(0.1)
                      : theme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status.contains('Error') 
                        ? theme.error.withOpacity(0.3)
                        : theme.success.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _status.contains('Error') 
                          ? Icons.error_outline 
                          : Icons.check_circle_outline,
                      color: _status.contains('Error') 
                          ? theme.error 
                          : theme.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status,
                        style: TextStyle(
                          fontSize: 14,
                          color: _status.contains('Error') 
                              ? theme.error 
                              : theme.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
            const Spacer(),
            
            // Warning
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Warning: Only add templates once! Duplicate templates will create multiple entries in the database.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _addSampleTemplates() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });
    
    try {
      await addSampleTemplates();
      setState(() {
                                _status = 'Successfully added 4 awesome workout templates!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error adding templates: $e';
        _isLoading = false;
      });
    }
  }

  // Check if current user has admin privileges
  bool _isAdminUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    // Använd säker config-fil för admin emails
    return AdminConfig.isAdminEmail(user.email ?? '');
  }
}