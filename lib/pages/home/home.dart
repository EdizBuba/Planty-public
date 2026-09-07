import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:planty/pages/login/login.dart';
import 'package:planty/pages/detail/plant_detail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String email = "";
  String username = "";
  List<Map<String, dynamic>> plants = [];
  String defaultImageUrl = 'https://www.clystvale.org/wp-content/uploads/woocommerce-placeholder-150x150.png.webp';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPlants();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        email = userDoc['email'];
        username = userDoc['username'];
      });
    }
  }

  void _loadPlants() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot querySnapshot = await _firestore
          .collection('plants')
          .where('userId', isEqualTo: user.uid)
          .orderBy('name')
          .get();

      setState(() {
        plants = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        }).toList();
      });
    }
  }

  Future<File?> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      String fileName = "plants/${DateTime.now().millisecondsSinceEpoch}.jpg";
      TaskSnapshot snapshot = await _storage.ref(fileName).putFile(imageFile);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Erreur d'upload d'image: $e");
      return "";
    }
  }

  void _showAddPlantDialog() {
    TextEditingController nameController = TextEditingController();
    File? imageFile;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Ajouter une plante"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Nom de la plante"),
                    ),
                    const SizedBox(height: 10),

                    // Affichage de l'image sélectionnée
                    imageFile != null
                        ? Image.file(imageFile!, height: 100, fit: BoxFit.cover)
                        : const Text("Aucune image sélectionnée"),

                    ElevatedButton(
                      onPressed: () async {
                        File? pickedImage = await _pickImage();
                        if (pickedImage != null) {
                          setState(() {
                            imageFile = pickedImage;
                          });
                        }
                      },
                      child: const Text("Choisir une image"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String imageUrl = "";
                    if (imageFile != null) {
                      imageUrl = await _uploadImage(imageFile!);
                    }
                    await _addPlant(
                      name: nameController.text,
                      imageUrl: imageUrl,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text("Ajouter"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addPlant({
    required String name,
    required String imageUrl,
  }) async {
    User? user = _auth.currentUser;
    if (user != null) {
      Timestamp now = Timestamp.now();

      DocumentReference plantRef = await _firestore.collection('plants').add({
        'userId': user.uid,
        'name': name.isNotEmpty ? name : 'Nouvelle plante',
        'imageUrl': imageUrl.isNotEmpty ? imageUrl : defaultImageUrl,
        'wateringMode': 'manuel', // mode par défaut
        'status': '',
        'lastModified': now,
      });

      await plantRef.update({'id': plantRef.id});

      _loadPlants();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Hello 👋, $username'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildPlantList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlantDialog,
        backgroundColor: const Color(0xff0D6EFD),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPlantList() {
    return plants.isEmpty
        ? const Center(child: Text("Aucune plante ajoutée"))
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        var plant = plants[index];
        return ListTile(
            leading: (plant['imageUrl'] != null &&
                plant['imageUrl'].toString().trim().isNotEmpty &&
                plant['imageUrl'].toString().startsWith("http"))
                ? Image.network(
              plant['imageUrl'],
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.network(
                  defaultImageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                );
              },
            )
                : Image.network(
              defaultImageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),

          title: Text(plant['name']),
            subtitle: Text(
                "Mode : ${plant['wateringMode']?.toString().toUpperCase() ?? 'MANUEL'}"
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlantDetail(
                    plantId: plant['id'],
                    name: plant['name'],
                    imageUrl: plant['imageUrl']?.toString().isNotEmpty == true
                        ? plant['imageUrl']
                        : defaultImageUrl,
                    wateringMode: plant['wateringMode'] ?? 'manuel',
                    status: plant['status'] ?? '',
                    humidityThreshold: plant['humidityThreshold']?.toDouble(),
                    temperatureThreshold: plant['temperatureThreshold']?.toDouble(),
                    manualWateringTime: plant['manualWateringTime'],
                    lastModified: plant['lastModified'],
                  ),
                ),
              );
              _loadPlants();
            }

        );
      },
    );
  }
}