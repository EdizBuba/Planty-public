import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class PlantDetail extends StatefulWidget {
  final String plantId;
  final String name;
  final String imageUrl;
  final String wateringMode;
  final String status;
  final double? humidityThreshold;
  final double? temperatureThreshold;
  final String? manualWateringTime;
  final Timestamp? lastModified;

  const PlantDetail({
    super.key,
    required this.plantId,
    required this.name,
    required this.imageUrl,
    required this.wateringMode,
    required this.status,
    this.humidityThreshold,
    this.temperatureThreshold,
    this.manualWateringTime,
    required this.lastModified,
  });

  @override
  _PlantDetailState createState() => _PlantDetailState();
}

class _PlantDetailState extends State<PlantDetail> {
  bool isEditing = false;
  late TextEditingController nameController;
  String wateringMode = "manuel";
  TextEditingController humidityController = TextEditingController();
  TextEditingController temperatureController = TextEditingController();
  File? newImageFile;
  String? newImageUrl;
  bool imageDeleted = false;
  String defaultImageUrl = 'https://www.clystvale.org/wp-content/uploads/woocommerce-placeholder-150x150.png.webp';
  TimeOfDay? wateringTime;
  String? status;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    status = widget.status;
    wateringMode = widget.wateringMode;
    if (widget.humidityThreshold != null) {
      humidityController.text = widget.humidityThreshold!.toString();
    }
    if (widget.temperatureThreshold != null) {
      temperatureController.text = widget.temperatureThreshold!.toString();
    }
    if (widget.manualWateringTime != null) {
      final parts = widget.manualWateringTime!.split(":");
      wateringTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
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
      String fileName = "plants/\${DateTime.now().millisecondsSinceEpoch}.jpg";
      TaskSnapshot snapshot = await FirebaseStorage.instance.ref(fileName).putFile(imageFile);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Erreur d'upload d'image: \$e");
      return "";
    }
  }

  Future<void> _updatePlant() async {
    String imageUrl = newImageUrl ?? widget.imageUrl;

    if (imageDeleted) {
      imageUrl = defaultImageUrl;
    } else if (newImageFile != null) {
      imageUrl = await _uploadImage(newImageFile!);
    } else if (newImageUrl != null) {
      imageUrl = newImageUrl!;
    }

    Timestamp now = Timestamp.now();

    await FirebaseFirestore.instance.collection('plants').doc(widget.plantId).update({
      'name': nameController.text,
      'imageUrl': imageUrl,
      'wateringMode': wateringMode,
      'humidityThreshold': wateringMode == "automatique" ? double.tryParse(humidityController.text) : null,
      'temperatureThreshold': wateringMode == "automatique" ? double.tryParse(temperatureController.text) : null,
      'manualWateringTime': wateringMode == "manuel" && wateringTime != null
          ? "${wateringTime!.hour.toString().padLeft(2, '0')}:${wateringTime!.minute.toString().padLeft(2, '0')}"
          : null,
      'lastModified': Timestamp.now(),
    });

    setState(() {
      isEditing = false;
      newImageUrl = imageUrl;
      newImageFile = null;
    });
  }

  Future<void> _sendWatering() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('plants')
        .doc(widget.plantId)
        .get();

    String currentStatus = snapshot['status'] ?? '';

    if (currentStatus == 'waiting') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La plante est déjà en attente d’arrosage.")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('plants').doc(widget.plantId).update({
      'status': 'waiting',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Commande d'arrosage envoyée !")),
    );

    setState(() {
      status = 'waiting';
    });
  }


  String _getEffectiveImageUrl() {
    if (imageDeleted) return defaultImageUrl;

    final url = (newImageUrl?.trim() ?? "").isNotEmpty
        ? newImageUrl!.trim()
        : widget.imageUrl.trim();

    if (url.isEmpty || !url.startsWith('http')) {
      return defaultImageUrl;
    }

    return url;
  }

  Widget buildImage() {
    if (newImageFile != null &&
        newImageFile!.path.isNotEmpty &&
        File(newImageFile!.path).existsSync()) {
      return Image.file(
        newImageFile!,
        height: 150,
        width: 150,
        fit: BoxFit.cover,
      );
    } else {
      final imageUrl = _getEffectiveImageUrl();
      return Image.network(
        imageUrl,
        height: 150,
        width: 150,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.network(
          defaultImageUrl,
          height: 150,
          width: 150,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  Future<void> _pickWateringTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: wateringTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        wateringTime = pickedTime;
      });
    }
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waiting':
        return Icons.schedule;
      case 'attention':
        return Icons.warning_amber_rounded;
      case 'critical':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.orange;
      case 'attention':
        return Colors.amber;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
        return "Arrosage en attente";
      case 'attention':
        return "Niveau d'attention requis";
      case 'critical':
        return "État critique";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails de la plante"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (isEditing) {
                _updatePlant();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: buildImage(),
                  ),
                  if (isEditing &&
                      (newImageFile != null ||
                          ((newImageUrl ?? widget.imageUrl).isNotEmpty &&
                              (newImageUrl ?? widget.imageUrl) != defaultImageUrl)))
                    Positioned(
                      right: -10,
                      top: -10,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        onPressed: () {
                          setState(() {
                            newImageFile = null;
                            newImageUrl = "";
                            imageDeleted = true;
                          });
                        },
                      ),
                    ),
                  if (isEditing)
                    Positioned(
                      bottom: -10,
                      right: -10,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () async {
                          File? picked = await _pickImage();
                          if (picked != null) {
                            setState(() {
                              newImageFile = picked;
                              newImageUrl = null;
                            });
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nom de la plante"),
              enabled: isEditing,
            ),
            const SizedBox(height: 10),
            const Text("Mode d'arrosage", style: TextStyle(fontWeight: FontWeight.bold)),
            if (isEditing)
              DropdownButton<String>(
                value: wateringMode,
                onChanged: (String? newValue) {
                  setState(() {
                    wateringMode = newValue!;
                  });
                },
                items: <String>['manuel', 'automatique']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()),
                  );
                }).toList(),
              )
            else
              Text(wateringMode.toUpperCase()),
            if (wateringMode == "automatique") ...[
              TextField(
                controller: humidityController,
                decoration: const InputDecoration(labelText: "Seuil d'humidité (%)"),
                keyboardType: TextInputType.number,
                enabled: isEditing,
              ),
              TextField(
                controller: temperatureController,
                decoration: const InputDecoration(labelText: "Seuil de température (°C)"),
                keyboardType: TextInputType.number,
                enabled: isEditing,
              ),
            ],
            if (wateringMode == "manuel") ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isEditing
                        ? (wateringTime != null
                        ? "Heure d'arrosage choisie : ${wateringTime!.format(context)}"
                        : "Aucune heure d'arrosage choisie")
                        : (wateringTime != null
                        ? "Heure d’arrosage : ${wateringTime!.format(context)}"
                        : "Aucune heure d’arrosage définie"),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: wateringTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            wateringTime = picked;
                          });
                        }
                      },
                    ),
                ],
              ),
            ],
            if (status != null && status!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _getStatusIcon(status!),
                    color: _getStatusColor(status!),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(status!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _getStatusColor(status!),
                    ),
                  ),
                ],
              ),
            ],
            if (wateringMode == "manuel" && !isEditing) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _sendWatering,
                icon: const Icon(Icons.water_drop),
                label: const Text("Arroser"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            if (widget.lastModified != null) ...[
              const SizedBox(height: 20),
              Text(
                "Dernière modification : ${_formatDate(widget.lastModified!)}",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
