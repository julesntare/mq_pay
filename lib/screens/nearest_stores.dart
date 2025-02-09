import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import 'package:mq_pay/helpers/launcher.dart';

class NearestStoresPage extends StatefulWidget {
  @override
  _NearestStoresPageState createState() => _NearestStoresPageState();
}

class _NearestStoresPageState extends State<NearestStoresPage> {
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNearestStores();
  }

  Future<void> _fetchNearestStores() async {
    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      double userLat = position.latitude;
      double userLon = position.longitude;

      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('stores').get();

      List<Map<String, dynamic>> stores = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        double storeLat = data['latitude'];
        double storeLon = data['longitude'];
        double distance =
            _calculateDistance(userLat, userLon, storeLat, storeLon);
        return {
          'name': data['name'],
          'paymentCode': data['paymentCode'],
          'paymentType': data['paymentType'],
          'distance': distance,
        };
      }).toList();

      stores.sort((a, b) => a['distance'].compareTo(b['distance']));

      setState(() {
        _stores = stores;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of Earth in km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Nearest Stores")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _stores.length,
              itemBuilder: (context, index) {
                var store = _stores[index];
                return ListTile(
                  title: Text(store['name']),
                  subtitle: Text(
                      "${store['paymentType']}: ${store['paymentCode']} - ${store['distance'].toStringAsFixed(2)} km away"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      String input = store['paymentCode'];
                      launchUSSD(
                          input.contains('*') && input.contains('#')
                              ? input
                              : "*182*${RegExp(r'^(?:\+2507|2507|07|7)[0-9]{8}$').hasMatch(input) ? '1' : '8'}*1*${input}*${input}#",
                          context);
                    },
                    child: Text("Pay Now"),
                  ),
                );
              },
            ),
    );
  }
}
