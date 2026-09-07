import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Historique extends StatefulWidget {
  const Historique({super.key});

  @override
  State<Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends State<Historique> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> wateringLogs = [];

  @override
  void initState() {
    super.initState();
    _loadWateringLogs();
  }

  Future<void> _loadWateringLogs() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot query = await _firestore
          .collection('watering')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> enrichedLogs = [];

      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final plantId = data['plantId'];

        String plantName = 'Plante inconnue';
        try {
          DocumentSnapshot plantDoc =
          await _firestore.collection('plants').doc(plantId).get();
          if (plantDoc.exists) {
            plantName = plantDoc['name'] ?? plantName;
          }
        } catch (_) {
          // Ignore errors (ex: plante supprimée)
        }

        enrichedLogs.add({
          ...data,
          'plantName': plantName,
        });
      }

      setState(() {
        wateringLogs = enrichedLogs;
      });
    }
  }

  Icon _getIcon(bool success) {
    return Icon(
      success ? Icons.check_circle : Icons.cancel,
      color: success ? Colors.green : Colors.red,
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day/$month/$year à $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historique des arrosages")),
      body: wateringLogs.isEmpty
          ? const Center(child: Text("Aucun historique disponible"))
          : ListView.builder(
        itemCount: wateringLogs.length,
        itemBuilder: (context, index) {
          final log = wateringLogs[index];
          return ListTile(
            leading: _getIcon(log['success'] == true),
            title: Text(log['plantName'] ?? 'Plante'),
            subtitle: Text(
              "${_formatDate(log['timestamp'])} • Mode : ${log['mode']}",
              style: const TextStyle(fontSize: 13),
            ),
          );
        },
      ),
    );
  }
}