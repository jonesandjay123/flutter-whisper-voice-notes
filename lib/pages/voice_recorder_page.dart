import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderPage extends StatefulWidget {
  const VoiceRecorderPage({super.key});

  @override
  State<VoiceRecorderPage> createState() => _VoiceRecorderPageState();
}

class _VoiceRecorderPageState extends State<VoiceRecorderPage> {
  // 錄音器
  final AudioRecorder _audioRecorder = AudioRecorder();
  // 播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 狀態管理
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  String? _recordingPath;
  
  // 錄音時間
  Duration _recordingDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _initializeRecording();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeRecording() async {
    // 獲取固定的錄音檔案路徑
    final directory = await getApplicationDocumentsDirectory();
    _recordingPath = '${directory.path}/voice_recording.wav';
    
    // 檢查是否已有錄音檔案
    final file = File(_recordingPath!);
    setState(() {
      _hasRecording = file.existsSync();
    });
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
    if (!await _requestPermissions()) return;

    try {
      // 確保錄音器停止
      if (await _audioRecorder.hasPermission()) {
        // 配置錄音設定 - 直接輸出 WAV 格式
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            bitRate: 256000,
            numChannels: 1, // 單聲道
          ),
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
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
      await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });

      _showSuccessSnackBar('錄音完成！檔案已儲存到固定位置');
    } catch (e) {
      _showErrorSnackBar('停止錄音失敗: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      _showErrorSnackBar('沒有錄音檔案可播放');
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
        setState(() {
          _isPlaying = true;
        });

        // 監聽播放完成
        _audioPlayer.onPlayerComplete.listen((event) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語音錄音器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 錄音狀態指示器
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording 
                  ? Colors.red.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.grey,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.mic,
                size: 80,
                color: _isRecording ? Colors.red : Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            // 錄音時間顯示
            Text(
              _isRecording 
                ? '錄音中: ${_formatDuration(_recordingDuration)}'
                : _hasRecording 
                  ? '已有錄音檔案'
                  : '準備錄音',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            // 控制按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 錄音/停止按鈕
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isRecording ? Icons.stop : Icons.mic),
                      const SizedBox(width: 8),
                      Text(_isRecording ? '停止錄音' : '開始錄音'),
                    ],
                  ),
                ),

                // 播放按鈕
                ElevatedButton(
                  onPressed: _hasRecording && !_isRecording ? _playRecording : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying ? Colors.orange : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      const SizedBox(width: 8),
                      Text(_isPlaying ? '停止播放' : '播放錄音'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 檔案資訊
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '檔案資訊:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text('格式: WAV (16kHz, 單聲道)'),
                  Text('位置: 固定檔案路徑'),
                  Text('狀態: ${_hasRecording ? "有錄音檔案" : "無錄音檔案"}'),
                  if (_recordingPath != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '路徑: $_recordingPath',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 提示訊息
            const Text(
              '💡 每次錄音都會覆蓋上一次的檔案\n錄音檔案會以 WAV 格式儲存，適合語音識別',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 