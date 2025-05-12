// 必要なパッケージのインポート
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

// アプリのルートウィジェット
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TR4 温度取得アプリ',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BleHomePage(),
    );
  }
}

// メイン画面ウィジェット
class BleHomePage extends StatefulWidget {
  const BleHomePage({super.key});

  @override
  State<BleHomePage> createState() => _BleHomePageState();
}

class _BleHomePageState extends State<BleHomePage> {
  final List<ScanResult> scanResults = [];
  bool isScanning = false;

  BluetoothDevice? selectedDevice;
  ScanResult? selectedResult;

  String latestTemperature = '';
  String lastUpdatedTime = '';

  // BLEスキャンを開始。BluetoothがONになるまで待機。
  Future<void> startScan() async {
    while (true) {
      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.on) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    await FlutterBluePlus.stopScan();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults.clear();
        scanResults.addAll(results.where((r) {
          final mfgData = r.advertisementData.manufacturerData;
          final hasCompanyId = mfgData.keys.contains(0x0392); // TR4のCompany ID
          return hasCompanyId;
        }));
      });
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      setState(() {
        isScanning = scanning;
      });
    });
  }

  // BLEスキャンを停止
  void stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  // デバイスの選択および選択解除
  void selectDevice(ScanResult? result) {
    if (selectedDevice == result?.device) {
      selectedDevice = null;
      selectedResult = null; // 選択解除
    } else {
      selectedDevice = result?.device;
      selectedResult = result; // 新規選択
    }
    setState(() {});
  }

  // アドバタイズデータから温度情報を取得して表示
  void getTemperatureFromAdvertisement() {
    if (selectedResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デバイスを選択してください')),
      );
      return;
    }

    final data = selectedResult!.advertisementData.manufacturerData[0x0392];
    if (data == null || data.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('温度データが取得できません')),
      );
      return;
    }

    // 温度データは7-8バイト目に格納。リトルエンディアンで解釈。
    final int tempRaw = data[6] | (data[7] << 8);
    if (tempRaw == 0xEEEE) {
      latestTemperature = '無効データ';
    } else {
      final double tempC = (tempRaw - 1000) / 10.0;
      latestTemperature = '$tempC ℃';
    }

    lastUpdatedTime = _currentTimeString();
    setState(() {});
  }

  // 現在時刻をフォーマットして返す
  String _currentTimeString() {
    final now = DateTime.now();
    return '${now.year}/${_pad(now.month)}/${_pad(now.day)} '
           '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
  }

  // 2桁表示のためにゼロ埋めするヘルパー関数
  String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TR4 温度取得アプリ')),
      body: Column(
        children: [
          // BLEスキャン制御ボタン
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: isScanning ? stopScan : startScan,
              child: Text(isScanning ? 'スキャン停止' : 'BLEスキャン開始'),
            ),
          ),
          // スキャン結果リスト表示
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final result = scanResults[index];
                final isSelected = result.device.id.id == selectedDevice?.id.id;

                return Container(
                  color: isSelected ? Colors.lightBlue[100] : null,
                  child: ListTile(
                    title: Text(result.device.name.isNotEmpty
                        ? result.device.name
                        : '(名称未設定)'),
                    // subtitle: Text(result.device.id.id),
                    trailing: ElevatedButton(
                      onPressed: () => selectDevice(isSelected ? null : result),
                      child: Text(isSelected ? '選択解除' : '選択'),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          // 温度取得ボタン
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: getTemperatureFromAdvertisement,
              child: const Text('最新の温度情報を取得'),
            ),
          ),
          // 温度情報表示
          Text(
            '最新温度: $latestTemperature',
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            '取得時刻: $lastUpdatedTime',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
