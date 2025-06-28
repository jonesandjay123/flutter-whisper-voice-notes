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

// 常量定義
class AppConstants {
  static const String recordsKey = 'transcription_records';
  static const String selectedModelKey = 'selected_model';
  static const double buttonPadding = 12;
  static const double iconSize = 18;
  static const int transcriptionTimeout = 60;
  
  // 文字常量
  static const String appTitle = 'Whisper 語音筆記';
  static const String recordIdea = '錄製想法';
  static const String stopAndTranscribe = '停止並轉錄';
  static const String transcribing = '轉錄中...';
  static const String retranscribe = '重新轉錄';
  static const String playRecording = '播放錄音';
  static const String stopPlaying = '停止播放';
  static const String flashNotes = '💡 快閃筆記';
  static const String noteDetail = '📄 筆記詳情';
  static const String important = '重要';
  static const String mark = '標記';
  static const String clickForDetail = '點擊查看詳情';
}

// 消息類型枚舉
enum MessageType { success, error, info }

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
  
  // Audio related
  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  String _recordingPath = '';
  
  // Model related
  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isTranscribing = false;
  String _selectedModel = 'tiny';
  String _currentLoadedModel = '';
  int? _whisperContextPtr;
  
  final Map<String, String> _modelOptions = {
    'tiny': 'Tiny 模型 (31MB) - 更快速',
    'base': 'Base 模型 (57MB) - 更準確',
  };
  
  // Notes related
  List<TranscriptionRecord> _transcriptionRecords = [];
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

  // ============ 初始化方法 ============
  
  Future<void> _initializeApp() async {
    await _initializeRecording();
    await _loadTranscriptionRecords();
    await _loadSelectedModel();
    await _loadModel();
  }

  Future<void> _initializeRecording() async {
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    final directory = await getApplicationDocumentsDirectory();
    _recordingPath = '${directory.path}/recording.wav';
  }

  // ============ 模型相關方法 ============
  
  Future<void> _loadModel() async {
    if (_isModelLoading) return;
    
    setState(() {
      _isModelLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final modelFileName = _selectedModel == 'tiny' ? 'ggml-tiny-q5_1.bin' : 'ggml-base-q5_1.bin';
      final modelPath = '${directory.path}/$modelFileName';
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        await platform.invokeMethod('copyAssetToFile', {
          'assetName': 'flutter_assets/assets/models/$modelFileName',
          'targetPath': modelPath,
        });
      }

      final contextPtr = await platform.invokeMethod('loadModel', {
        'modelPath': modelPath,
      });

      if (contextPtr != null && contextPtr is int && contextPtr != 0) {
        setState(() {
          _isModelLoaded = true;
          _whisperContextPtr = contextPtr;
          _currentLoadedModel = _selectedModel;
        });
        _showMessage('${_modelOptions[_selectedModel]}載入成功！', MessageType.success);
      } else {
        throw Exception('載入模型失敗：返回的 context pointer 無效');
      }
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _whisperContextPtr = null;
      });
      _showMessage('載入模型失敗: $e', MessageType.error);
    } finally {
      setState(() {
        _isModelLoading = false;
      });
    }
  }

  Future<void> _saveSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.selectedModelKey, _selectedModel);
    } catch (e) {
      print('保存模型選擇失敗: $e');
    }
  }

  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedModel = prefs.getString(AppConstants.selectedModelKey);
      if (savedModel != null && _modelOptions.containsKey(savedModel)) {
        setState(() {
          _selectedModel = savedModel;
        });
      }
    } catch (e) {
      print('載入模型選擇失敗: $e');
    }
  }

  // ============ 錄音相關方法 ============
  
  Future<bool> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isDenied) {
      _showMessage('需要麥克風權限才能錄音', MessageType.error);
      return false;
    }
    return true;
  }

  Future<void> _startRecording() async {
    if (!_isModelLoaded) {
      _showMessage('請先載入模型', MessageType.error);
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

        _showMessage('開始錄音...', MessageType.info);
        _startTimer();
      }
    } catch (e) {
      _showMessage('錄音失敗: $e', MessageType.error);
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder!.stop();
      
      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });

      _showMessage('錄音完成！正在自動轉錄...', MessageType.success);
      await _transcribeAudio();
    } catch (e) {
      _showMessage('停止錄音失敗: $e', MessageType.error);
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath.isEmpty || !File(_recordingPath).existsSync()) {
      _showMessage('沒有錄音檔案可播放', MessageType.error);
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

        _showMessage('開始播放錄音', MessageType.success);
      }
    } catch (e) {
      _showMessage('播放失敗: $e', MessageType.error);
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

  // ============ 轉錄相關方法 ============
  
  Future<void> _transcribeAudio() async {
    if (_recordingPath.isEmpty || _whisperContextPtr == null) {
      _showMessage('錯誤：沒有可轉錄的錄音檔案或模型未載入', MessageType.error);
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
        Duration(seconds: AppConstants.transcriptionTimeout),
        onTimeout: () {
          stopwatch.stop();
          throw Exception('轉錄超時（${AppConstants.transcriptionTimeout}秒）- 耗時: ${stopwatch.elapsedMilliseconds}ms');
        },
      );

      stopwatch.stop();
      final elapsedSeconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

      if (result.trim().isNotEmpty) {
        await _addTranscriptionRecord(result.trim());
        _showTranscriptionSuccessMessage(result.trim(), elapsedSeconds);
      }

    } catch (e) {
      stopwatch.stop();
      final elapsedSeconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);
      print('轉錄失敗: $e (耗時: ${elapsedSeconds}s)');
      _showMessage('轉錄失敗', MessageType.error);
    } finally {
      setState(() {
        _isTranscribing = false;
      });
    }
  }

  // ============ 筆記管理方法 ============
  
  Future<void> _loadTranscriptionRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recordsJson = prefs.getString(AppConstants.recordsKey);
      
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
      await prefs.setString(AppConstants.recordsKey, recordsJson);
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
      _transcriptionRecords.insert(0, newRecord);
    });

    await _saveTranscriptionRecords();
  }

  Future<void> _editTranscriptionRecord(int index, String newText) async {
    if (index >= 0 && index < _transcriptionRecords.length) {
      setState(() {
        _transcriptionRecords[index].text = newText;
      });
      await _saveTranscriptionRecords();
      _showMessage('記錄已更新', MessageType.success);
    }
  }

  Future<void> _deleteTranscriptionRecord(int index) async {
    if (index >= 0 && index < _transcriptionRecords.length) {
      setState(() {
        _transcriptionRecords.removeAt(index);
      });
      await _saveTranscriptionRecords();
      _showMessage('記錄已刪除', MessageType.success);
    }
  }

  Future<void> _toggleImportance(TranscriptionRecord record) async {
    setState(() {
      record.isImportant = !record.isImportant;
    });
    await _saveTranscriptionRecords();
    _showMessage(record.isImportant ? '已標記為重要' : '已取消重要標記', MessageType.success);
  }

  // ============ UI 相關方法 ============
  
  void _showRecordDetail(TranscriptionRecord record) {
    setState(() {
      _selectedRecord = record;
      _showDetailView = true;
    });
  }

  void _closeDetailView() {
    setState(() {
      _showDetailView = false;
      _selectedRecord = null;
    });
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
              onPressed: () => Navigator.of(context).pop(),
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
              onPressed: () => Navigator.of(context).pop(),
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

  // ============ 消息顯示方法 ============
  
  void _showMessage(String message, MessageType type) {
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case MessageType.success:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case MessageType.error:
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case MessageType.info:
        backgroundColor = Colors.blue;
        icon = Icons.info;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _showTranscriptionSuccessMessage(String result, String elapsedSeconds) {
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
                  Text('轉錄完成！', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 4),
              Text('內容: $result', style: TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('耗時: ${elapsedSeconds}s', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============ 工具方法 ============
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // ============ UI 組件構建方法 ============
  
  Widget _buildModelDropdown() {
    return Container(
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
                  await _saveSelectedModel();
                  await _loadModel();
                }
              },
      ),
    );
  }

  Widget _buildModelLoadingIndicator() {
    if (!_isModelLoading) return SizedBox.shrink();
    
    return Container(
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
          ),
          SizedBox(width: 12),
          Text(
            '正在載入 ${_modelOptions[_selectedModel]}...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    if (!_isRecording) return SizedBox.shrink();
    
    return Container(
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isModelLoaded && !_isRecording && !_isTranscribing ? _startRecording : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            icon: Icon(Icons.mic, size: 18),
            label: Text(AppConstants.recordIdea, style: TextStyle(fontSize: 13)),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isRecording || (_hasRecording && !_isTranscribing)
                ? _isRecording ? _stopRecording : _transcribeAudio
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.grey : _isTranscribing ? Colors.orange : Colors.blue,
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            icon: Icon(_isRecording ? Icons.stop : _isTranscribing ? Icons.hourglass_empty : Icons.text_fields, size: 18),
            label: Text(
              _isRecording ? AppConstants.stopAndTranscribe : _isTranscribing ? AppConstants.transcribing : AppConstants.retranscribe,
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _hasRecording && !_isRecording && !_isTranscribing ? _playRecording : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPlaying ? Colors.orange : Colors.green,
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
            label: Text(
              _isPlaying ? AppConstants.stopPlaying : AppConstants.playRecording,
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesList() {
    if (_transcriptionRecords.isEmpty) return SizedBox.shrink();
    
    return Expanded(
      child: Container(
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
            _buildNotesHeader(),
            Expanded(child: _buildNotesListView()),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesHeader() {
    return Container(
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
            '${AppConstants.flashNotes} (${_transcriptionRecords.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
          ),
          Spacer(),
          Text(
            AppConstants.clickForDetail,
            style: TextStyle(fontSize: 12, color: Colors.amber.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesListView() {
    return ListView.builder(
      itemCount: _transcriptionRecords.length,
      itemBuilder: (context, index) {
        final record = _transcriptionRecords[index];
        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.amber.withOpacity(0.2), width: 0.5),
            ),
          ),
          child: ListTile(
            dense: true,
            onTap: () => _showRecordDetail(record),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade700),
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
                  Icon(Icons.star, size: 20, color: Colors.red.shade600),
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
                  icon: Icon(Icons.edit, size: AppConstants.iconSize, color: Colors.blue),
                  onPressed: () => _showEditDialog(index),
                  tooltip: '編輯',
                  padding: EdgeInsets.all(4),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: AppConstants.iconSize, color: Colors.red),
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
    );
  }

  Widget _buildDetailView() {
    if (!_showDetailView || _selectedRecord == null) return SizedBox.shrink();
    
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.blue.withOpacity(0.02),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        AppConstants.noteDetail,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                      SizedBox(width: 12),
                      InkWell(
                        onTap: () => _toggleImportance(_selectedRecord!),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedRecord!.isImportant ? Colors.red.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selectedRecord!.isImportant ? Colors.red.shade300 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedRecord!.isImportant ? Icons.star : Icons.star_outline,
                                size: 16,
                                color: _selectedRecord!.isImportant ? Colors.red.shade600 : Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _selectedRecord!.isImportant ? AppConstants.important : AppConstants.mark,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRecord!.isImportant ? Colors.red.shade600 : Colors.grey.shade600,
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
                          _showMessage('已複製到剪貼簿', MessageType.success);
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _selectedRecord!.text,
                      style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey.shade800),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_selectedRecord!.timestamp.year}/${_selectedRecord!.timestamp.month.toString().padLeft(2, '0')}/${_selectedRecord!.timestamp.day.toString().padLeft(2, '0')} ${_selectedRecord!.timestamp.hour.toString().padLeft(2, '0')}:${_selectedRecord!.timestamp.minute.toString().padLeft(2, '0')}:${_selectedRecord!.timestamp.second.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_showDetailView) return SizedBox.shrink();
    
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                _transcriptionRecords.isEmpty
                    ? _isModelLoaded 
                      ? '點擊錄製想法來創建你的第一個快閃筆記！' 
                      : '正在載入 Whisper 模型，請稍候...'
                    : '點擊上方的快閃筆記來查看詳細內容',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
              ),
              if (_transcriptionRecords.isEmpty && _isModelLoaded) ...[
                SizedBox(height: 16),
                Text(
                  '💡 靈感稍縱即逝，用語音快速記錄你的想法！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.amber.shade600, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.mic, color: Colors.deepPurple, size: 28),
            SizedBox(width: 8),
            Text(AppConstants.appTitle),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [_buildModelDropdown()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModelLoadingIndicator(),
              if (_isModelLoading) SizedBox(height: 12),
              _buildRecordingIndicator(),
              if (_isRecording || _isModelLoading) SizedBox(height: 12),
              _buildControlButtons(),
              SizedBox(height: 12),
              _buildNotesList(),
              if (_transcriptionRecords.isNotEmpty && _showDetailView) SizedBox(height: 12),
              _buildDetailView(),
              _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }
} 