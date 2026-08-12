import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/app_avatar.dart';
import '../../../services/vehicle_service.dart';
import '../screen/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfileScreen({super.key, required this.profileData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ProfileService _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController vehicleModelController;
  late final TextEditingController vehicleTypeController;
  late final TextEditingController vehicleColorController;
  late final TextEditingController vehicleNumberController;
  late final TextEditingController seatsController;
  late final TextEditingController licenceController;
  late final TextEditingController upiController;
  late final TextEditingController upiMobileController;
  late final TextEditingController emergencyController;
  late final TextEditingController bioController;

  String selectedGender = '';
  bool isSaving = false;

  String? currentPhotoUrl;
  String? currentLicenceUrl;

  int? selectedAvatarIndex;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.profileData['name']?.toString() ?? '',
    );

    phoneController = TextEditingController(
      text: widget.profileData['phone']?.toString() ?? '',
    );

    vehicleModelController = TextEditingController(
      text: widget.profileData['vehicleModel']?.toString() ?? '',
    );

    vehicleTypeController = TextEditingController(
      text: widget.profileData['vehicle']?.toString() ?? '',
    );

    vehicleColorController = TextEditingController(
      text: widget.profileData['vehicleColor']?.toString() ?? '',
    );

    vehicleNumberController = TextEditingController(
      text: widget.profileData['vehicleNumber']?.toString() ?? '',
    );

    seatsController = TextEditingController(
      text: widget.profileData['seats']?.toString() ?? '4',
    );

    licenceController = TextEditingController(
      text: widget.profileData['drivingLicence']?.toString() ?? '',
    );

    upiController = TextEditingController(
      text: widget.profileData['upiId']?.toString() ?? '',
    );

    upiMobileController = TextEditingController(
      text: widget.profileData['upiMobileNumber']?.toString() ?? '',
    );

    emergencyController = TextEditingController(
      text: widget.profileData['emergencyContact']?.toString() ?? '',
    );

    bioController = TextEditingController(
      text: widget.profileData['bio']?.toString() ?? '',
    );

    selectedGender = widget.profileData['gender']?.toString() ?? '';

    final String photoUrl =
        widget.profileData['photoUrl']?.toString().trim() ?? '';

    final String licenceUrl =
        widget.profileData['licenceImageUrl']?.toString().trim() ?? '';

    currentPhotoUrl = photoUrl.isEmpty ? null : photoUrl;
    currentLicenceUrl = licenceUrl.isEmpty ? null : licenceUrl;

    final dynamic storedAvatar = widget.profileData['avatarIndex'];

    selectedAvatarIndex = storedAvatar is int
        ? storedAvatar
        : int.tryParse(storedAvatar?.toString() ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    vehicleModelController.dispose();
    vehicleTypeController.dispose();
    vehicleColorController.dispose();
    vehicleNumberController.dispose();
    seatsController.dispose();
    licenceController.dispose();
    upiController.dispose();
    upiMobileController.dispose();
    emergencyController.dispose();
    bioController.dispose();

    super.dispose();
  }

  Future<String> _uploadImageToFirebase({
    required File imageFile,
    required String folderName,
    required String fileName,
    required String firestoreField,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in. Please log in again.');
    }

    final bool imageExists = await imageFile.exists();

    if (!imageExists) {
      throw Exception('The selected image could not be found.');
    }

    try {
      // Refresh the Firebase Authentication token.
      await user.getIdToken(true);

      final String storagePath = '$folderName/${user.uid}/$fileName';

      final Reference reference = _storage.ref().child(storagePath);

      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{'ownerId': user.uid},
      );

      final UploadTask uploadTask = reference.putFile(imageFile, metadata);

      final TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state != TaskState.success) {
        throw Exception('The image upload was not completed.');
      }

      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
        firestoreField: downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return downloadUrl;
    } on FirebaseException catch (error) {
      debugPrint('Profile image upload failed (${error.code}).');

      if (error.code == 'unauthorized') {
        throw Exception(
          'Storage permission denied. Publish the correct '
          'Firebase Storage rules and check the folder names.',
        );
      }

      if (error.code == 'unauthenticated') {
        throw Exception('Your login session has expired. Please log in again.');
      }

      if (error.code == 'object-not-found') {
        throw Exception('The Firebase Storage location was not found.');
      }

      if (error.code == 'quota-exceeded') {
        throw Exception(
          'Firebase Storage quota has been exceeded. '
          'Check your Firebase billing plan.',
        );
      }

      throw Exception(error.message ?? 'Firebase image upload failed.');
    } catch (error) {
      throw Exception('Image upload failed: $error');
    }
  }

  Future<void> _pickImage() async {
    if (isSaving) return;

    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (selectedImage == null) return;

      setState(() {
        isSaving = true;
      });

      final String imageUrl = await _uploadImageToFirebase(
        imageFile: File(selectedImage.path),

        // This must match Firebase Storage rules.
        folderName: 'profile_pictures',

        // This overwrites the old picture instead of creating many files.
        fileName: 'profile.jpg',

        // This URL is saved in users/{uid}.
        firestoreField: 'photoUrl',
      );

      if (!mounted) return;

      setState(() {
        currentPhotoUrl = imageUrl;
        selectedAvatarIndex = null;
      });

      _showMessage('Profile picture uploaded successfully!');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to upload profile picture: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _pickLicenceImage() async {
    if (isSaving) return;

    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (selectedImage == null) return;

      setState(() {
        isSaving = true;
      });

      final String imageUrl = await _uploadImageToFirebase(
        imageFile: File(selectedImage.path),

        // This must match Firebase Storage rules.
        folderName: 'driver_licences',

        // This overwrites the old licence picture.
        fileName: 'licence.jpg',

        // This URL is saved in users/{uid}.
        firestoreField: 'licenceImageUrl',
      );

      if (!mounted) return;

      setState(() {
        currentLicenceUrl = imageUrl;
      });

      _showMessage('Driving Licence uploaded successfully!');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to upload Driving Licence: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'You are not logged in. Please log in again.',
        isError: true,
      );
      return;
    }

    if (currentPhotoUrl == null && selectedAvatarIndex == null) {
      _showMessage(
        'Please upload a profile picture or select an avatar.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _profileService.updateProfile(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        vehicleModel: vehicleModelController.text.trim(),
        gender: selectedGender,
        vehicle: vehicleTypeController.text.trim(),
        vehicleColor: vehicleColorController.text.trim(),
        vehicleNumber: vehicleNumberController.text.trim().toUpperCase(),
        seats: int.tryParse(seatsController.text.trim()),
        drivingLicence: licenceController.text.trim().toUpperCase(),
        upiId: upiController.text.trim(),
        upiMobileNumber: upiMobileController.text.trim(),
        emergencyContact: emergencyController.text.trim(),
        bio: bioController.text.trim(),
        avatarIndex: selectedAvatarIndex,
        licenceImageUrl: currentLicenceUrl,
      );

      await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
        'photoUrl': currentPhotoUrl,
        'licenceImageUrl': currentLicenceUrl,
        'avatarIndex': selectedAvatarIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage('Profile updated successfully!');

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message ?? 'Firebase profile update failed.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Profile update failed: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validatePhone(String? value) {
    final String phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Phone number is required';
    }

    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 10) {
      return 'Enter a valid phone number';
    }

    return null;
  }

  String? _validateUpi(String? value) {
    final String upiId = value?.trim() ?? '';

    // UPI is optional for passengers.
    if (upiId.isEmpty) {
      return null;
    }

    final RegExp upiPattern = RegExp(
      r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$',
    );

    if (!upiPattern.hasMatch(upiId)) {
      return 'Enter a valid UPI ID, for example name@upi';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const Color primaryColor = Color(0xFF2ED6C7);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101116)
          : const Color(0xFFF8FCFC),
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1A1C23) : Colors.white,
        elevation: 0,
      ),
      body: AbsorbPointer(
        absorbing: isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              _buildAvatarSection(isDark),

              const SizedBox(height: 32),

              _buildInput(
                nameController,
                'Full Name',
                Icons.person_outline_rounded,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildInput(
                phoneController,
                'Phone Number',
                Icons.phone_iphone_rounded,
                keyboard: TextInputType.phone,
                validator: _validatePhone,
              ),

              const SizedBox(height: 32),

              _sectionTitle(
                'Driver Verification (Mandatory to Publish a Ride)',
                isDark,
              ),

              const SizedBox(height: 16),

              _buildInput(
                licenceController,
                'Driving Licence Number',
                Icons.badge_rounded,
                hint: 'DL-XXXXXXXXXXXXX',
              ),

              const SizedBox(height: 12),

              _buildImagePicker(
                label: 'Upload Driving Licence Photo',
                imageUrl: currentLicenceUrl,
                onTap: _pickLicenceImage,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              _buildInput(
                upiController,
                'UPI ID (to receive payments)',
                Icons.account_balance_wallet_rounded,
                hint: 'name@upi',
                validator: _validateUpi,
              ),

              const SizedBox(height: 32),

              _sectionTitle('Vehicle Information', isDark),

              const SizedBox(height: 16),

              _buildVehicleModelInput(isDark),

              const SizedBox(height: 16),

              _buildInput(
                vehicleColorController,
                'Car Color',
                Icons.palette_rounded,
              ),

              const SizedBox(height: 16),

              _buildInput(
                vehicleNumberController,
                'Vehicle Number',
                Icons.pin_rounded,
              ),

              const SizedBox(height: 16),

              _buildInput(
                seatsController,
                'Number of Seats',
                Icons.event_seat_rounded,
                keyboard: TextInputType.number,
              ),

              const SizedBox(height: 32),

              _sectionTitle('Additional Info', isDark),

              const SizedBox(height: 16),

              _buildInput(
                emergencyController,
                'Emergency Contact Number',
                Icons.emergency_share_rounded,
                keyboard: TextInputType.phone,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Emergency contact is required for safety';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildGenderDropdown(isDark),

              const SizedBox(height: 16),

              _buildInput(
                vehicleTypeController,
                'Vehicle Type (Car/Bike)',
                Icons.directions_car_filled_rounded,
              ),

              const SizedBox(height: 16),

              _buildInput(
                bioController,
                'About You',
                Icons.info_outline_rounded,
                lines: 3,
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'SAVE CHANGES',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : const Color(0xFF08234C),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String? imageUrl,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1C23) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return _buildImagePlaceholder(label);
                          },
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2ED6C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              )
            : _buildImagePlaceholder(label),
      ),
    );
  }

  Widget _buildImagePlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(
          Icons.add_a_photo_rounded,
          color: Color(0xFF2ED6C7),
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAvatarSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Center(
              child: AppAvatar(
                avatarIndex: selectedAvatarIndex,
                photoUrl: currentPhotoUrl,
                size: 110,
                borderColor: const Color(0xFF2ED6C7),
                borderWidth: 2.5,
              ),
            ),
            Positioned(
              bottom: 0,
              right: MediaQuery.of(context).size.width * 0.35,
              child: GestureDetector(
                onTap: isSaving ? null : _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ED6C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 25),

        Text(
          'Or Choose an Avatar',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF08234C),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AppAvatar.avatarCount,
            itemBuilder: (BuildContext context, int index) {
              final bool selected = selectedAvatarIndex == index;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: isSaving
                      ? null
                      : () {
                          setState(() {
                            selectedAvatarIndex = index;
                            currentPhotoUrl = null;
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF2ED6C7)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AppAvatar(
                      avatarIndex: index,
                      size: 64,
                      borderWidth: 0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleModelInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
      ),
      child: RawAutocomplete<String>(
        initialValue: TextEditingValue(text: vehicleModelController.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          return VehicleService.getSuggestions(textEditingValue.text);
        },
        onSelected: (String selection) {
          vehicleModelController.text = selection;
        },
        fieldViewBuilder:
            (
              BuildContext context,
              TextEditingController controller,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Car Model',
                  labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.directions_car_rounded,
                    color: Color(0xFF2ED6C7),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (String value) {
                  vehicleModelController.text = value;
                },
              );
            },
        optionsViewBuilder:
            (
              BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options,
            ) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(15),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 320,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);

                        return ListTile(
                          title: Text(
                            option,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int lines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF2ED6C7), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedGender.isEmpty ? null : selectedGender,
        decoration: const InputDecoration(
          labelText: 'Gender',
          prefixIcon: Icon(
            Icons.people_outline,
            color: Color(0xFF2ED6C7),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'Male', child: Text('Male')),
          DropdownMenuItem<String>(value: 'Female', child: Text('Female')),
          DropdownMenuItem<String>(value: 'Other', child: Text('Other')),
        ],
        onChanged: (String? value) {
          if (value == null) return;

          setState(() {
            selectedGender = value;
          });
        },
      ),
    );
  }
}
