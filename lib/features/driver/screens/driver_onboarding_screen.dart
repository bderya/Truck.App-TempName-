import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../providers/driver_booking_provider.dart';
import '../providers/driver_onboarding_provider.dart';

/// Multi-step driver onboarding: Full Name, Plate Number, Truck Type, License photo, Vehicle Registration photo.
/// Saves to users (is_verified: false, status: 'pending') and tow_trucks.
class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key, this.initialFullName});

  final String? initialFullName;

  @override
  ConsumerState<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  int _currentStep = 0;
  String _truckType = 'standard';
  File? _licenseFile;
  File? _vehicleRegFile;
  bool _loading = false;
  String? _error;

  static const List<String> _truckTypes = ['standard', 'heavy', 'motorcycle'];
  static const Map<String, String> _truckLabels = {
    'standard': 'Standard',
    'heavy': 'Heavy',
    'motorcycle': 'Motorcycle',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialFullName != null && widget.initialFullName!.isNotEmpty) {
      _nameController.text = widget.initialFullName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLicense) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() {
      if (isLicense) {
        _licenseFile = File(file.path);
      } else {
        _vehicleRegFile = File(file.path);
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_licenseFile == null || _vehicleRegFile == null) {
      setState(() => _error = 'Please add both photos');
      return;
    }
    final user = await ref.read(currentAppUserProvider.future);
    if (user == null) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await ref.read(driverOnboardingServiceProvider).submitOnboarding(
            userId: user.id,
            fullName: _nameController.text.trim(),
            plateNumber: _plateController.text.trim(),
            truckType: _truckType,
            licenseImageFile: _licenseFile!,
            vehicleRegistrationFile: _vehicleRegFile!,
          );
      if (!mounted) return;
      ref.invalidate(currentAuthUserTowTruckProvider);
      ref.invalidate(currentAppUserProvider);
      ref.read(driverIdProvider.notifier).state = user.id;
      ref.invalidate(currentDriverUserProvider);
      ref.invalidate(currentDriverTruckProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver registration'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep == 0) {
                if (_nameController.text.trim().isEmpty) {
                  setState(() => _error = 'Enter your full name');
                  return;
                }
              }
              if (_currentStep == 1) {
                if (_plateController.text.trim().isEmpty) {
                  setState(() => _error = 'Enter plate number');
                  return;
                }
              }
              if (_currentStep < 4) {
                setState(() {
                  _currentStep++;
                  _error = null;
                });
              } else {
                _submit();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                  _error = null;
                });
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : details.onStepContinue,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_currentStep == 4 ? 'Submit' : 'Next'),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Full name'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Step(
                title: const Text('Plate number'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle plate number',
                    hintText: '34 ABC 123',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Step(
                title: const Text('Truck type'),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _truckTypes.map((type) {
                    return RadioListTile<String>(
                      title: Text(_truckLabels[type] ?? type),
                      value: type,
                      groupValue: _truckType,
                      onChanged: (v) => setState(() => _truckType = v ?? type),
                    );
                  }).toList(),
                ),
              ),
              Step(
                title: const Text('Driver license'),
                isActive: _currentStep >= 3,
                state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                content: ListTile(
                  title: const Text('Upload driver license photo'),
                  subtitle: Text(_licenseFile != null ? p.basename(_licenseFile!.path) : 'No file'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_photo_alternate),
                    onPressed: () => _pickImage(true),
                  ),
                ),
              ),
              Step(
                title: const Text('Vehicle registration'),
                isActive: _currentStep >= 4,
                state: StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Upload vehicle registration / plate photo'),
                      subtitle: Text(_vehicleRegFile != null ? p.basename(_vehicleRegFile!.path) : 'No file'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_photo_alternate),
                        onPressed: () => _pickImage(false),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
