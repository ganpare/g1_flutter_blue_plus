import 'package:flutter/material.dart';
import '../services/bluetooth_manager.dart';
import '../services/display_utils.dart';

class EnhancedDisplayPage extends StatefulWidget {
  final BluetoothManager bluetoothManager;
  
  const EnhancedDisplayPage({
    super.key,
    required this.bluetoothManager,
  });

  @override
  State<EnhancedDisplayPage> createState() => _EnhancedDisplayPageState();
}

class _EnhancedDisplayPageState extends State<EnhancedDisplayPage> {
  int _selectedDemo = 0;
  double _progressValue = 0.5;
  int _selectedMenuItem = 0;

  final List<String> _demoTypes = [
    'Bordered Text',
    'Progress Bar',
    'Menu Display',
    'Status Display',
    'Simple Chart',
    'Alert Messages',
  ];

  final List<String> _menuItems = [
    'Settings',
    'Bluetooth',
    'Display',
    'Audio',
    'About',
  ];

  final List<double> _chartData = [0.2, 0.5, 0.8, 0.3, 0.9, 0.1, 0.7, 0.4];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Display Demos'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Display Type',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: _selectedDemo,
                      isExpanded: true,
                      items: _demoTypes.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDemo = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Demo-specific controls
            if (_selectedDemo == 1) _buildProgressControls(),
            if (_selectedDemo == 2) _buildMenuControls(),
            
            const SizedBox(height: 16),
            
            // Preview card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Text(
                        _generateDemoContent(),
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendToGlasses,
                    icon: const Icon(Icons.send),
                    label: const Text('Send to Glasses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _clearDisplay,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Value',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _progressValue,
              onChanged: (value) {
                setState(() {
                  _progressValue = value;
                });
              },
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${(_progressValue * 100).toInt()}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Menu Item',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _menuItems.asMap().entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedMenuItem == entry.key,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMenuItem = entry.key;
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _generateDemoContent() {
    switch (_selectedDemo) {
      case 0: // Bordered Text
        return DisplayUtils.createBorderedText(
          'Hello World!\nThis is a bordered text example for Even G1.',
          title: 'Message',
          useUnicode: true,
        );
      
      case 1: // Progress Bar
        return DisplayUtils.createProgressBar(
          _progressValue,
          label: 'Loading',
          showPercentage: true,
        );
      
      case 2: // Menu Display
        return DisplayUtils.createMenu(
          _menuItems,
          selectedIndex: _selectedMenuItem,
          cursor: '→',
        );
      
      case 3: // Status Display
        return DisplayUtils.createStatusDisplay(
          title: 'Even G1 Status',
          status: 'Connected',
          isConnected: widget.bluetoothManager.leftGlass != null,
        );
      
      case 4: // Simple Chart
        return DisplayUtils.createSimpleChart(
          _chartData,
          title: 'Data Visualization',
          height: 3,
        );
      
      case 5: // Alert Messages
        return DisplayUtils.createAlert(
          'This is an important alert message for your attention!',
          type: AlertType.warning,
        );
      
      default:
        return 'Select a demo type to preview';
    }
  }

  void _sendToGlasses() async {
    if (widget.bluetoothManager.leftGlass == null) {
      _showSnackBar('Please connect to Even G1 glasses first');
      return;
    }

    String content = _generateDemoContent();
    
    try {
      await DisplayUtils.sendEnhancedDisplay(
        content: content,
        bluetoothManager: widget.bluetoothManager,
      );
      _showSnackBar('Content sent to glasses successfully!');
    } catch (e) {
      _showSnackBar('Error sending to glasses: $e');
    }
  }

  void _clearDisplay() async {
    if (widget.bluetoothManager.leftGlass == null) {
      _showSnackBar('Please connect to Even G1 glasses first');
      return;
    }

    try {
      await DisplayUtils.sendEnhancedDisplay(
        content: '\n\n\n\n',
        bluetoothManager: widget.bluetoothManager,
      );
      _showSnackBar('Display cleared');
    } catch (e) {
      _showSnackBar('Error clearing display: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
