import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart' show consentVersion;
import '../../../core/providers.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../../legal/legal_document_screen.dart';
import '../providers/driver_booking_provider.dart';
import '../providers/driver_onboarding_provider.dart';
import 'registration_received_screen.dart';

const String _kOnboardingStepKey = 'driver_onboarding_step';

/// Step 1: Personal (name, TCKN, selfie). Step 2: Vehicle (plate, tow type, max weight).
/// Step 3: License photo. Step 4: Vehicle reg photo. Step 5: Payout (IBAN, tax ID). Step 6: Submit.
class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key, this.initialFullName});

  final String? initialFullName;

  @override
  ConsumerState<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tcknController = TextEditingController();
  final _plateController = TextEditingController();
  final _maxWeightController = TextEditingController();
  final _ibanController = TextEditingController();
  final _taxIdController = TextEditingController();

  int _currentStep = 0;
  String _towTruckStyle = 'sliding_bed';
  File? _selfieFile;
  File? _licenseFile;
  File? _vehicleRegFile;
  bool _loading = false;
  String? _error;
  bool _agreedKvkk = false;
  bool _agreedEula = false;

  static const List<String> _towTruckStyles = ['sliding_bed', 'fixed', 'crane'];
  static const Map<String, String> _towTruckLabels = {
    'sliding_bed': 'Sliding Bed',
    'fixed': 'Fixed',
    'crane': 'Crane',
  };
  static const int _maxSteps = 7;

  @override
  void initState() {
    super.initState();
    if (widget.initialFullName != null && widget.initialFullName!.isNotEmpty) {
      _nameController.text = widget.initialFullName!;
    }
    _loadSavedStep();
  }

  Future<void> _loadSavedStep() async {
    final prefs = await SharedPreferences.getInstance();
    final step = prefs.getInt(_kOnboardingStepKey);
    if (step != null && step >= 0 && step < _maxSteps && mounted) {
      setState(() => _currentStep = step);
    }
  }

  Future<void> _saveStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOnboardingStepKey, step);
  }

  Future<void> _clearSavedStep() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingStepKey);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tcknController.dispose();
    _plateController.dispose();
    _maxWeightController.dispose();
    _ibanController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int which) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
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
      switch (which) {
        case 0:
          _selfieFile = File(file.path);
          break;
        case 1:
          _licenseFile = File(file.path);
          break;
        case 2:
          _vehicleRegFile = File(file.path);
          break;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_selfieFile == null || _licenseFile == null || _vehicleRegFile == null) {
      setState(() => _error = 'Lütfen tüm fotoğrafları ekleyin');
      return;
    }
    final user = await ref.read(currentAppUserProvider.future);
    if (user == null) {
      setState(() => _error = 'Oturum sonlandı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final maxWeight = int.tryParse(_maxWeightController.text.trim());
      await ref.read(driverOnboardingServiceProvider).submitOnboarding(
            userId: user.id,
            fullName: _nameController.text.trim(),
            nationalId: _tcknController.text.trim(),
            selfieWithLicenseFile: _selfieFile!,
            plateNumber: _plateController.text.trim(),
            towTruckStyle: _towTruckStyle,
            maxWeightCapacityKg: maxWeight,
            licenseImageFile: _licenseFile!,
            vehicleRegistrationFile: _vehicleRegFile!,
            iban: _ibanController.text.trim().isEmpty ? null : _ibanController.text.trim(),
            legalEntityTaxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
          );
      final now = DateTime.now().toUtc();
      await ref.read(authServiceProvider).updateUserConsent(user.id, version: consentVersion, date: now);
      await _clearSavedStep();
      if (!mounted) return;
      ref.invalidate(currentAuthUserTowTruckProvider);
      ref.invalidate(currentAppUserProvider);
      ref.read(driverIdProvider.notifier).state = user.id;
      ref.invalidate(currentDriverUserProvider);
      ref.invalidate(currentDriverTruckProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const RegistrationReceivedScreen(),
        ),
      );
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

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _error = 'Ad soyad girin');
        return;
      }
      if (_tcknController.text.trim().length != 11) {
        setState(() => _error = 'TCKN 11 haneli olmalıdır');
        return;
      }
      if (_selfieFile == null) {
        setState(() => _error = 'Ehliyet ile selfie yükleyin');
        return;
      }
    }
    if (_currentStep == 1) {
      if (_plateController.text.trim().isEmpty) {
        setState(() => _error = 'Plaka girin');
        return;
      }
    }
    if (_currentStep == 3) {
      if (_licenseFile == null) {
        setState(() => _error = 'Ehliyet fotoğrafı yükleyin');
        return;
      }
    }
    if (_currentStep == 4) {
      if (_vehicleRegFile == null) {
        setState(() => _error = 'Ruhsat fotoğrafı yükleyin');
        return;
      }
    }
    if (_currentStep == 5) {
      if (!_agreedKvkk || !_agreedEula) {
        setState(() => _error = 'Devam etmek için her iki sözleşmeyi de kabul etmelisiniz.');
        return;
      }
    }

    if (_currentStep < _maxSteps - 1) {
      setState(() {
        _currentStep++;
        _error = null;
      });
      _saveStep(_currentStep);
    } else {
      _submit();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
      _saveStep(_currentStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sürücü kaydı'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: Stepper(
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: (_loading || (_currentStep == 5 && (!_agreedKvkk || !_agreedEula)))
                          ? null
                          : _onStepContinue,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_currentStep == _maxSteps - 1 ? 'Gönder' : 'İleri'),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _onStepCancel,
                        child: const Text('Geri'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // Step 0: Personal
              Step(
                title: const Text('Kişisel bilgiler'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tcknController,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'TC Kimlik No (TCKN)',
                        hintText: '11 hane',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Ehliyet ile selfie'),
                      subtitle: Text(_selfieFile != null ? p.basename(_selfieFile!.path) : 'Fotoğraf yükleyin'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_photo_alternate),
                        onPressed: () => _pickImage(0),
                      ),
                    ),
                  ],
                ),
              ),
              // Step 1: Vehicle detail
              Step(
                title: const Text('Araç bilgisi'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Plaka',
                        hintText: '34 ABC 123',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Çekici tipi', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _towTruckStyle,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _towTruckStyles.map((s) => DropdownMenuItem(value: s, child: Text(_towTruckLabels[s] ?? s))).toList(),
                      onChanged: (v) => setState(() => _towTruckStyle = v ?? _towTruckStyle),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxWeightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maks. ağırlık kapasitesi (kg)',
                        hintText: 'Örn. 3500',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              // Step 2: Driver license photo
              Step(
                title: const Text('Ehliyet'),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: ListTile(
                  title: const Text('Ehliyet fotoğrafı yükleyin'),
                  subtitle: Text(_licenseFile != null ? p.basename(_licenseFile!.path) : 'Dosya yok'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_photo_alternate),
                    onPressed: () => _pickImage(1),
                  ),
                ),
              ),
              // Step 3: Vehicle registration photo
              Step(
                title: const Text('Ruhsat'),
                isActive: _currentStep >= 3,
                state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                content: ListTile(
                  title: const Text('Ruhsat / plaka fotoğrafı yükleyin'),
                  subtitle: Text(_vehicleRegFile != null ? p.basename(_vehicleRegFile!.path) : 'Dosya yok'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_photo_alternate),
                    onPressed: () => _pickImage(2),
                  ),
                ),
              ),
              // Step 4: Payout
              Step(
                title: const Text('Ödeme bilgisi'),
                isActive: _currentStep >= 4,
                state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _ibanController,
                      decoration: const InputDecoration(
                        labelText: 'IBAN',
                        hintText: 'TR00 0000 0000 0000 0000 0000 00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxIdController,
                      decoration: const InputDecoration(
                        labelText: 'Vergi no / Tüzel kişi (isteğe bağlı)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              // Step 5: Legal consent
              Step(
                title: const Text('Yasal onay'),
                isActive: _currentStep >= 5,
                state: _currentStep > 5 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Kayıt olmak için aşağıdaki metinleri okuyup kabul etmelisiniz.'),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedKvkk,
                          onChanged: (v) => setState(() => _agreedKvkk = v ?? false),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => LegalDocumentScreen.open(context, assetPath: 'assets/legal/kvkk.html', title: 'Gizlilik Politikası'),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('Gizlilik Politikası (KVKK)', style: TextStyle(decoration: TextDecoration.underline)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedEula,
                          onChanged: (v) => setState(() => _agreedEula = v ?? false),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => LegalDocumentScreen.open(context, assetPath: 'assets/legal/eula.html', title: 'Kullanım Koşulları'),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('Kullanım Koşulları (EULA)', style: TextStyle(decoration: TextDecoration.underline)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Step 6: Submit
              Step(
                title: const Text('Gönder'),
                isActive: _currentStep >= 6,
                state: StepState.indexed,
                content: const Text('Tüm bilgileri kontrol edip gönderin.'),
              ),
            ],
          ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
