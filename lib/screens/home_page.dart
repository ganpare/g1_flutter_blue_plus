import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:charset/charset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/glass.dart';
import '../services/audio_handler.dart';
import '../services/bluetooth_manager.dart';
import '../services/commands.dart';
import '../widgets/glass_status.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  late PageTurnerAudioHandler _audioHandler;

  // Connection status
  String leftStatus = 'Disconnected';
  String rightStatus = 'Disconnected';

  // Page management state
  String _fileName = 'No file selected';
  List<String> _pages = [];
  int _currentPageIndex = 0;
  bool _isAudioServiceReady = false;

  @override
  void initState() {
    super.initState();
    _initAudioService();
  }

  Future<void> _initAudioService() async {
    print("DEBUG: _initAudioService started.");
    try {
      final status = await Permission.notification.request();
      print("DEBUG: Notification permission status: $status");

      if (status.isGranted || status.isLimited) {
        _audioHandler = await AudioService.init(
          builder: () => PageTurnerAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.ryanheise.audioservice.channel.audio',
            androidNotificationChannelName: 'Audio Service',
            androidNotificationOngoing: true,
          ),
        );
        print("DEBUG: AudioService.init completed.");

        _audioHandler.currentPageIndex.addListener(() {
          if (mounted) {
            setState(() {
              _currentPageIndex = _audioHandler.currentPageIndex.value;
            });
            _sendCurrentPageToDevice();
          }
        });

        if (mounted) {
          setState(() {
            _isAudioServiceReady = true;
          });
          print("DEBUG: _isAudioServiceReady set to true.");
        }
      } else {
        print("DEBUG: Notification permission not granted. Audio service will not initialize.");
        // Optionally, show a message to the user that permission is required
      }
    } catch (e) {
      print("ERROR: Error initializing audio service: $e");
      // Handle error appropriately, maybe show a dialog
    }
    print("DEBUG: _initAudioService finished.");
  }

  Future<void> _pickFile() async {
    print("DEBUG: _pickFile called");
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      print("DEBUG: File selected: ${file.name}, path: ${file.path}");
      setState(() {
        _fileName = file.name;
      });
      
      try {
        // Read file as bytes first
        List<int> bytes = await File(file.path!).readAsBytes();
        print("DEBUG: File read as bytes, length: ${bytes.length}");
        
        String usedEncoding = 'Unknown';
        
        // Try to detect encoding and decode
        Map<String, dynamic> result = await _detectAndDecodeText(bytes);
        usedEncoding = result['encoding'] as String;
        String textContent = result['text'] as String;
        
        if (textContent.isNotEmpty) {
          // Show which encoding was used
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File loaded with $usedEncoding encoding'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          _processTextFile(textContent);
        } else {
          print("DEBUG: All encodings failed");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not read file with any supported encoding'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print("DEBUG: Error reading file: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reading file: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print("DEBUG: User canceled file picker");
      // User canceled the picker
    }
  }

  void _processTextFile(String content) {
    print("DEBUG: _processTextFile called with content length: ${content.length}");
    List<String> lines = formatTextLines(content);
    print("DEBUG: formatTextLines returned ${lines.length} lines");
    List<String> pages = [];
    for (var i = 0; i < lines.length; i += 5) {
      pages.add(lines.sublist(i, i + 5 > lines.length ? lines.length : i + 5).join('\n'));
    }
    print("DEBUG: Created ${pages.length} pages");

    setState(() {
      _pages = pages;
      _currentPageIndex = 0;
    });
    print("DEBUG: setState completed, _pages.length = ${_pages.length}");

    if (_isAudioServiceReady) {
      _audioHandler.setPageCount(_pages.length);
      _audioHandler.setPageIndex(0);
    }
    _sendCurrentPageToDevice();
  }

  void _sendCurrentPageToDevice() {
    if (_pages.isNotEmpty && bluetoothManager.leftGlass != null) {
      sendTextPacket(
        textMessage: _pages[_currentPageIndex],
        bluetoothManager: bluetoothManager,
        pageNumber: _currentPageIndex + 1,
        maxPages: _pages.length,
        screenStatus: (_currentPageIndex == _pages.length - 1)
            ? AIStatus.DISPLAY_COMPLETE
            : AIStatus.DISPLAYING | ScreenAction.NEW_CONTENT,
      );
    }
  }

  bool _containsJapaneseCharacters(String content) {
    // Check for actual Japanese characters (Hiragana, Katakana, Kanji)
    final japaneseCharPattern = RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]');
    return japaneseCharPattern.hasMatch(content);
  }

  void _scanAndConnect() async {
    try {
      setState(() {
        leftStatus = 'Scanning...';
        rightStatus = 'Scanning...';
      });

      await bluetoothManager.startScanAndConnect(
        onGlassFound: (Glass glass) async {
          await _connectToGlass(glass);
        },
        onScanTimeout: (message) {
          setState(() {
            if (bluetoothManager.leftGlass == null) leftStatus = 'Not Found';
            if (bluetoothManager.rightGlass == null) rightStatus = 'Not Found';
          });
        },
        onScanError: (error) {
          setState(() {
            leftStatus = 'Scan Error';
            rightStatus = 'Scan Error';
          });
        },
      );
    } catch (e) {
      print('Error in _scanAndConnect: $e');
    }
  }

  Future<void> _connectToGlass(Glass glass) async {
    await glass.connect();
    setState(() {
      if (glass.side == 'left') {
        leftStatus = 'Connecting...';
      } else {
        rightStatus = 'Connecting...';
      }
    });

    glass.device.connectionState.listen((BluetoothConnectionState state) {
      if (mounted) {
        setState(() {
          if (glass.side == 'left') {
            leftStatus = state.toString().split('.').last;
          } else {
            rightStatus = state.toString().split('.').last;
          }
        });
      }
    });
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
      _sendCurrentPageToDevice();
      if (_isAudioServiceReady) {
        _audioHandler.setPageIndex(_currentPageIndex);
      }
    }
  }

  void _goToNextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      setState(() {
        _currentPageIndex++;
      });
      _sendCurrentPageToDevice();
      if (_isAudioServiceReady) {
        _audioHandler.setPageIndex(_currentPageIndex);
      }
    }
  }

  @override
  void dispose() {
    if (_isAudioServiceReady) {
      _audioHandler.stop();
    }
    bluetoothManager.leftGlass?.disconnect();
    bluetoothManager.rightGlass?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Even Glasses Control'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Connect to Glasses', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _scanAndConnect, child: const Text('Scan & Connect')),
                GlassStatus(side: 'Left', status: leftStatus),
                GlassStatus(side: 'Right', status: rightStatus),
              ],
            ),
            const Divider(height: 30),
            const Text('2. Select and Control Text File', style: TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Select .txt File'),
            ),
            if (!_isAudioServiceReady)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Note: Media controls unavailable (audio service initializing)',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 8),
            Text('File: $_fileName'),
            const SizedBox(height: 20),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _pages.isNotEmpty ? _pages[_currentPageIndex] : 'Select a file to see content here.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _pages.isNotEmpty ? 'Page ${_currentPageIndex + 1} of ${_pages.length}' : '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _pages.isNotEmpty && _currentPageIndex > 0 ? _goToPreviousPage : null,
                  child: const Text('Previous'),
                ),
                ElevatedButton(
                  onPressed: _pages.isNotEmpty && _currentPageIndex < _pages.length - 1 ? _goToNextPage : null,
                  child: const Text('Next'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Use buttons above or Bluetooth media controller to turn pages.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _detectAndDecodeText(List<int> bytes) async {
    // First check for UTF-8 BOM
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      try {
        String text = utf8.decode(bytes.sublist(3));
        return {'text': text, 'encoding': 'UTF-8 with BOM'};
      } catch (e) {
        print("DEBUG: UTF-8 with BOM failed: $e");
      }
    }

    // Try different encodings
    final encodingTests = [
      {
        'name': 'UTF-8',
        'test': () => utf8.decode(bytes, allowMalformed: false)
      },
      {
        'name': 'Shift_JIS',
        'test': () {
          try {
            return shiftJis.decode(bytes);
          } catch (e) {
            throw Exception('Shift_JIS decode failed: $e');
          }
        }
      },
      {
        'name': 'EUC-JP',
        'test': () {
          try {
            return eucJp.decode(bytes);
          } catch (e) {
            throw Exception('EUC-JP decode failed: $e');
          }
        }
      },
      {
        'name': 'UTF-8 (lenient)',
        'test': () => utf8.decode(bytes, allowMalformed: true)
      },
      {
        'name': 'Latin1',
        'test': () => latin1.decode(bytes)
      },
    ];

    for (var encoding in encodingTests) {
      try {
        final testFunction = encoding['test'] as String Function()?;
        if (testFunction != null) {
          String text = testFunction();
          if (text.isNotEmpty) {
            String encodingName = encoding['name'] as String;
            
            // Validate Japanese content for Japanese encodings
            if (['Shift_JIS', 'EUC-JP', 'ISO-2022-JP'].contains(encodingName)) {
              if (_containsJapaneseCharacters(text)) {
                print("DEBUG: Successfully decoded with $encodingName (Japanese detected)");
                return {'text': text, 'encoding': '$encodingName (Japanese detected)'};
              } else {
                print("DEBUG: $encodingName decoded but no Japanese characters found");
                continue;
              }
            } else {
              print("DEBUG: Successfully decoded with $encodingName");
              return {'text': text, 'encoding': encodingName};
            }
          }
        }
      } catch (e) {
        print("DEBUG: ${encoding['name']} failed: $e");
        continue;
      }
    }
    
    return {'text': '', 'encoding': 'Unknown'};
  }
}