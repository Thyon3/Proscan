import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Assuming you're using go_router

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  String fullName = 'Jessica Miller';
  String email = 'j.miller@email.com';
  String phone = '';
  String country = 'United States';
  String timeZone = 'Pacific Standard Time (PST)';

  final List<String> countries = [
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'Other',
  ];

  final List<String> timeZones = [
    'Pacific Standard Time (PST)',
    'Eastern Standard Time (EST)',
    'Central Standard Time (CST)',
    'Mountain Standard Time (MST)',
    'Alaska Standard Time (AKST)',
    'Hawaii Standard Time (HST)',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 360;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => _showCancelConfirmation(context),
        ),
        title: Text(
          'Edit Profile',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(colorScheme),
                const SizedBox(height: 24),
                _buildFormFields(isSmallScreen, colorScheme, textTheme),
                const SizedBox(height: 32),
                _buildSaveButton(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceVariant,
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1494790108755-2616b612b786?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=100&q=80',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.background, width: 2),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: colorScheme.onPrimary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Change Profile Photo',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(
    bool isSmallScreen,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(
            label: 'Full name',
            value: fullName,
            onChanged: (value) => setState(() => fullName = value),
            isRequired: true,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 20),
          _buildEmailField(colorScheme, textTheme),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'Phone (Optional)',
            value: phone,
            onChanged: (value) => setState(() => phone = value),
            hintText: 'Enter your phone number',
            keyboardType: TextInputType.phone,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'Country/Region (Optional)',
            value: country,
            items: countries,
            onChanged: (value) => setState(() => country = value ?? country),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'Time zone (Optional)',
            value: timeZone,
            items: timeZones,
            onChanged: (value) => setState(() => timeZone = value ?? timeZone),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 8),
          Text(
            'Time zone is detected automatically.',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String value,
    required Function(String) onChanged,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    String? hintText,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
          ),
          keyboardType: keyboardType,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildEmailField(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: email,
          readOnly: true,
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: colorScheme.primary, size: 14),
              const SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: colorScheme.surface,
            icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
            style: TextStyle(color: colorScheme.onSurface),
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Save',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      // In a real app, you would save the data to your backend here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Navigate back after saving using router
      Future.delayed(const Duration(milliseconds: 1500), () {
        context.pop();
      });
    }
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Discard Changes?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'Are you sure you want to discard your changes?',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Keep Editing',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pop(); // Use router to go back
              },
              child: Text(
                'Discard',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
