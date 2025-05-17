import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final User user;
  final String email;

  const ProfileCompletionScreen(
      {required this.user, required this.email, super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  DateTime? _birthDate;
  String _countryCode = '+1'; // Default country code (e.g., US)

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CountryCodePicker(
                    onChanged: (country) {
                      setState(() {
                        _countryCode = country.dialCode ?? '+1';
                      });
                    },
                    dialogBackgroundColor: Colors.black,
                    barrierColor: Colors.black,
                    initialSelection: 'US',
                    favorite: ['+1', '+91'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        focusColor: Colors.grey,
                        hintText: '1234567890',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        // Validate phone number without country code
                        if (!RegExp(r'^[0-9]{6,15}$').hasMatch(value)) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  _birthDate == null
                      ? "Select Birth Date"
                      : "Birth Date: ${DateFormat('yyyy-MM-dd').format(_birthDate!)}",
                  style: TextStyle(color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _birthDate = date);
                  }
                },
                tileColor: Colors.grey[900],
                textColor: Colors.white,
              ),
              const SizedBox(height: 50),
              // Submit Button
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: _submitProfile,
                  child: const Text(
                    "Complete Profile",
                    style: TextStyle(fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Cancel Button
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomeDashboard()));
                  },
                  child: const Text(
                    "Cancel",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitProfile() async {
    if (_formKey.currentState!.validate() && _birthDate != null) {
      // Save to Supabase
      await AuthService.client().from('users').upsert({
        'id': widget.user.id,
        'email': widget.email,
        'phone': _phoneController.text,
        'birthdate': _birthDate!.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Navigate to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeDashboard()),
      );
    }
  }
}
