import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

// 轉錄記錄項目類
class TranscriptionRecord {
  String id;
  String text;
  DateTime timestamp;
  bool isImportant;

  TranscriptionRecord({
    required this.id,
    required this.text,
    required this.timestamp,
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isImportant': isImportant,
    };
  }

  factory TranscriptionRecord.fromJson(Map<String, dynamic> json) {
    return TranscriptionRecord(
      id: json['id'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      isImportant: json['isImportant'] ?? false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('whisper_voice_notes');
  
  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isTranscribing = false;
  String _recordingPath = '';
  String _systemInfo = '';
  int? _whisperContextPtr;
  Duration _recordingDuration = Duration.zero;
  
  // 模型選擇相關變數
  String _selectedModel = 'tiny'; // 預設選擇tiny模型
  String _currentLoadedModel = '';
  
  final Map<String, String> _modelOptions = {
    'tiny': 'Tiny 模型 (31MB) - 更快速',
    'base': 'Base 模型 (57MB) - 更準確',
  };
  
  // 快閃筆記清單相關變數
  List<TranscriptionRecord> _transcriptionRecords = [];
  static const String _recordsKey = 'transcription_records';
  static const String _selectedModelKey = 'selected_model';
  
  // 詳細內容顯示相關變數
  bool _showDetailView = false;
  TranscriptionRecord? _selectedRecord;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _initializeRecording();
    await _getSystemInfo();
    await _loadTranscriptionRecords();
    await _loadSelectedModel();
    // 自動載入選定的模型
    await _loadModel();
  }

  Future<void> _getSystemInfo() async {
    try {
      final String systemInfo = await platform.invokeMethod('getSystemInfo');
      setState(() {
        _systemInfo = systemInfo;
      });
    } catch (e) {
      print('獲取系統資訊失敗: $e');
    }
  }

  Future<void> _initializeRecording() async {
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    // 設定固定的錄音路徑
    final directory = await getApplicationDocumentsDirectory();
    _recordingPath = '${directory.path}/recording.wav';
  }

  Future<void> _loadModel() async {
    if (_isModelLoading) return;
    
    setState(() {
      _isModelLoading = true;
    });

    try {
      // 獲取應用程式目錄
      final directory = await getApplicationDocumentsDirectory();

      // 根據選擇的模型設定檔案路徑
      final modelFileName = _selectedModel == 'tiny' ? 'ggml-tiny-q5_1.bin' : 'ggml-base-q5_1.bin';
      final modelPath = '${directory.path}/$modelFileName';
      final modelFile = File(modelPath);

      // 如果模型不存在，從 assets 複製
      if (!await modelFile.exists()) {
        await platform.invokeMethod('copyAssetToFile', {
          'assetName': 'models/$modelFileName',
          'targetPath': modelPath,
        });
      }

      // 載入模型
      final contextPtr = await platform.invokeMethod('loadModel', {
        'modelPath': modelPath,
      });

      if (contextPtr != null && contextPtr is int && contextPtr != 0) {
        setState(() {
          _isModelLoaded = true;
          _whisperContextPtr = contextPtr;
          _currentLoadedModel = _selectedModel;
        });
        _showSuccessSnackBar('${_modelOptions[_selectedModel]}載入成功！');
      } else {
        throw Exception('載入模型失敗：返回的 context pointer 無效');
      }
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _whisperContextPtr = null;
      });
      _showErrorSnackBar('載入模型失敗: $e');
    } finally {
      setState(() {
        _isModelLoading = false;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isDenied) {
      _showErrorSnackBar('需要麥克風權限才能錄音');
      return false;
    }
    return true;
  }

  Future<void> _startRecording() async {
    if (!_isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先載入模型')),
      );
      return;
    }

    if (!await _requestPermissions()) return;

    try {
      if (await _audioRecorder!.hasPermission()) {
        await _audioRecorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            bitRate: 256000,
            numChannels: 1,
          ),
          path: _recordingPath,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _showSuccessSnackBar('開始錄音...');
        _startTimer();
      }
    } catch (e) {
      _showErrorSnackBar('錄音失敗: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder!.stop();
      
      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });

      _showSuccessSnackBar('錄音完成！正在自動轉錄...');
      
      // 自動觸發轉錄
      await _transcribeAudio();
    } catch (e) {
      _showErrorSnackBar('停止錄音失敗: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath.isEmpty || !File(_recordingPath).existsSync()) {
      _showErrorSnackBar('沒有錄音檔案可播放');
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer!.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer!.play(DeviceFileSource(_recordingPath));
        setState(() {
          _isPlaying = true;
        });

        _audioPlayer!.onPlayerComplete.listen((event) {
          setState(() {
            _isPlaying = false;
          });
        });

        _showSuccessSnackBar('開始播放錄音');
      }
    } catch (e) {
      _showErrorSnackBar('播放失敗: $e');
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        setState(() {
          _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
        });
        _startTimer();
      }
    });
  }

  Future<void> _transcribeAudio() async {
    if (_recordingPath.isEmpty || _whisperContextPtr == null) {
      _showErrorSnackBar('錯誤：沒有可轉錄的錄音檔案或模型未載入');
      return;
    }

    final stopwatch = Stopwatch()..start();

    setState(() {
      _isTranscribing = true;
    });

    try {
      final String result = await platform.invokeMethod('transcribeAudio', {
        'contextPtr': _whisperContextPtr,
        'audioPath': _recordingPath,
        'threads': 6,
      }).timeout(
        Duration(seconds: 60),
        onTimeout: () {
          stopwatch.stop();
          throw Exception('轉錄超時（60秒）- 耗時: ${stopwatch.elapsedMilliseconds}ms');
        },
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final elapsedSeconds = (elapsedMs / 1000).toStringAsFixed(2);

      // 自動添加轉錄結果到快閃筆記
      if (result.trim().isNotEmpty) {
        await _addTranscriptionRecord(result.trim());
      }

      // 顯示轉錄成功的浮動通知
      _showTranscriptionSuccessToast(result.trim(), elapsedSeconds);

    } catch (e) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final elapsedSeconds = (elapsedMs / 1000).toStringAsFixed(2);

      // 轉錄失敗時的錯誤處理
      print('轉錄失敗: $e (耗時: ${elapsedSeconds}s)');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('轉錄失敗'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

    } finally {
      setState(() {
        _isTranscribing = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }



  // ============ 快閃筆記清單相關函數 ============
  
  Future<void> _loadTranscriptionRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recordsJson = prefs.getString(_recordsKey);
      
      if (recordsJson != null) {
        final List<dynamic> recordsList = json.decode(recordsJson);
        setState(() {
          _transcriptionRecords = recordsList
              .map((record) => TranscriptionRecord.fromJson(record))
              .toList();
        });
      }
    } catch (e) {
      print('載入轉錄記錄失敗: $e');
    }
  }

  Future<void> _saveTranscriptionRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String recordsJson = json.encode(
        _transcriptionRecords.map((record) => record.toJson()).toList(),
      );
      await prefs.setString(_recordsKey, recordsJson);
    } catch (e) {
      print('保存轉錄記錄失敗: $e');
    }
  }

  Future<void> _addTranscriptionRecord(String text) async {
    final newRecord = TranscriptionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _transcriptionRecords.insert(0, newRecord); // 新記錄放在最前面
    });

    await _saveTranscriptionRecords();
  }

  Future<void> _editTranscriptionRecord(int index, String newText) async {
    if (index >= 0 && index < _transcriptionRecords.length) {
      setState(() {
        _transcriptionRecords[index].text = newText;
      });
      await _saveTranscriptionRecords();
      _showSuccessSnackBar('記錄已更新');
    }
  }

  Future<void> _deleteTranscriptionRecord(int index) async {
    if (index >= 0 && index < _transcriptionRecords.length) {
      setState(() {
        _transcriptionRecords.removeAt(index);
      });
      await _saveTranscriptionRecords();
      _showSuccessSnackBar('記錄已刪除');
    }
  }

  void _showEditDialog(int index) {
    final TextEditingController controller = TextEditingController(
      text: _transcriptionRecords[index].text,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('編輯記錄'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '請輸入文字...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _editTranscriptionRecord(index, controller.text.trim());
                }
                Navigator.of(context).pop();
              },
              child: Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('確認刪除'),
          content: Text('確定要刪除這條記錄嗎？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _deleteTranscriptionRecord(index);
                Navigator.of(context).pop();
              },
              child: Text('刪除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 顯示轉錄成功的浮動通知
  void _showTranscriptionSuccessToast(String result, String elapsedSeconds) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '轉錄完成！',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '內容: $result',
                style: TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                '耗時: ${elapsedSeconds}s',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // 保存和載入模型選擇
  Future<void> _saveSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedModelKey, _selectedModel);
    } catch (e) {
      print('保存模型選擇失敗: $e');
    }
  }

  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedModel = prefs.getString(_selectedModelKey);
      if (savedModel != null && _modelOptions.containsKey(savedModel)) {
        setState(() {
          _selectedModel = savedModel;
        });
      }
    } catch (e) {
      print('載入模型選擇失敗: $e');
    }
  }

  // 顯示詳細內容
  void _showRecordDetail(TranscriptionRecord record) {
    setState(() {
      _selectedRecord = record;
      _showDetailView = true;
    });
  }

  // 關閉詳細內容
  void _closeDetailView() {
    setState(() {
      _showDetailView = false;
      _selectedRecord = null;
    });
  }

  // 切換筆記重要性
  Future<void> _toggleImportance(TranscriptionRecord record) async {
    setState(() {
      record.isImportant = !record.isImportant;
    });
    await _saveTranscriptionRecords();
    _showSuccessSnackBar(record.isImportant ? '已標記為重要' : '已取消重要標記');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.mic,
              color: Colors.deepPurple,
              size: 28,
            ),
            SizedBox(width: 8),
            Text('Whisper 語音筆記'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 模型選擇 Dropdown
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inversePrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
            child: DropdownButton<String>(
              value: _selectedModel,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
              iconSize: 20,
              elevation: 8,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              underline: Container(),
              dropdownColor: Theme.of(context).colorScheme.inversePrimary,
              items: _modelOptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: entry.key == 'tiny' ? Colors.green : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          entry.key == 'tiny' ? 'Tiny (快)' : 'Base (準確)',
                          style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: _isModelLoading || _isRecording || _isTranscribing 
                  ? null 
                  : (String? newValue) async {
                      if (newValue != null && newValue != _selectedModel) {
                        setState(() {
                          _selectedModel = newValue;
                          _isModelLoaded = false;
                          _whisperContextPtr = null;
                        });
                        // 保存模型選擇
                        await _saveSelectedModel();
                        // 自動載入新選擇的模型
                        await _loadModel();
                      }
                    },
            ),
          ),
        ],
      ),
              body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 模型載入狀態顯示（如果正在載入）
              if (_isModelLoading)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '正在載入 ${_modelOptions[_selectedModel]}...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isModelLoading) SizedBox(height: 16),

            // 錄音狀態顯示
            if (_isRecording)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      '錄音中... ${_formatDuration(_recordingDuration)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16),

            // 控制按鈕 - 三個按鈕在同一排
            Row(
              children: [
                // 開始錄音按鈕
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isModelLoaded && !_isRecording && !_isTranscribing
                        ? _startRecording
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(Icons.mic),
                    label: Text('錄製想法', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SizedBox(width: 6),
                // 停止錄音並轉錄按鈕
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRecording || (_hasRecording && !_isTranscribing)
                        ? _isRecording ? _stopRecording : _transcribeAudio
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording 
                          ? Colors.grey 
                          : _isTranscribing 
                            ? Colors.orange 
                            : Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(
                      _isRecording 
                          ? Icons.stop 
                          : _isTranscribing 
                            ? Icons.hourglass_empty 
                            : Icons.text_fields
                    ),
                    label: Text(
                      _isRecording 
                          ? '停止並轉錄' 
                          : _isTranscribing 
                            ? '轉錄中...' 
                            : '重新轉錄',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                // 播放錄音按鈕
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hasRecording && !_isRecording && !_isTranscribing
                        ? _playRecording
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlaying ? Colors.orange : Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isPlaying ? '停止播放' : '播放錄音',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),

            // 快閃筆記清單 - 核心功能區域！
            if (_transcriptionRecords.isNotEmpty) ...[
              Container(
                height: 500, // 加倍高度，給更多空間顯示筆記
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.amber.withOpacity(0.05), Colors.orange.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // 清單標題
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.withOpacity(0.15), Colors.orange.withOpacity(0.15)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '💡 快閃筆記 (${_transcriptionRecords.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '點擊查看詳情',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 清單內容
                    Expanded(
                      child: ListView.builder(
                        itemCount: _transcriptionRecords.length,
                        itemBuilder: (context, index) {
                          final record = _transcriptionRecords[index];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.amber.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              onTap: () => _showRecordDetail(record), // 添加點擊事件
                              leading: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      record.text,
                                      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (record.isImportant) ...[
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.star,
                                      size: 20,
                                      color: Colors.red.shade600,
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${record.timestamp.month}/${record.timestamp.day} ${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 18, color: Colors.blue),
                                    onPressed: () => _showEditDialog(index),
                                    tooltip: '編輯',
                                    padding: EdgeInsets.all(4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmDialog(index),
                                    tooltip: '刪除',
                                    padding: EdgeInsets.all(4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // 詳細內容顯示區域
            if (_showDetailView && _selectedRecord != null)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue.withOpacity(0.02),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                                              Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '📄 筆記詳情',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                SizedBox(width: 12),
                                InkWell(
                                  onTap: () => _toggleImportance(_selectedRecord!),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _selectedRecord!.isImportant 
                                          ? Colors.red.shade100 
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _selectedRecord!.isImportant 
                                            ? Colors.red.shade300 
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _selectedRecord!.isImportant ? Icons.star : Icons.star_outline,
                                          size: 16,
                                          color: _selectedRecord!.isImportant 
                                              ? Colors.red.shade600 
                                              : Colors.grey.shade600,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          _selectedRecord!.isImportant ? '重要' : '標記',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedRecord!.isImportant 
                                                ? Colors.red.shade600 
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _selectedRecord!.text));
                                    _showSuccessSnackBar('已複製到剪貼簿');
                                  },
                                  icon: Icon(Icons.copy, color: Colors.grey.shade600),
                                  tooltip: '複製內容',
                                ),
                                IconButton(
                                  onPressed: _closeDetailView,
                                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                                  tooltip: '關閉',
                                ),
                              ],
                            ),
                          ],
                        ),
                      Divider(color: Colors.blue.withOpacity(0.3)),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📝 筆記內容',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _selectedRecord!.text,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🕐 創建時間',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_selectedRecord!.timestamp.year}/${_selectedRecord!.timestamp.month.toString().padLeft(2, '0')}/${_selectedRecord!.timestamp.day.toString().padLeft(2, '0')} ${_selectedRecord!.timestamp.hour.toString().padLeft(2, '0')}:${_selectedRecord!.timestamp.minute.toString().padLeft(2, '0')}:${_selectedRecord!.timestamp.second.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 提示信息（當沒有選中詳細內容時）
            if (!_showDetailView)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _transcriptionRecords.isEmpty
                              ? _isModelLoaded 
                                ? '點擊錄製想法來創建你的第一個快閃筆記！' 
                                : '正在載入 Whisper 模型，請稍候...'
                              : '點擊上方的快閃筆記來查看詳細內容',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                        if (_transcriptionRecords.isEmpty && _isModelLoaded) ...[
                          SizedBox(height: 16),
                          Text(
                            '💡 靈感稍縱即逝，用語音快速記錄你的想法！',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 