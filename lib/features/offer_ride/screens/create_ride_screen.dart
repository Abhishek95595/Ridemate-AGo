import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../map/widgets/location_search_widget.dart';
import '../../profile/models/user_model.dart';
import '../../profile/screen/edit_profile_screen.dart';
import '../models/ride_model.dart';
import '../services/ride_service.dart';

import '../../map/services/vehicle_marker_service.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  static const Color _teal = Color(0xFF14D8C4);
  static const Color _navy = Color(0xFF0F172A);

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController bioController = TextEditingController();

  final RideService rideService = RideService();

  String vehicle = 'Car';
  int seats = 1;
  bool isPublishing = false;

  LatLng? _pickupCoords;
  LatLng? _destinationCoords;

  @override
  void initState() {
    super.initState();
    _loadProfileVehicle();
  }

  Future<void> _loadProfileVehicle() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final profileVehicle =
            (doc.data()!['vehicle'] ?? doc.data()!['vehicleType'] ?? '')
                .toString();
        final normalized = VehicleMarkerService.normalizeVehicleType(
          profileVehicle,
        );
        if (mounted && normalized == 'bike') {
          setState(() {
            vehicle = 'Bike';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile vehicle preference: $e');
    }
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    dateController.dispose();
    timeController.dispose();
    priceController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Offer New Ride',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(isDark),
            const SizedBox(height: 30),

            LocationSearchWidget(
              label: 'Pickup Location',
              icon: Icons.radio_button_checked,
              iconColor: _teal,
              controller: pickupController,
              onSelected: (loc) {
                setState(() {
                  _pickupCoords = LatLng(loc.latitude!, loc.longitude!);
                  pickupController.text = loc.name;
                });
              },
            ),
            const SizedBox(height: 16),

            LocationSearchWidget(
              label: 'Destination',
              icon: Icons.location_on,
              iconColor: Colors.redAccent,
              controller: destinationController,
              onSelected: (loc) {
                setState(() {
                  _destinationCoords = LatLng(loc.latitude!, loc.longitude!);
                  destinationController.text = loc.name;
                });
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTapField(
                    controller: dateController,
                    label: "Travel Date",
                    icon: Icons.calendar_today,
                    onTap: selectDate,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTapField(
                    controller: timeController,
                    label: "Departure",
                    icon: Icons.access_time,
                    onTap: selectTime,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildDropdown(isDark),
            const SizedBox(height: 16),

            _buildSeatCounter(isDark),
            const SizedBox(height: 16),

            _buildInputWrapper(
              icon: Icons.currency_rupee,
              isDark: isDark,
              child: TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "Price Per Seat (₹)",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputWrapper(
              icon: Icons.article_outlined,
              isDark: isDark,
              minHeight: 120,
              alignTop: true,
              child: TextField(
                controller: bioController,
                maxLines: 4,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Add ride details for passengers...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 40),

            _buildPublishButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Ride",
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _navy,
              ),
            ),
            Text(
              "Fill the ride details below",
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
        Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.directions_car_filled,
            color: _teal,
            size: 45,
          ),
        ),
      ],
    );
  }

  Widget _buildTapField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return _buildInputWrapper(
      icon: icon,
      isDark: isDark,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDropdown(bool isDark) {
    return _buildInputWrapper(
      icon: Icons.directions_car_filled,
      isDark: isDark,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: vehicle,
          isExpanded: true,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : _navy,
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          items: [
            'Car',
            'SUV',
            'Sedan',
            'Bike',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => vehicle = val!),
        ),
      ),
    );
  }

  Widget _buildSeatCounter(bool isDark) {
    return _buildInputWrapper(
      icon: Icons.event_seat,
      isDark: isDark,
      child: Row(
        children: [
          Text(
            "Available Seats",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 15),
          ),
          const Spacer(),
          _counterBtn(Icons.remove, () {
            if (seats > 1) setState(() => seats--);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              "$seats",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _counterBtn(Icons.add, () {
            if (seats < 6) setState(() => seats++);
          }),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _teal, size: 20),
      ),
    );
  }

  Widget _buildInputWrapper({
    required IconData icon,
    required bool isDark,
    required Widget child,
    double minHeight = 64,
    bool alignTop = false,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFECECEC),
        ),
      ),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: alignTop ? 18 : 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _teal, size: 22),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B4CF0), Color(0xFF4436C7)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isPublishing ? null : _publish,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
          ),
          child: isPublishing
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Text(
                  "PUBLISH RIDE",
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();
    if (!userDoc.exists) return;

    final userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);

    if (!userModel.isDriverEligible) {
      if (!mounted) return;
      _showProfileIncompleteDialog(
        userDoc.data()!,
        "To publish a ride, you must add your Profile Photo, Phone Number, Driving Licence, and UPI ID.",
      );
      return;
    }

    if (pickupController.text.isEmpty ||
        destinationController.text.isEmpty ||
        _pickupCoords == null ||
        _destinationCoords == null) {
      _error("Please select valid pickup and destination locations.");
      return;
    }
    if (dateController.text.isEmpty ||
        timeController.text.isEmpty ||
        priceController.text.isEmpty) {
      _error("Please fill all required travel details.");
      return;
    }

    setState(() => isPublishing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ride = RideModel(
        driverId: user!.uid,
        pickup: pickupController.text,
        destination: destinationController.text,
        date: dateController.text,
        time: timeController.text,
        vehicle: vehicle,
        seats: seats,
        availableSeats: seats,
        price: int.parse(priceController.text),
        description: bioController.text,
        pickupLat: _pickupCoords!.latitude,
        pickupLng: _pickupCoords!.longitude,
        destinationLat: _destinationCoords!.latitude,
        destinationLng: _destinationCoords!.longitude,
      );
      await rideService.publishRide(ride);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ride Published Successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _error("Failed to publish ride: $e");
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(
        () => dateController.text =
            "${picked.day}/${picked.month}/${picked.year}",
      );
    }
  }

  Future<void> selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => timeController.text = picked.format(context));
    }
  }

  void _showProfileIncompleteDialog(Map<String, dynamic> data, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          "Profile Incomplete",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profileData: data),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ED6C7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "COMPLETE NOW",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
