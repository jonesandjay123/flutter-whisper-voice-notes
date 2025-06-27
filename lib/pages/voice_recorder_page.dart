import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:async';

class VoiceRecorderPage extends StatefulWidget {
  const VoiceRecorderPage({super.key});

  @override
  State<VoiceRecorderPage> createState() => _VoiceRecorderPageState();
}

class _VoiceRecorderPageState extends State<VoiceRecorderPage> {
  static const platform = MethodChannel('whisper_voice_notes');
  
  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isTranscribing = false;
  bool _hasTranscription = false;
  String _transcriptionResult = '';
  String _recordingPath = '';
  String _systemInfo = '';
  int? _whisperContextPtr;
  Duration _recordingDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _initializeRecording();
    _getSystemInfo();
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
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
      _transcriptionResult = '正在載入模型...';
    });

    try {
      // 獲取應用程式目錄
      final directory = await getApplicationDocumentsDirectory();

      // 模型檔案路徑
      final modelPath = '${directory.path}/ggml-tiny-q5_1.bin';
      final modelFile = File(modelPath);

      // 如果模型不存在，從 assets 複製
      if (!await modelFile.exists()) {
        setState(() {
          _transcriptionResult = '正在複製 Tiny 模型檔案（更快速）...';
        });
        
        await platform.invokeMethod('copyAssetToFile', {
          'assetName': 'models/ggml-tiny-q5_1.bin',
          'targetPath': modelPath,
        });
        
        setState(() {
          _transcriptionResult = 'Tiny 模型檔案複製完成，正在載入...';
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
          _transcriptionResult = '模型載入成功！可以開始錄音了。';
        });
      } else {
        throw Exception('載入模型失敗：返回的 context pointer 無效');
      }
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _whisperContextPtr = null;
        _transcriptionResult = '載入模型失敗: $e';
      });
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
      // 確保錄音器停止
      if (await _audioRecorder!.hasPermission()) {
        // 配置錄音設定 - 直接輸出 WAV 格式
        await _audioRecorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            bitRate: 256000,
            numChannels: 1, // 單聲道
          ),
          path: _recordingPath,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
          _transcriptionResult = '正在錄音...';
        });

        _showSuccessSnackBar('開始錄音...');
        
        // 開始計時
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
        _transcriptionResult = '錄音完成，檔案已儲存';
      });

      _showSuccessSnackBar('錄音完成！檔案已儲存到固定位置');
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

        // 監聽播放完成
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
      setState(() {
        _transcriptionResult = '錯誤：沒有可轉錄的錄音檔案或模型未載入';
      });
      return;
    }

    // 開始計時
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isTranscribing = true;
      _transcriptionResult = '正在轉錄音頻...（使用 Tiny 模型）\n開始時間: ${DateTime.now().toString().substring(11, 19)}';
    });

    try {
      // 增加超時時間到 60 秒，並添加進度更新
      final String result = await platform.invokeMethod('transcribeAudio', {
        'contextPtr': _whisperContextPtr,
        'audioPath': _recordingPath,
        'threads': 6,
      }).timeout(
        Duration(seconds: 60), // 增加到 60 秒
        onTimeout: () {
          stopwatch.stop();
          throw Exception('轉錄超時（60秒）- 耗時: ${stopwatch.elapsedMilliseconds}ms');
        },
      );

      // 停止計時
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final elapsedSeconds = (elapsedMs / 1000).toStringAsFixed(2);

      setState(() {
        _transcriptionResult = '''
🎯 轉錄成功！

📝 結果: $result

⏱️ 性能統計:
• 總耗時: ${elapsedSeconds}s (${elapsedMs}ms)
• 速度: ${elapsedMs < 1000 ? '超快' : elapsedMs < 3000 ? '快速' : elapsedMs < 10000 ? '正常' : '較慢'}
• 完成時間: ${DateTime.now().toString().substring(11, 19)}

📊 音頻資訊:
• 檔案: ${_recordingPath.split('/').last}
• 使用模型: Tiny-Q5
• 執行緒數: 6
''';
        _hasTranscription = true;
      });

      // 顯示成功通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('轉錄完成！耗時 ${elapsedSeconds}s'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final elapsedSeconds = (elapsedMs / 1000).toStringAsFixed(2);

      setState(() {
        _transcriptionResult = '''
❌ 轉錄失敗

🔍 錯誤詳情: $e

⏱️ 失敗前耗時: ${elapsedSeconds}s (${elapsedMs}ms)

💡 建議:
1. 檢查錄音檔案是否正常
2. 嘗試重新載入模型
3. 錄製更短的音頻（3-5秒）
4. 確保手機性能充足

📊 除錯資訊:
• 檔案路徑: $_recordingPath
• 模型指標: $_whisperContextPtr
• 失敗時間: ${DateTime.now().toString().substring(11, 19)}
''';
        _hasTranscription = true;
      });

      // 顯示錯誤通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('轉錄失敗: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}'),
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

  void _copyTranscription() {
    if (_transcriptionResult.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _transcriptionResult));
      _showSuccessSnackBar('轉錄結果已複製到剪貼簿');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語音錄音與轉錄'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 系統資訊卡片
            Card(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '系統資訊',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _systemInfo.isNotEmpty ? _systemInfo : '載入中...',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // 模型載入按鈕
            ElevatedButton(
              onPressed: _isModelLoading ? null : _loadModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isModelLoaded ? Colors.green : Colors.orange,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _isModelLoading 
                  ? '載入中...' 
                  : _isModelLoaded 
                    ? '模型已載入 ✓' 
                    : '載入 Whisper 模型',
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 16),

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

            // 錄音控制按鈕
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isModelLoaded && !_isRecording && !_isTranscribing
                        ? _startRecording
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('開始錄音', style: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecording ? _stopRecording : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('停止錄音', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // 播放和轉錄按鈕
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasRecording && !_isRecording && !_isTranscribing
                        ? _playRecording
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlaying ? Colors.orange : Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _isPlaying ? '停止播放' : '播放錄音',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasRecording && !_isRecording && !_isTranscribing
                        ? _transcribeAudio
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _isTranscribing ? '轉錄中...' : '轉錄音頻',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // 結果顯示區域
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '轉錄結果',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_hasTranscription)
                          IconButton(
                            onPressed: _copyTranscription,
                            icon: Icon(Icons.copy),
                            tooltip: '複製到剪貼簿',
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _transcriptionResult.isEmpty 
                            ? '轉錄結果將顯示在這裡...' 
                            : _transcriptionResult,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 