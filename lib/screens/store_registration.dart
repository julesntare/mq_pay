import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class StoreRegistrationPage extends StatefulWidget {
  @override
  _StoreRegistrationPageState createState() => _StoreRegistrationPageState();
}

class _StoreRegistrationPageState extends State<StoreRegistrationPage> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _paymentCodeController = TextEditingController();
  String _paymentType = "Phone Number";
  bool _isLoading = false;

  Future<void> _registerStore() async {
    setState(() => _isLoading = true);

    try {
      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission is required to register a store.");
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
            "Location permission is permanently denied. Enable it from settings.");
        setState(() => _isLoading = false);
        return;
      }

      // Fetch user location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await FirebaseFirestore.instance.collection('stores').add({
        'name': _storeNameController.text,
        'paymentCode': _paymentCodeController.text,
        'paymentType': _paymentType,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Store Registered Successfully!")));
      _storeNameController.clear();
      _paymentCodeController.clear();
    } catch (e) {
      _showError("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register Store")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _storeNameController,
              decoration: InputDecoration(labelText: "Store Name"),
            ),
            TextField(
              controller: _paymentCodeController,
              decoration: InputDecoration(labelText: "Payment Code"),
            ),
            DropdownButton<String>(
              value: _paymentType,
              onChanged: (value) {
                setState(() => _paymentType = value!);
              },
              items: ["Phone Number", "MoMo Code"]
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _registerStore, child: Text("Register Store")),
          ],
        ),
      ),
    );
  }
}
