import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:planty/pages/login/login.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedDelay = '30';
  final List<String> delays = ['15', '30', '60'];

  @override
  void initState() {
    super.initState();
    _loadNotificationDelay();
  }

  void _loadNotificationDelay() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        selectedDelay = (userDoc['notificationDelay'] ?? '30').toString();
      });
    }
  }

  Future<void> _updateNotificationDelay(String newDelay) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'notificationDelay': newDelay,
      });
    }
  }

  void _showNotificationDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: delays.map((delay) {
            String label = switch (delay) {
              '15' => '15 minutes avant',
              '30' => '30 minutes avant',
              '60' => '1 heure avant',
              _ => '$delay min',
            };
            return ListTile(
              title: Text(label),
              leading: Radio<String>(
                value: delay,
                groupValue: selectedDelay,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    setState(() {
                      selectedDelay = value;
                    });
                    _updateNotificationDelay(value);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => Login()),
          (route) => false,
    );
  }

  String _getDelayLabel(String delay) {
    switch (delay) {
      case '15':
        return '15 minutes avant';
      case '30':
        return '30 minutes avant';
      case '60':
        return '1 heure avant';
      default:
        return '$delay min';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.notifications, color: Colors.white),
            ),
            title: const Text('Notifications'),
            subtitle: Text(_getDelayLabel(selectedDelay)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showNotificationDialog,
          ),
          const Divider(),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.red,
              child: Icon(Icons.logout, color: Colors.white),
            ),
            title: const Text('Se déconnecter'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}