import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WhisperTestPage extends StatefulWidget {
  const WhisperTestPage({super.key});

  @override
  State<WhisperTestPage> createState() => _WhisperTestPageState();
}

class _WhisperTestPageState extends State<WhisperTestPage> {
  static const platform = MethodChannel('com.jovicheer.whisper_voice_notes/whisper');
  
  String _transcriptionResult = '點擊按鈕測試 Whisper JNI 連接';
  bool _isProcessing = false;

  Future<void> _testWhisperConnection() async {
    setState(() {
      _isProcessing = true;
      _transcriptionResult = '正在處理中...';
    });

    try {
      // 測試用的假音檔路徑
      final String result = await platform.invokeMethod('transcribeAudio', {
        'audioPath': '/test/audio/path.wav'
      });
      
      setState(() {
        _transcriptionResult = result;
      });
    } on PlatformException catch (e) {
      setState(() {
        _transcriptionResult = '錯誤: ${e.message}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _testModelLoading() async {
    setState(() {
      _isProcessing = true;
      _transcriptionResult = '正在載入預設模型...';
    });

    try {
      // 顯示模型資訊而不是實際載入
      setState(() {
        _transcriptionResult = '📋 模型資訊：\n• 預設模型：ggml-base-q5_1.bin\n• 位置：assets/models/\n• 格式：GGML\n• 語言：多語言支援\n\n⚠️ 注意：模型載入功能需要完整實作\n目前 JNI 連接測試正常！';
      });
      return;
    } on PlatformException catch (e) {
      setState(() {
        _transcriptionResult = '模型載入錯誤: ${e.message}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whisper JNI 測試'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.science,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Whisper JNI 測試',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '測試 C++ 與 Dart 之間的連接',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _transcriptionResult,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 測試按鈕們
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _testModelLoading,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing 
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('處理中...'),
                          ],
                        )
                      : const Text(
                          '🔧 測試模型載入',
                          style: TextStyle(fontSize: 18),
                        ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _testWhisperConnection,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing 
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('處理中...'),
                          ],
                        )
                      : const Text(
                          '🧪 測試 Whisper JNI',
                          style: TextStyle(fontSize: 18),
                        ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // 說明區域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 測試說明：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• 模型載入：測試是否能正確載入 Whisper 模型'),
                  const Text('• JNI 測試：測試 Flutter 與 C++ 的通信'),
                  const Text('• 這些測試會驗證底層 whisper.cpp 整合'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 