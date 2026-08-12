import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/ride_model.dart';
import '../services/ride_service.dart';

class EditRideScreen extends StatefulWidget {
  final RideModel ride;

  const EditRideScreen({super.key, required this.ride});

  @override
  State<EditRideScreen> createState() => _EditRideScreenState();
}

class _EditRideScreenState extends State<EditRideScreen> {
  static const Color primary = Color(0xFF5B4CF0);

  final RideService rideService = RideService();

  late final TextEditingController pickupController;
  late final TextEditingController destinationController;
  late final TextEditingController dateController;
  late final TextEditingController timeController;
  late final TextEditingController priceController;
  late final TextEditingController descriptionController;

  late String vehicle;
  late int seats;

  bool isUpdating = false;

  final List<String> vehicleOptions = const [
    'Car',
    'SUV',
    'Sedan',
    'Hatchback',
    'Bike',
  ];

  @override
  void initState() {
    super.initState();

    pickupController = TextEditingController(text: widget.ride.pickup);

    destinationController = TextEditingController(
      text: widget.ride.destination,
    );

    dateController = TextEditingController(text: widget.ride.date);

    timeController = TextEditingController(text: widget.ride.time);

    priceController = TextEditingController(text: widget.ride.price.toString());

    descriptionController = TextEditingController(
      text: widget.ride.description,
    );

    vehicle = vehicleOptions.contains(widget.ride.vehicle)
        ? widget.ride.vehicle
        : vehicleOptions.first;

    seats = widget.ride.seats > 0 ? widget.ride.seats : 1;
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    dateController.dispose();
    timeController.dispose();
    priceController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Ride',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Ride Details',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Make changes to your published ride.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              buildTextField(
                controller: pickupController,
                label: 'Pickup Location',
                icon: Icons.my_location_rounded,
              ),

              const SizedBox(height: 18),

              buildTextField(
                controller: destinationController,
                label: 'Destination',
                icon: Icons.location_on_rounded,
              ),

              const SizedBox(height: 18),

              TextField(
                controller: dateController,
                readOnly: true,
                enabled: !isUpdating,
                onTap: selectDate,
                decoration: buildInputDecoration(
                  label: 'Travel Date',
                  icon: Icons.calendar_today_rounded,
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: timeController,
                readOnly: true,
                enabled: !isUpdating,
                onTap: selectTime,
                decoration: buildInputDecoration(
                  label: 'Departure Time',
                  icon: Icons.access_time_rounded,
                ),
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                initialValue: vehicle,
                isExpanded: true,
                decoration: buildInputDecoration(
                  label: 'Vehicle',
                  icon: Icons.directions_car_rounded,
                ),
                items: vehicleOptions.map((vehicleName) {
                  return DropdownMenuItem<String>(
                    value: vehicleName,
                    child: Text(vehicleName),
                  );
                }).toList(),
                onChanged: isUpdating
                    ? null
                    : (String? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          vehicle = value;
                        });
                      },
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat_rounded),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        'Available Seats',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      onPressed: isUpdating
                          ? null
                          : () {
                              if (seats > 1) {
                                setState(() {
                                  seats--;
                                });
                              }
                            },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Text(
                      seats.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: isUpdating
                          ? null
                          : () {
                              if (seats < 8) {
                                setState(() {
                                  seats++;
                                });
                              }
                            },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              buildTextField(
                controller: priceController,
                label: 'Price Per Seat (₹)',
                icon: Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),

              buildTextField(
                controller: descriptionController,
                label: 'Ride Description',
                icon: Icons.notes_rounded,
                maxLines: 4,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: isUpdating ? null : updateRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withValues(alpha: 0.60),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    isUpdating ? 'Updating...' : 'Update Ride',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> updateRide() async {
    FocusScope.of(context).unfocus();

    final String pickup = pickupController.text.trim();

    final String destination = destinationController.text.trim();

    final String date = dateController.text.trim();

    final String time = timeController.text.trim();

    final String priceText = priceController.text.trim();

    final String description = descriptionController.text.trim();

    if (pickup.isEmpty ||
        destination.isEmpty ||
        date.isEmpty ||
        time.isEmpty ||
        priceText.isEmpty ||
        description.isEmpty) {
      showMessage('Please fill all required fields.');

      return;
    }

    if (pickup.toLowerCase() == destination.toLowerCase()) {
      showMessage('Pickup and destination cannot be the same.');

      return;
    }

    final int? price = int.tryParse(priceText);

    if (price == null || price <= 0) {
      showMessage('Please enter a valid price.');

      return;
    }

    if (vehicle.trim().isEmpty) {
      showMessage('Please select a vehicle.');

      return;
    }

    if (seats <= 0) {
      showMessage('Please select valid seats.');

      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      final RideModel updatedRide = RideModel(
        id: widget.ride.id,
        driverId: widget.ride.driverId,
        pickup: pickup,
        destination: destination,
        date: date,
        time: time,
        vehicle: vehicle,
        seats: seats,
        price: price,
        description: description,
        status: widget.ride.status,
        createdAt: widget.ride.createdAt,
      );

      await rideService.updateRide(rideId: widget.ride.id, ride: updatedRide);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      showMessage(error.message ?? 'Failed to update ride.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      showMessage('Failed to update ride. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> selectDate() async {
    final DateTime now = DateTime.now();

    DateTime initialDate = now;

    final List<String> dateParts = dateController.text.split('/');

    if (dateParts.length == 3) {
      final int? day = int.tryParse(dateParts[0]);

      final int? month = int.tryParse(dateParts[1]);

      final int? year = int.tryParse(dateParts[2]);

      if (day != null && month != null && year != null) {
        final DateTime existingDate = DateTime(year, month, day);

        if (!existingDate.isBefore(now)) {
          initialDate = existingDate;
        }
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (!mounted || picked == null) {
      return;
    }

    dateController.text =
        '${picked.day.toString().padLeft(2, '0')}/'
        '${picked.month.toString().padLeft(2, '0')}/'
        '${picked.year}';
  }

  Future<void> selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (!mounted || picked == null) {
      return;
    }

    timeController.text = picked.format(context);
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      enabled: !isUpdating,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: buildInputDecoration(label: label, icon: icon),
    );
  }

  InputDecoration buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
