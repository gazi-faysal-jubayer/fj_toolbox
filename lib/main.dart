import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const QRCodeApp());
}

// Enhanced QR Types
enum QRType { text, url, email, phone, wifi, vcard, calendar, location, sms }

enum ExportFormat { png, svg, pdf }

// Model for QR Code History
class QRCodeRecord {
  final String data;
  final String type;
  final DateTime timestamp;

  QRCodeRecord({
    required this.data,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'data': data,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QRCodeRecord.fromJson(Map<String, dynamic> json) => QRCodeRecord(
        data: json['data'],
        type: json['type'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class QRCodeApp extends StatelessWidget {
  const QRCodeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Master',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _screenshotController = ScreenshotController();
  String qrData = '';
  QRType selectedQRType = QRType.text;
  final TextEditingController _textController = TextEditingController();
  List<QRCodeRecord> scanHistory = [];

  // QR Code Customization Options
  Color qrColor = Colors.black;
  Color backgroundColor = Colors.white;
  double errorCorrectionLevel = 0.0; // 0.0 to 1.0
  QrEyeShape eyeShape = QrEyeShape.square; // Instead of QrEyeStyle
  QrDataModuleShape dataModuleShape = QrDataModuleShape.square;

  // Form Controllers for vCard
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();

  // Form Controllers for Calendar Event
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventDescriptionController =
      TextEditingController();
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Added History tab
    _loadScanHistory();
  }

  Future<void> _loadScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('scan_history') ?? [];
    setState(() {
      scanHistory = historyJson
          .map((item) => QRCodeRecord.fromJson(json.decode(item)))
          .toList();
    });
  }

  Future<void> _saveScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson =
        scanHistory.map((record) => json.encode(record.toJson())).toList();
    await prefs.setStringList('scan_history', historyJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Master'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Generate'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneratorTab(),
          _buildScannerTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildGeneratorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButton<QRType>(
                    value: selectedQRType,
                    isExpanded: true,
                    items: QRType.values.map((QRType type) {
                      return DropdownMenuItem<QRType>(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (QRType? newValue) {
                      setState(() {
                        selectedQRType = newValue!;
                        qrData = '';
                        _textController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputFields(),
                  const SizedBox(height: 16),
                  _buildCustomizationOptions(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (qrData.isNotEmpty) _buildQRCodePreview(),
        ],
      ),
    );
  }

  Widget _buildCustomizationOptions() {
    return ExpansionTile(
      title: const Text('Customization Options'),
      children: [
        ListTile(
          title: const Text('QR Code Color'),
          trailing: Container(
            width: 24,
            height: 24,
            color: qrColor,
          ),
          onTap: () => _showColorPicker(isBackground: false),
        ),
        ListTile(
          title: const Text('Background Color'),
          trailing: Container(
            width: 24,
            height: 24,
            color: backgroundColor,
          ),
          onTap: () => _showColorPicker(isBackground: true),
        ),
        ListTile(
          title: const Text('Error Correction'),
          trailing: Slider(
            value: errorCorrectionLevel,
            onChanged: (value) {
              setState(() => errorCorrectionLevel = value);
            },
          ),
        ),
        ListTile(
          title: const Text('Eye Shape'),
          trailing: DropdownButton<QrEyeShape>(
            value: eyeShape,
            items: QrEyeShape.values.map((shape) {
              return DropdownMenuItem(
                value: shape,
                child: Text(shape.toString().split('.').last),
              );
            }).toList(),
            onChanged: (QrEyeShape? value) {
              setState(() => eyeShape = value!);
            },
          ),
        ),
        ListTile(
          title: const Text('Module Shape'),
          trailing: DropdownButton<QrDataModuleShape>(
            value: dataModuleShape,
            items: QrDataModuleShape.values.map((shape) {
              return DropdownMenuItem(
                value: shape,
                child: Text(shape.toString().split('.').last),
              );
            }).toList(),
            onChanged: (QrDataModuleShape? value) {
              setState(() => dataModuleShape = value!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputFields() {
    switch (selectedQRType) {
      case QRType.vcard:
        return Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => _updateVCardData(),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: (_) => _updateVCardData(),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              onChanged: (_) => _updateVCardData(),
            ),
            TextField(
              controller: _organizationController,
              decoration: const InputDecoration(labelText: 'Organization'),
              onChanged: (_) => _updateVCardData(),
            ),
          ],
        );
      case QRType.calendar:
        return Column(
          children: [
            TextField(
              controller: _eventTitleController,
              decoration: const InputDecoration(labelText: 'Event Title'),
              onChanged: (_) => _updateCalendarData(),
            ),
            TextField(
              controller: _eventDescriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (_) => _updateCalendarData(),
            ),
            ListTile(
              title: const Text('Start Date'),
              trailing: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _eventStartDate = date;
                      _updateCalendarData();
                    });
                  }
                },
                child: Text(_eventStartDate?.toString() ?? 'Select'),
              ),
            ),
            ListTile(
              title: const Text('End Date'),
              trailing: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _eventEndDate = date;
                      _updateCalendarData();
                    });
                  }
                },
                child: Text(_eventEndDate?.toString() ?? 'Select'),
              ),
            ),
          ],
        );
      default:
        return TextField(
          controller: _textController,
          decoration: InputDecoration(
            labelText: _getInputLabel(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              qrData = value;
            });
          },
        );
    }
  }

  void _updateVCardData() {
    final vcard = '''BEGIN:VCARD
VERSION:3.0
FN:${_nameController.text}
EMAIL:${_emailController.text}
TEL:${_phoneController.text}
ORG:${_organizationController.text}
END:VCARD''';
    setState(() {
      qrData = vcard;
    });
  }

  void _updateCalendarData() {
    if (_eventStartDate != null && _eventEndDate != null) {
      final calendar = '''BEGIN:VEVENT
SUMMARY:${_eventTitleController.text}
DESCRIPTION:${_eventDescriptionController.text}
DTSTART:${_eventStartDate!.toIso8601String()}
DTEND:${_eventEndDate!.toIso8601String()}
END:VEVENT''';
      setState(() {
        qrData = calendar;
      });
    }
  }

  Future<void> _requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      // Request permission
      await Permission.storage.request();
    }
  }

  Widget _buildQRCodePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Screenshot(
              controller: _screenshotController,
              child: Container(
                color: backgroundColor,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: backgroundColor,
                  foregroundColor: qrColor,
                  errorCorrectionLevel: _getErrorCorrectionLevel(),
                  eyeStyle: QrEyeStyle(
                    eyeShape: eyeShape,
                    color: qrColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: dataModuleShape,
                    color: qrColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () async {
                    await _requestPermission(); // Request permission
                    _exportQR(ExportFormat.png);
                  },
                ),
                PopupMenuButton<ExportFormat>(
                  icon: const Icon(Icons.save_alt),
                  onSelected: _exportQR,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ExportFormat.png,
                      child: Text('Save as PNG'),
                    ),
                    const PopupMenuItem(
                      value: ExportFormat.svg,
                      child: Text('Save as SVG'),
                    ),
                    const PopupMenuItem(
                      value: ExportFormat.pdf,
                      child: Text('Save as PDF'),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: _shareQRCode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      itemCount: scanHistory.length,
      itemBuilder: (context, index) {
        final record = scanHistory[index];
        return ListTile(
          title: Text(record.data),
          subtitle: Text(
            '${record.type} - ${record.timestamp.toString().split('.')[0]}',
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Text('Copy'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                setState(() {
                  scanHistory.removeAt(index);
                  _saveScanHistory();
                });
              }
              // Implement copy functionality
            },
          ),
        );
      },
    );
  }

  // Helper methods for export functionality

  Future<void> _exportQR(ExportFormat format) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      _showMessage('Permission denied');
      return;
    }

    switch (format) {
      case ExportFormat.png:
        await _saveQRCode();
        break;
      case ExportFormat.svg:
        // Implement SVG export
        break;
      case ExportFormat.pdf:
        // Implement PDF export
        break;
    }
  }

  int _getErrorCorrectionLevel() {
    if (errorCorrectionLevel < 0.25) {
      return 0; // QrErrorCorrectLevel.L - Low - 7% correction
    } else if (errorCorrectionLevel < 0.5) {
      return 1; // QrErrorCorrectLevel.M - Medium - 15% correction
    } else if (errorCorrectionLevel < 0.75) {
      return 2; // QrErrorCorrectLevel.Q - Quartile - 25% correction
    } else {
      return 3; // QrErrorCorrectLevel.H - High - 30% correction
    }
  }

  String _getInputLabel() {
    switch (selectedQRType) {
      case QRType.text:
        return 'Enter text';
      case QRType.url:
        return 'Enter URL';
      case QRType.email:
        return 'Enter email address';
      case QRType.phone:
        return 'Enter phone number';
      case QRType.wifi:
        return 'Enter WiFi SSID';
      case QRType.location:
        return 'Enter coordinates (lat,long)';
      case QRType.sms:
        return 'Enter phone number and message';
      default:
        return 'Enter data';
    }
  }

  Future<void> _saveQRCode() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        _showMessage('Failed to generate image');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      final result = await ImageGallerySaverPlus.saveFile(imagePath);
      if (result['isSuccess']) {
        _showMessage('QR Code saved successfully');
      } else {
        _showMessage('Failed to save QR Code');
      }
    } catch (e) {
      _showMessage('Error: $e');
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        _showMessage('Failed to generate image');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/qr_code_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      await Share.shareFiles([imagePath], text: 'Share QR Code');
    } catch (e) {
      _showMessage('Error sharing QR Code: $e');
    }
  }

  Widget _buildScannerTab() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleScannedCode(barcode.rawValue!);
                }
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Scan from Gallery'),
                onPressed: _scanFromGallery,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on),
                label: const Text('Toggle Flash'),
                onPressed: () {
                  // Implement flash toggle
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Implement QR code scanning from image
      // You'll need to use a package that can detect QR codes from images
    }
  }

  void _handleScannedCode(String scannedData) {
    // Add to history
    final newRecord = QRCodeRecord(
      data: scannedData,
      type: _detectQRType(scannedData),
      timestamp: DateTime.now(),
    );

    setState(() {
      scanHistory.insert(0, newRecord);
      if (scanHistory.length > 50) {
        // Limit history to 50 items
        scanHistory.removeLast();
      }
    });

    _saveScanHistory();
    _showScannedDataDialog(scannedData);
  }

  String _detectQRType(String data) {
    if (data.startsWith('BEGIN:VCARD')) return 'vCard';
    if (data.startsWith('BEGIN:VEVENT')) return 'Calendar';
    if (data.startsWith('http')) return 'URL';
    if (data.contains('@')) return 'Email';
    if (data.startsWith('tel:')) return 'Phone';
    if (data.startsWith('WIFI:')) return 'WiFi';
    return 'Text';
  }

  void _showScannedDataDialog(String data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanned QR Code'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    onPressed: () {
                      // Implement copy to clipboard
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () {
                      Share.share(data);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showColorPicker({required bool isBackground}) {
    // Implement color picker dialog
    // You can use the flutter_colorpicker package
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _eventTitleController.dispose();
    _eventDescriptionController.dispose();
    super.dispose();
  }
}
