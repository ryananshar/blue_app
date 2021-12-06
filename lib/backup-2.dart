import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  const BluetoothApp({Key? key}) : super(key: key);

  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  // initiate bt connectien state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  // bt instance
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  // track bt connection with remote device
  late BluetoothConnection connection;

  late bool _isButtonUnavailable;

  // track wheter device si still connected to bt
  bool get isConnected => connection.isConnected;

  // for storing the devices list
  List<BluetoothDevice> _devicesList = [];

  bool isDisconnecting = false;

  late int _deviceState;

  // track bt device connection state
  @override
  void initState() {
    super.initState();

    // get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0;

    // If the Bluetooth of the device is not enabled,
    // then request permission to turn on Bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // For retrieving the paired devices list
        getPairedDevices();
      });
    });
  }

  Future<bool> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the Bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  Future<Void?> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // Get list paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return null;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection;
    }

    super.dispose();
  }

  bool _connected = false;
  BluetoothDevice? _device;

  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(const DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      for (var device in _devicesList) {
        items.add(DropdownMenuItem(
          child: Text(device.name.toString()),
          value: device,
        ));
      }
    }
    return items;
  }

  void _connect() async {
    if (_device == null) {
      print('No device selected');
    } else {
      // If a device is selected from the
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device!.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;

          // Updating the device connectivity
          // status to [true]
          setState(() {
            _connected = true;
          });

          connection.input!.listen(null).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        print('Device connected');
      }
    }
  }

  void _disconnect() async {
    // Closing the Bluetooth connection
    await connection.close();
    print('Device disconnected');

    // Update the [_connected] variable
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
      });
    }
  }

// turning the Bluetooth device on
  void _sendOnMessageToBluetooth() async {
    var encodedOn = utf8.encode("1" + "\r\n");
    connection.output.add(Uint8List.fromList(encodedOn));
    await connection.output.allSent;
    print('Device Turned On');
    setState(() {
      _deviceState = 1; // device on
    });
  }

// turning the Bluetooth device off
  void _sendOffMessageToBluetooth() async {
    var encodedOff = utf8.encode("0" + "\r\n");
    connection.output.add(Uint8List.fromList(encodedOff));
    await connection.output.allSent;
    print('Device Turned Off');
    setState(() {
      _deviceState = -1; // device off
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepOrangeAccent[400],
        title: const Text('Flutter Bluetooth'),
        centerTitle: true,
        elevation: 10,
      ),
      body: SafeArea(
        child: Container(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Enable Bluetooth',
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Switch(
                        value: _bluetoothState.isEnabled,
                        onChanged: (bool value) {
                          future() async {
                            if (value) {
                              // enable bt
                              await FlutterBluetoothSerial.instance
                                  .requestEnable();
                            } else {
                              // disable bt
                              await FlutterBluetoothSerial.instance
                                  .requestDisable();
                            }

                            await getPairedDevices();
                            _isButtonUnavailable = false;

                            // Disconnect any device before turning off bt
                            if (_connected) {
                              _disconnect();
                            }
                          }

                          future().then((_) {
                            setState(() {});
                          });
                        }),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  'Paired Device',
                  style: TextStyle(
                    fontSize: 21.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.lightBlue,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Device: ',
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    DropdownButton(
                      items: _getDeviceItems(),
                      onChanged: (value) =>
                          setState(() => _device = value as BluetoothDevice?),
                      value: _devicesList.isNotEmpty ? _device : null,
                    ),
                    ElevatedButton(
                      onPressed: _isButtonUnavailable
                          ? null
                          : _connected
                              ? _disconnect
                              : _connect,
                      child: Text(_connected ? 'Disconnect' : 'Connect'),
                    ),
                  ],
                ),
              ],
            )),
      ),
    );
  }
}
