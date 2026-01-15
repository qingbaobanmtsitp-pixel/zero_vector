import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

// ========================================
// 🔑 ここにOpenAI APIキーを入力してください！
// ========================================
// 1. https://platform.openai.com/api-keys にアクセス
// 2. 「Create new secret key」をクリック
// 3. 生成されたキーを下の '' の中にコピー＆ペースト
// 例: const String OPENAI_API_KEY = 'sk-proj-abc123...';
// ========================================

const String OPENAI_API_KEY = ''; // ← ここにAPIキーを入力！

// ========================================

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学習支援アプリ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// OpenAI APIサービスクラス
class OpenAIService {
  static const String baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<Map<String, dynamic>> analyzeProblemAndGenerateSimilar(
      String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final requestBody = {
        "model": "gpt-4o",
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": """この画像に写っている問題を解析して、以下のJSON形式で回答してください。

{
  "original_problem": "認識した問題文",
  "original_solution": "元の問題の詳しい解答と解説",
  "similar_problems": [
    {
      "title": "類題1のタイトル",
      "problem": "類題1の問題文",
      "solution": "類題1の詳しい解答",
      "explanation": "類題1の解法ステップ"
    },
    {
      "title": "類題2のタイトル",
      "problem": "類題2の問題文",
      "solution": "類題2の詳しい解答",
      "explanation": "類題2の解法ステップ"
    },
    {
      "title": "類題3のタイトル",
      "problem": "類題3の問題文",
      "solution": "類題3の詳しい解答",
      "explanation": "類題3の解法ステップ"
    }
  ]
}

重要：
- 類題は元の問題と同じ解法を使うが、数値や条件が異なるものを3つ生成してください
- 解答は詳しく、ステップバイステップで説明してください
- 日本語で回答してください
- JSON形式のみを返してください（他のテキストは含めないでください）"""
              },
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              }
            ]
          }
        ],
        "max_tokens": 4000,
        "temperature": 0.7
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = data['choices'][0]['message']['content'];

        String jsonText = text.trim();
        if (jsonText.contains('```json')) {
          jsonText = jsonText.split('```json')[1].split('```')[0].trim();
        } else if (jsonText.contains('```')) {
          jsonText = jsonText.split('```')[1].split('```')[0].trim();
        }

        final result = jsonDecode(jsonText);
        return result;
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('API Error: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('Error in analyzeProblemAndGenerateSimilar: $e');
      rethrow;
    }
  }
}

class AIMenuScreen extends StatelessWidget {
  const AIMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI学習支援'),
        backgroundColor: Colors.teal[400],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 100,
                  color: Colors.teal[300],
                ),
                const SizedBox(height: 30),
                const Text(
                  '問題を撮影して類題を生成',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'カメラで問題を撮影すると、AIが自動で類題を生成します',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AICameraScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'カメラを起動',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AICameraScreen extends StatefulWidget {
  const AICameraScreen({super.key});

  @override
  State<AICameraScreen> createState() => _AICameraScreenState();
}

class _AICameraScreenState extends State<AICameraScreen> {
  bool _isProcessing = false;
  String? _imagePath;

  Future<void> _takePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _imagePath = image.path;
        _isProcessing = true;
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AIAnalysisScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラエラー: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _imagePath = image.path;
        _isProcessing = true;
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AIAnalysisScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像選択エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題を撮影'),
        backgroundColor: Colors.teal[400],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal, width: 3),
              ),
              child: _imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.file(
                        File(_imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image,
                            size: 150,
                            color: Colors.grey[600],
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.camera_alt,
                      size: 150,
                      color: Colors.grey[600],
                    ),
            ),
            const SizedBox(height: 40),
            if (_isProcessing)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'AIが問題を解析中...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Text(
                    '問題が写るように撮影してください',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: const Icon(Icons.camera, size: 32),
                        label: const Text(
                          '撮影する',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library, size: 32),
                        label: const Text(
                          'ギャラリー',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AIAnalysisScreen extends StatefulWidget {
  final String imagePath;

  const AIAnalysisScreen({super.key, required this.imagePath});

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen> {
  bool _isAnalyzing = true;
  String? _analyzedProblem;
  String? _solution;
  List<Map<String, String>>? _similarProblems;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _analyzeProblem();
  }

  Future<void> _analyzeProblem() async {
    try {
      if (OPENAI_API_KEY.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = '⚠️ APIキーが設定されていません\n\n'
              '設定方法：\n'
              '1. プログラムファイル（main.dart）を開く\n'
              '2. 一番上の方にある\n'
              '   「const String OPENAI_API_KEY = \'\';」\n'
              '   を探す\n'
              '3. \'\' の中にAPIキーを入力\n'
              '   例: const String OPENAI_API_KEY = \'sk-proj-abc...\';\n\n'
              'APIキーの取得方法：\n'
              'https://platform.openai.com/api-keys\n'
              'にアクセスして「Create new secret key」をクリック';
        });
        return;
      }

      final result = await OpenAIService.analyzeProblemAndGenerateSimilar(
          widget.imagePath);

      if (mounted) {
        setState(() {
          _analyzedProblem = result['original_problem'];
          _solution = result['original_solution'];
          _similarProblems = (result['similar_problems'] as List)
              .map((p) => {
                    'title': p['title'].toString(),
                    'problem': p['problem'].toString(),
                    'solution': p['solution'].toString(),
                    'explanation': p['explanation']?.toString() ?? '',
                  })
              .toList();
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'エラーが発生しました：\n$e\n\n'
              '確認事項：\n'
              '✓ APIキーが正しく設定されているか\n'
              '✓ OpenAIアカウントに残高があるか\n'
              '✓ インターネット接続があるか\n'
              '✓ 画像が明瞭に問題を写しているか';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AI解析中'),
          backgroundColor: Colors.teal[400],
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
              SizedBox(height: 30),
              Text(
                'AIが問題を解析しています...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '解答と類題を生成中',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '※ 30秒〜1分程度かかる場合があります',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('エラー'),
          backgroundColor: Colors.red[400],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 30),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('戻る'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI解析結果'),
        backgroundColor: Colors.teal[400],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('撮影した画像', Icons.image, Colors.teal),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            _buildHeader('認識した問題', Icons.camera_alt, Colors.blue),
            const SizedBox(height: 10),
            _buildCard(_analyzedProblem ?? '', Colors.blue[50]!),
            const SizedBox(height: 30),
            _buildHeader('AI生成解答', Icons.check_circle, Colors.green),
            const SizedBox(height: 10),
            _buildCard(_solution ?? '', Colors.green[50]!),
            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 20),
            _buildHeader('AI生成類題', Icons.auto_awesome, Colors.orange),
            const SizedBox(height: 20),
            if (_similarProblems != null)
              ..._similarProblems!.asMap().entries.map((entry) {
                final index = entry.key;
                final problem = entry.value;
                final colors = [Colors.orange, Colors.purple, Colors.pink];
                final color = colors[index % colors.length];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(
                      problem['title']!,
                      Icons.lightbulb,
                      color,
                    ),
                    const SizedBox(height: 10),
                    _buildExpandableCard(
                      problem['problem']!,
                      problem['solution']!,
                      problem['explanation']!,
                      color[50]!,
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
                label: const Text('ホームに戻る'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('もう一度撮影'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String content, Color backgroundColor) {
    return Card(
      elevation: 4,
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          content,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
      ),
    );
  }

  Widget _buildExpandableCard(String problem, String solution,
      String explanation, Color backgroundColor) {
    return Card(
      elevation: 4,
      color: backgroundColor,
      child: ExpansionTile(
        title: const Text(
          '問題',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  problem,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                const Divider(height: 30),
                const Text(
                  '解答',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  solution,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                if (explanation.isNotEmpty) ...[
                  const Divider(height: 30),
                  const Text(
                    '解説',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    explanation,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final StudyDataManager _dataManager = StudyDataManager();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      PomodoroScreen(dataManager: _dataManager),
      StudyRecordScreen(dataManager: _dataManager),
      const MemoScreen(),
      const SubjectListScreen(),
      const AIMenuScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'ポモドーロ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '記録',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'メモ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: '問題集',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology),
            label: 'AI',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class StudyDataManager {
  final List<StudySession> _sessions = [];

  void addSession(int minutes) {
    _sessions.add(StudySession(
      dateTime: DateTime.now(),
      minutes: minutes,
    ));
  }

  Map<String, int> getTodayMinutes() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int total = 0;
    for (var session in _sessions) {
      final sessionDate = DateTime(
        session.dateTime.year,
        session.dateTime.month,
        session.dateTime.day,
      );
      if (sessionDate.isAtSameMomentAs(today)) {
        total += session.minutes;
      }
    }
    return {'today': total};
  }

  Map<String, int> getWeekMinutes() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    int total = 0;
    for (var session in _sessions) {
      if (session.dateTime.isAfter(weekStartDate)) {
        total += session.minutes;
      }
    }
    return {'week': total};
  }

  Map<String, int> getMonthMinutes() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    int total = 0;
    for (var session in _sessions) {
      if (session.dateTime.isAfter(monthStart)) {
        total += session.minutes;
      }
    }
    return {'month': total};
  }

  int getTotalMinutes() {
    return _sessions.fold(0, (sum, session) => sum + session.minutes);
  }

  List<DayData> getLast7DaysData() {
    final now = DateTime.now();
    final List<DayData> data = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int minutes = 0;
      for (var session in _sessions) {
        if (session.dateTime.isAfter(dayStart) &&
            session.dateTime.isBefore(dayEnd)) {
          minutes += session.minutes;
        }
      }

      data.add(DayData(
        date: dayStart,
        minutes: minutes,
      ));
    }

    return data;
  }
}

class StudySession {
  final DateTime dateTime;
  final int minutes;

  StudySession({required this.dateTime, required this.minutes});
}

class DayData {
  final DateTime date;
  final int minutes;

  DayData({required this.date, required this.minutes});
}

// カスタムタイマー機能を追加したPomodoroScreen

class PomodoroScreen extends StatefulWidget {
  final StudyDataManager dataManager;

  const PomodoroScreen({super.key, required this.dataManager});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  // デフォルト設定
  int _workMinutes = 25; // 作業時間（分）
  int _breakMinutes = 5; // 休憩時間（分）

  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;
  bool _isWorkTime = true;
  int _completedPomodoros = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _workMinutes * 60;
  }

  // 作業完了音を再生
  Future<void> _playWorkCompleteSound() async {
    try {
      await _audioPlayer.play(AssetSource('work_complete.mp3'));
    } catch (e) {
      print('作業完了音の再生エラー: $e');
    }
  }

  // 休憩完了音を再生
  Future<void> _playBreakCompleteSound() async {
    try {
      await _audioPlayer.play(AssetSource('break_complete.mp3'));
    } catch (e) {
      print('休憩完了音の再生エラー: $e');
    }
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;

          if (_isWorkTime) {
            // 作業時間完了
            widget.dataManager.addSession(_workMinutes);
            _completedPomodoros++;
            _remainingSeconds = _breakMinutes * 60;
            _isWorkTime = false;
            _playWorkCompleteSound();
            _showCompletionDialog(
              '作業時間完了！',
              '$_workMinutes分間の作業お疲れ様でした。\n$_breakMinutes分間の休憩を開始します。',
            );
          } else {
            // 休憩時間完了
            _remainingSeconds = _workMinutes * 60;
            _isWorkTime = true;
            _playBreakCompleteSound();
            _showCompletionDialog(
              '休憩時間完了！',
              '次の作業時間を開始できます。',
            );
          }
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isWorkTime = true;
      _remainingSeconds = _workMinutes * 60;
    });
  }

  void _showCompletionDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ⭐ 新機能：時間設定ダイアログ
  void _showTimerSettingsDialog() {
    int tempWorkMinutes = _workMinutes;
    int tempBreakMinutes = _breakMinutes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('タイマー時間設定'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 作業時間設定
                    const Text(
                      '作業時間',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 作業時間プリセット
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [15, 25, 30, 45, 60, 90].map((minutes) {
                        return ChoiceChip(
                          label: Text('${minutes}分'),
                          selected: tempWorkMinutes == minutes,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tempWorkMinutes = minutes;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // 作業時間カスタム入力
                    Row(
                      children: [
                        const Text('カスタム: '),
                        Expanded(
                          child: Slider(
                            value: tempWorkMinutes.toDouble(),
                            min: 1,
                            max: 120,
                            divisions: 119,
                            label: '$tempWorkMinutes分',
                            onChanged: (value) {
                              setDialogState(() {
                                tempWorkMinutes = value.toInt();
                              });
                            },
                          ),
                        ),
                        Text(
                          '$tempWorkMinutes分',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 30),

                    // 休憩時間設定
                    const Text(
                      '休憩時間',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 休憩時間プリセット
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [3, 5, 10, 15, 20].map((minutes) {
                        return ChoiceChip(
                          label: Text('${minutes}分'),
                          selected: tempBreakMinutes == minutes,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tempBreakMinutes = minutes;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // 休憩時間カスタム入力
                    Row(
                      children: [
                        const Text('カスタム: '),
                        Expanded(
                          child: Slider(
                            value: tempBreakMinutes.toDouble(),
                            min: 1,
                            max: 30,
                            divisions: 29,
                            label: '$tempBreakMinutes分',
                            onChanged: (value) {
                              setDialogState(() {
                                tempBreakMinutes = value.toInt();
                              });
                            },
                          ),
                        ),
                        Text(
                          '$tempBreakMinutes分',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // プリセット組み合わせ
                    const Text(
                      'おすすめ設定',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        ListTile(
                          title: const Text('ポモドーロ（標準）'),
                          subtitle: const Text('作業25分 / 休憩5分'),
                          leading: const Icon(Icons.timer),
                          onTap: () {
                            setDialogState(() {
                              tempWorkMinutes = 25;
                              tempBreakMinutes = 5;
                            });
                          },
                        ),
                        ListTile(
                          title: const Text('短時間集中'),
                          subtitle: const Text('作業15分 / 休憩3分'),
                          leading: const Icon(Icons.flash_on),
                          onTap: () {
                            setDialogState(() {
                              tempWorkMinutes = 15;
                              tempBreakMinutes = 3;
                            });
                          },
                        ),
                        ListTile(
                          title: const Text('長時間集中'),
                          subtitle: const Text('作業45分 / 休憩10分'),
                          leading: const Icon(Icons.access_time),
                          onTap: () {
                            setDialogState(() {
                              tempWorkMinutes = 45;
                              tempBreakMinutes = 10;
                            });
                          },
                        ),
                        ListTile(
                          title: const Text('深い集中'),
                          subtitle: const Text('作業90分 / 休憩20分'),
                          leading: const Icon(Icons.psychology),
                          onTap: () {
                            setDialogState(() {
                              tempWorkMinutes = 90;
                              tempBreakMinutes = 20;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _workMinutes = tempWorkMinutes;
                      _breakMinutes = tempBreakMinutes;

                      // タイマーをリセット
                      _timer?.cancel();
                      _isRunning = false;
                      _isWorkTime = true;
                      _remainingSeconds = _workMinutes * 60;
                    });
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '作業時間: $_workMinutes分、休憩時間: $_breakMinutes分に設定しました',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('設定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ポモドーロタイマー'),
        backgroundColor: Colors.red[400],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'タイマー時間設定',
            onPressed: _showTimerSettingsDialog,
          ),
        ],
      ),
      body: Center(
        // ← 中央揃え
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 現在のモード表示
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _isWorkTime ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isWorkTime ? Icons.work : Icons.coffee,
                      color: _isWorkTime ? Colors.red[700] : Colors.green[700],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isWorkTime ? '作業時間' : '休憩時間',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color:
                            _isWorkTime ? Colors.red[700] : Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 設定表示
              Text(
                '作業 $_workMinutes分 / 休憩 $_breakMinutes分',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // タイマー表示
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: _isWorkTime ? Colors.red[700] : Colors.green[700],
                ),
              ),
              const SizedBox(height: 60),

              // コントロールボタン
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  // 開始/一時停止ボタン
                  ElevatedButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isRunning ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        const SizedBox(width: 10),
                        Text(
                          _isRunning ? '一時停止' : '開始',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),

                  // リセットボタン
                  ElevatedButton(
                    onPressed: _resetTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 10),
                        Text(
                          'リセット',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),

              // 完了回数
              SizedBox(
                width: 200,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 40, color: Colors.green),
                        const SizedBox(height: 10),
                        const Text(
                          '完了回数',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$_completedPomodoros 回',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class StudyGoalManager {
  int goalMinutes = 0; // 目標時間（分）
  bool isGoalSet = false;
  bool goalAchieved = false;

  void setGoal(int minutes) {
    goalMinutes = minutes;
    isGoalSet = true;
    goalAchieved = false;
  }

  void clearGoal() {
    goalMinutes = 0;
    isGoalSet = false;
    goalAchieved = false;
  }

  bool checkGoalAchievement(int currentMinutes) {
    if (isGoalSet && !goalAchieved && currentMinutes >= goalMinutes) {
      goalAchieved = true;
      return true;
    }
    return false;
  }

  double getProgress(int currentMinutes) {
    if (!isGoalSet || goalMinutes == 0) return 0.0;
    return (currentMinutes / goalMinutes).clamp(0.0, 1.0);
  }
}

// StudyRecordScreen を拡張
class StudyRecordScreen extends StatefulWidget {
  final StudyDataManager dataManager;

  const StudyRecordScreen({super.key, required this.dataManager});

  @override
  State<StudyRecordScreen> createState() => _StudyRecordScreenState();
}

class _StudyRecordScreenState extends State<StudyRecordScreen> {
  final StudyGoalManager goalManager = StudyGoalManager();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _checkGoalAchievement();
  }

  void _checkGoalAchievement() {
    if (!mounted) return;

    final todayMinutes = widget.dataManager.getTodayMinutes()['today'] ?? 0;

    if (goalManager.checkGoalAchievement(todayMinutes)) {
      _playGoalAchievedSound();
      _showGoalAchievedDialog();
    }
  }

  Future<void> _playGoalAchievedSound() async {
    try {
      await _audioPlayer.play(AssetSource('goal_achieved.mp3'));
    } catch (e) {
      print('目標達成音の再生エラー: $e');
    }
  }

  void _showGoalAchievedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber[700], size: 32),
              const SizedBox(width: 10),
              const Text('目標達成！'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉 おめでとうございます！ 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '今日の目標 ${goalManager.goalMinutes} 分を達成しました！',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                '素晴らしい努力です！',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSetGoalDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('今日の目標時間を設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('目標勉強時間（分）を入力してください'),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '目標時間（分）',
                  hintText: '例: 180（3時間）',
                  border: OutlineInputBorder(),
                  suffixText: '分',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '※ 目標達成時に通知します',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text);
                if (minutes != null && minutes > 0) {
                  setState(() {
                    goalManager.setGoal(minutes);
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('目標時間を ${minutes} 分に設定しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('設定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayMinutes = widget.dataManager.getTodayMinutes()['today'] ?? 0;
    final weekMinutes = widget.dataManager.getWeekMinutes()['week'] ?? 0;
    final monthMinutes = widget.dataManager.getMonthMinutes()['month'] ?? 0;
    final totalMinutes = widget.dataManager.getTotalMinutes();
    final last7Days = widget.dataManager.getLast7DaysData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('勉強時間記録'),
        backgroundColor: Colors.blue[400],
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: '目標設定',
            onPressed: _showSetGoalDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 目標設定カード
              if (goalManager.isGoalSet) _buildGoalCard(todayMinutes),
              if (goalManager.isGoalSet) const SizedBox(height: 15),

              _buildRecordCard(
                '今日の勉強時間',
                todayMinutes,
                Colors.blue,
                Icons.today,
              ),
              const SizedBox(height: 15),
              _buildRecordCard(
                '今週の勉強時間',
                weekMinutes,
                Colors.green,
                Icons.calendar_view_week,
              ),
              const SizedBox(height: 15),
              _buildRecordCard(
                '今月の勉強時間',
                monthMinutes,
                Colors.orange,
                Icons.calendar_month,
              ),
              const SizedBox(height: 15),
              _buildRecordCard(
                '総勉強時間',
                totalMinutes,
                Colors.purple,
                Icons.emoji_events,
              ),
              const SizedBox(height: 30),
              const Text(
                '過去7日間の勉強時間',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildBarChart(last7Days),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(int currentMinutes) {
    final progress = goalManager.getProgress(currentMinutes);
    final remaining = goalManager.goalMinutes - currentMinutes;
    final isAchieved = goalManager.goalAchieved;

    return Card(
      elevation: 6,
      color: isAchieved ? Colors.amber[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isAchieved ? Icons.emoji_events : Icons.flag,
                      color: isAchieved ? Colors.amber[700] : Colors.blue[700],
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isAchieved ? '目標達成！' : '今日の目標',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            isAchieved ? Colors.amber[900] : Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      goalManager.clearGoal();
                    });
                  },
                  tooltip: '目標をクリア',
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              '目標: ${goalManager.goalMinutes} 分',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              '現在: $currentMinutes 分',
              style: const TextStyle(fontSize: 16),
            ),
            if (!isAchieved) ...[
              const SizedBox(height: 5),
              Text(
                '残り: $remaining 分',
                style: TextStyle(
                  fontSize: 16,
                  color: remaining > 0 ? Colors.orange[700] : Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 20,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isAchieved ? Colors.amber : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% 達成',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
      String title, int minutes, Color color, IconData icon) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${hours}時間 ${mins}分',
                    style: TextStyle(
                      fontSize: 24,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<DayData> data) {
    final maxMinutes =
        data.fold<int>(0, (max, day) => day.minutes > max ? day.minutes : max);
    final maxHeight = 200.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: maxHeight + 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: data.map((dayData) {
                  final barHeight = maxMinutes > 0
                      ? (dayData.minutes / maxMinutes) * maxHeight
                      : 0.0;
                  final dayOfWeek = ['月', '火', '水', '木', '金', '土', '日'];
                  final weekday = dayOfWeek[(dayData.date.weekday - 1) % 7];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${dayData.minutes}分',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: barHeight < 10 ? 10 : barHeight,
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            weekday,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class MemoData {
  final String title;
  final String content;

  MemoData({required this.title, required this.content});
}

class _MemoScreenState extends State<MemoScreen> {
  final List<MemoData> _memos = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  void _showAddMemoDialog() {
    _titleController.clear();
    _contentController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('メモを追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '見出し',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: '本文',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_titleController.text.isNotEmpty ||
                    _contentController.text.isNotEmpty) {
                  setState(() {
                    _memos.add(MemoData(
                      title: _titleController.text.isEmpty
                          ? '無題'
                          : _titleController.text,
                      content: _contentController.text,
                    ));
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
  }

  void _deleteMemo(int index) {
    setState(() {
      _memos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ'),
        backgroundColor: Colors.green[400],
      ),
      body: _memos.isEmpty
          ? const Center(
              child: Text(
                'メモがありません\n右下のボタンから追加してください',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _memos.length,
              itemBuilder: (context, index) {
                final memo = _memos[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: ListTile(
                    title: Text(
                      memo.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      memo.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMemo(index),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(memo.title),
                            content: SingleChildScrollView(
                              child: Text(memo.content),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('閉じる'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemoDialog,
        backgroundColor: Colors.green[400],
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}

class SubjectListScreen extends StatefulWidget {
  const SubjectListScreen({super.key});

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  final Map<String, Map<String, List<String>>> subjects = {
    '数学': {
      '数I': ['数と式', '二次関数', '図形と計量', 'データの分析'],
      '数II': ['式と証明', '複素数と方程式', '図形と方程式', '三角関数', '指数関数・対数関数', '微分法・積分法'],
      '数III': ['極限', '微分法', '積分法'],
      '数A': ['場合の数と確率', '整数の性質', '図形の性質'],
      '数B': ['数列', 'ベクトル'],
      '数C': ['ベクトル', '平面上の曲線と複素数平面', '数学的な表現の工夫'],
    },
    '英語': {
      '英文法': ['時制', '受動態', '不定詞'],
    },
    '国語': {
      '現代文': ['評論'],
      '古文': ['文法'],
    },
    '理科': {
      '物理': ['力学'],
      '化学': ['理論化学'],
    },
    '社会': {
      '日本史': ['近代'],
      '世界史': ['近代革命'],
      '地理': ['地形'],
      '政治経済': ['政治制度'],
    },
  };

  void _onUnitTap(String subject, String subSubject, String unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProblemListScreen(
          subject: subject,
          subSubject: subSubject,
          unit: unit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集'),
        backgroundColor: Colors.purple[400],
      ),
      body: ListView(
        children: subjects.entries.map((entry) {
          return ExpansionTile(
            title: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: Icon(_getSubjectIcon(entry.key), color: Colors.purple),
            children: entry.value.entries.map((subEntry) {
              return ExpansionTile(
                title: Text(
                  subEntry.key,
                  style: const TextStyle(fontSize: 18),
                ),
                children: subEntry.value.map((unit) {
                  return ListTile(
                    title: Text(unit),
                    leading: const Icon(Icons.circle, size: 12),
                    contentPadding: const EdgeInsets.only(left: 72),
                    onTap: () => _onUnitTap(entry.key, subEntry.key, unit),
                  );
                }).toList(),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject) {
      case '数学':
        return Icons.calculate;
      case '英語':
        return Icons.language;
      case '国語':
        return Icons.menu_book;
      case '理科':
        return Icons.science;
      case '社会':
        return Icons.public;
      default:
        return Icons.school;
    }
  }
}

// 問題データを格納するMapを定義
final Map<String, List<Map<String, String>>> _problemsData = {
  // ==================== 数学I ====================
  '数学_数I_数と式': [
    {
      'title': '因数分解の基本',
      'problem': '次の式を因数分解せよ。\nx² + 5x + 6',
      'answer': 'x² + 5x + 6 = (x + 2)(x + 3)',
      'explanation': '【解法】和が5、積が6になる2数を探す\n2 + 3 = 5, 2 × 3 = 6',
    },
    {
      'title': '因数分解（たすきがけ）',
      'problem': '次の式を因数分解せよ。\n2x² + 7x + 3',
      'answer': '2x² + 7x + 3 = (2x + 1)(x + 3)',
      'explanation': '【たすきがけ】\n2 × 3 = 6, 1 × 1 = 1\n6 + 1 = 7 ✓',
    },
    {
      'title': '平方根の計算',
      'problem': '√72 を簡単にせよ。',
      'answer': '√72 = √(36×2) = 6√2',
      'explanation': '【平方根の簡単化】\n素因数分解して平方数を見つける',
    },
    {
      'title': '式の展開',
      'problem': '(x + 3)(x - 5) を展開せよ。',
      'answer': 'x² - 2x - 15',
      'explanation': '【展開】\nx² - 5x + 3x - 15 = x² - 2x - 15',
    },
    {
      'title': '絶対値を含む方程式',
      'problem': '|x - 2| = 5 を解け。',
      'answer': 'x = 7 または x = -3',
      'explanation': '【絶対値】\nx - 2 = 5 または x - 2 = -5',
    },
  ],
  '数学_数I_二次関数': [
    {
      'title': '二次関数の頂点',
      'problem': 'y = x² - 4x + 3 の頂点を求めよ。',
      'answer': '頂点: (2, -1)',
      'explanation': '【平方完成】\ny = (x - 2)² - 1',
    },
    {
      'title': '二次関数の最大値・最小値',
      'problem': 'y = -x² + 4x - 3 (-1 ≤ x ≤ 3) の最大値と最小値を求めよ。',
      'answer': '最大値: 1 (x=2)\n最小値: -8 (x=-1)',
      'explanation': '【解法】\ny = -(x-2)² + 1\n頂点(2,1)は定義域内',
    },
    {
      'title': '二次方程式の解の公式',
      'problem': '2x² - 3x - 2 = 0 を解け。',
      'answer': 'x = 2 または x = -1/2',
      'explanation': '【解の公式】\nx = (3 ± √25) / 4',
    },
    {
      'title': '判別式',
      'problem': 'x² + kx + 4 = 0 が実数解をもつkの範囲を求めよ。',
      'answer': 'k ≤ -4 または k ≥ 4',
      'explanation': '【判別式】\nD = k² - 16 ≥ 0',
    },
    {
      'title': '二次不等式',
      'problem': 'x² - 5x + 6 > 0 を解け。',
      'answer': 'x < 2 または x > 3',
      'explanation': '【因数分解】\n(x-2)(x-3) > 0',
    },
  ],
  '数学_数I_図形と計量': [
    {
      'title': '正弦定理',
      'problem': '△ABC で a=8, B=60°, C=45° のとき、bを求めよ。',
      'answer': 'b = 4√6',
      'explanation': '【正弦定理】\na/sinA = b/sinB',
    },
    {
      'title': '余弦定理',
      'problem': '△ABC で a=5, b=7, c=8 のとき、cosAを求めよ。',
      'answer': 'cosA = 11/14',
      'explanation': '【余弦定理】\na² = b² + c² - 2bc cosA',
    },
    {
      'title': '三角形の面積',
      'problem': '△ABC で b=6, c=8, A=60° のとき、面積を求めよ。',
      'answer': 'S = 12√3',
      'explanation': '【面積公式】\nS = (1/2)bc sinA',
    },
  ],
  '数学_数I_データの分析': [
    {
      'title': '平均値',
      'problem': 'データ 3, 5, 7, 8, 10, 12 の平均値を求めよ。',
      'answer': '平均値 = 7.5',
      'explanation': '合計45 ÷ 6 = 7.5',
    },
    {
      'title': '中央値',
      'problem': 'データ 3, 5, 7, 8, 10, 12 の中央値を求めよ。',
      'answer': '中央値 = 7.5',
      'explanation': '(7 + 8) / 2 = 7.5',
    },
    {
      'title': '分散と標準偏差',
      'problem': 'データ 2, 4, 6, 8, 10 の分散を求めよ。',
      'answer': '分散 = 8',
      'explanation': '平均6、偏差の2乗の平均',
    },
  ],

  // ==================== 数学II ====================
  '数学_数II_式と証明': [
    {
      'title': '二項定理',
      'problem': '(2x + 1)⁴ を展開せよ。',
      'answer': '16x⁴ + 32x³ + 24x² + 8x + 1',
      'explanation': '【二項定理】\n₄C₀, ₄C₁, ₄C₂, ₄C₃, ₄C₄を使用',
    },
    {
      'title': '恒等式',
      'problem': 'ax² + bx + c = 2x² - 3x + 1 が恒等式のとき、a, b, cを求めよ。',
      'answer': 'a = 2, b = -3, c = 1',
      'explanation': '【恒等式】係数を比較',
    },
    {
      'title': '剰余の定理',
      'problem': 'P(x) = x³ - 2x² + 3x - 4 を x - 2 で割った余りを求めよ。',
      'answer': '余り = 2',
      'explanation': '【剰余の定理】P(2) = 8 - 8 + 6 - 4 = 2',
    },
  ],
  '数学_数II_複素数と方程式': [
    {
      'title': '複素数の計算',
      'problem': '(2 + 3i)(1 - 2i) を計算せよ。',
      'answer': '8 - i',
      'explanation': '【展開】2 - 4i + 3i - 6i² = 2 - i + 6 = 8 - i',
    },
    {
      'title': '2次方程式の解',
      'problem': 'x² + 2x + 5 = 0 を解け。',
      'answer': 'x = -1 ± 2i',
      'explanation': '【解の公式】判別式 D = -16',
    },
    {
      'title': '解と係数の関係',
      'problem': '2次方程式 x² - 3x + 2 = 0 の2つの解をα, βとするとき、α + β, αβを求めよ。',
      'answer': 'α + β = 3, αβ = 2',
      'explanation': '【解と係数】α + β = -b/a, αβ = c/a',
    },
  ],
  '数学_数II_図形と方程式': [
    {
      'title': '2点間の距離',
      'problem': '2点 A(1, 2), B(4, 6) 間の距離を求めよ。',
      'answer': '距離 = 5',
      'explanation': '√[(4-1)² + (6-2)²] = √25 = 5',
    },
    {
      'title': '円の方程式',
      'problem': '中心が (2, -3) で半径が 5 の円の方程式を求めよ。',
      'answer': '(x - 2)² + (y + 3)² = 25',
      'explanation': '【円の方程式】(x - a)² + (y - b)² = r²',
    },
    {
      'title': '直線の方程式',
      'problem': '2点 (1, 2), (3, 6) を通る直線の方程式を求めよ。',
      'answer': 'y = 2x',
      'explanation': '【傾き】m = (6-2)/(3-1) = 2',
    },
  ],
  '数学_数II_三角関数': [
    {
      'title': '三角関数の値',
      'problem': 'sin 150° の値を求めよ。',
      'answer': 'sin 150° = 1/2',
      'explanation': '【単位円】150° = 180° - 30°',
    },
    {
      'title': '三角関数の合成',
      'problem': 'y = sin x + √3 cos x を合成せよ。',
      'answer': 'y = 2 sin(x + 60°)',
      'explanation': '【合成】r = √(1² + (√3)²) = 2',
    },
    {
      'title': '三角方程式',
      'problem': '2 sin x = √3 (0° ≤ x < 360°) を解け。',
      'answer': 'x = 60°, 120°',
      'explanation': 'sin x = √3/2',
    },
  ],
  '数学_数II_指数関数・対数関数': [
    {
      'title': '指数法則',
      'problem': '2³ × 2⁵ を計算せよ。',
      'answer': '2⁸ = 256',
      'explanation': '【指数法則】a^m × a^n = a^(m+n)',
    },
    {
      'title': '対数の計算',
      'problem': 'log₂ 8 + log₂ 4 を計算せよ。',
      'answer': 'log₂ 32 = 5',
      'explanation': '【対数法則】log a + log b = log(ab)',
    },
    {
      'title': '常用対数',
      'problem': 'log₁₀ 1000 を求めよ。',
      'answer': 'log₁₀ 1000 = 3',
      'explanation': '10³ = 1000',
    },
  ],
  '数学_数II_微分法・積分法': [
    {
      'title': '導関数の計算',
      'problem': 'f(x) = x³ - 2x² + 3x のとき、f\'(x)を求めよ。',
      'answer': 'f\'(x) = 3x² - 4x + 3',
      'explanation': '【微分】(x^n)\' = nx^(n-1)',
    },
    {
      'title': '接線の方程式',
      'problem': 'y = x² 上の点 (2, 4) における接線の方程式を求めよ。',
      'answer': 'y = 4x - 4',
      'explanation': '【導関数】y\' = 2x, (2,4)で傾き4',
    },
    {
      'title': '不定積分',
      'problem': '∫(3x² + 2x) dx を計算せよ。',
      'answer': 'x³ + x² + C',
      'explanation': '【積分】∫x^n dx = x^(n+1)/(n+1) + C',
    },
  ],

  // ==================== 数学III ====================
  '数学_数III_極限': [
    {
      'title': '数列の極限',
      'problem': 'lim[n→∞] (2n + 1)/(3n - 2) を求めよ。',
      'answer': '2/3',
      'explanation': '【極限】分子分母をnで割る',
    },
    {
      'title': '関数の極限',
      'problem': 'lim[x→2] (x² - 4)/(x - 2) を求めよ。',
      'answer': '4',
      'explanation': '【因数分解】(x+2)(x-2)/(x-2) = x+2',
    },
    {
      'title': '無限級数',
      'problem': '1 + 1/2 + 1/4 + 1/8 + ... の和を求めよ。',
      'answer': '2',
      'explanation': '【等比級数】初項1、公比1/2',
    },
  ],
  '数学_数III_微分法': [
    {
      'title': '合成関数の微分',
      'problem': 'y = (2x + 1)³ のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 6(2x + 1)²',
      'explanation': '【合成関数】(f(g(x)))\' = f\'(g(x))g\'(x)',
    },
    {
      'title': '積の微分',
      'problem': 'y = x² sin x のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 2x sin x + x² cos x',
      'explanation': '【積の微分】(uv)\' = u\'v + uv\'',
    },
    {
      'title': 'e^xの微分',
      'problem': 'y = e^(2x) のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 2e^(2x)',
      'explanation': '【指数関数】(e^(ax))\' = ae^(ax)',
    },
  ],
  '数学_数III_積分法': [
    {
      'title': '置換積分',
      'problem': '∫x(x² + 1)³ dx を計算せよ。',
      'answer': '(x² + 1)⁴/8 + C',
      'explanation': '【置換】u = x² + 1',
    },
    {
      'title': '部分積分',
      'problem': '∫x e^x dx を計算せよ。',
      'answer': 'xe^x - e^x + C',
      'explanation': '【部分積分】∫udv = uv - ∫vdu',
    },
    {
      'title': '定積分',
      'problem': '∫[0,1] x² dx を計算せよ。',
      'answer': '1/3',
      'explanation': '[x³/3][0,1] = 1/3',
    },
  ],

  // ==================== 数学A ====================
  '数学_数A_場合の数と確率': [
    {
      'title': '順列',
      'problem': '5人から3人を選んで1列に並べる方法は何通りか。',
      'answer': '60通り',
      'explanation': '【順列】₅P₃ = 5×4×3 = 60',
    },
    {
      'title': '組合せ',
      'problem': '7個から4個を選ぶ組合せは何通りか。',
      'answer': '35通り',
      'explanation': '【組合せ】₇C₄ = 7!/(4!3!) = 35',
    },
    {
      'title': '確率の基本',
      'problem': 'サイコロを1回投げて、偶数の目が出る確率を求めよ。',
      'answer': '1/2',
      'explanation': '偶数は2,4,6の3通り。3/6 = 1/2',
    },
    {
      'title': '独立試行',
      'problem': 'コインを3回投げて、表が2回出る確率を求めよ。',
      'answer': '3/8',
      'explanation': '₃C₂ × (1/2)³ = 3/8',
    },
  ],
  '数学_数A_整数の性質': [
    {
      'title': '最大公約数',
      'problem': '48と72の最大公約数を求めよ。',
      'answer': '24',
      'explanation': '【ユークリッドの互除法】',
    },
    {
      'title': '素因数分解',
      'problem': '360を素因数分解せよ。',
      'answer': '360 = 2³ × 3² × 5',
      'explanation': '360 = 8 × 9 × 5',
    },
    {
      'title': '1次不定方程式',
      'problem': '3x + 5y = 1 の整数解を求めよ。',
      'answer': 'x = 2, y = -1 (一例)',
      'explanation': '【拡張ユークリッド】',
    },
  ],
  '数学_数A_図形の性質': [
    {
      'title': '三角形の角の二等分線',
      'problem': '△ABC で AB=6, AC=9, BC=12 のとき、角Aの二等分線がBCを分ける比を求めよ。',
      'answer': '2:3',
      'explanation': '【角の二等分線定理】AB:AC = 6:9 = 2:3',
    },
    {
      'title': '円周角の定理',
      'problem': '円周上の点A,B,Cがあり、中心角∠AOB=80°のとき、円周角∠ACBを求めよ。',
      'answer': '40°',
      'explanation': '【円周角】中心角の半分',
    },
    {
      'title': 'メネラウスの定理',
      'problem': '△ABCで辺BC,CA,ABまたはその延長がそれぞれ点P,Q,Rと交わるとき、成り立つ関係式を書け。',
      'answer': '(BP/PC) × (CQ/QA) × (AR/RB) = 1',
      'explanation': '【メネラウスの定理】3辺の分点比の積',
    },
  ],

  // ==================== 数学B ====================
  '数学_数B_数列': [
    {
      'title': '等差数列',
      'problem': '初項3、公差4の等差数列の第10項を求めよ。',
      'answer': '39',
      'explanation': '【一般項】aₙ = a₁ + (n-1)d = 3 + 9×4 = 39',
    },
    {
      'title': '等比数列',
      'problem': '初項2、公比3の等比数列の第5項を求めよ。',
      'answer': '162',
      'explanation': '【一般項】aₙ = a₁ × r^(n-1) = 2 × 3⁴ = 162',
    },
    {
      'title': '等差数列の和',
      'problem': '1 + 3 + 5 + ... + 99 の和を求めよ。',
      'answer': '2500',
      'explanation': '【和】項数50、S = 50×(1+99)/2 = 2500',
    },
    {
      'title': '階差数列',
      'problem': '数列 1, 3, 6, 10, 15, ... の一般項を求めよ。',
      'answer': 'aₙ = n(n+1)/2',
      'explanation': '【階差数列】差が1,2,3,4,...',
    },
  ],
  '数学_数B_ベクトル': [
    {
      'title': 'ベクトルの内積',
      'problem': 'a = (2, 3), b = (4, -1) のとき、a·b を求めよ。',
      'answer': 'a·b = 5',
      'explanation': '【内積】2×4 + 3×(-1) = 8 - 3 = 5',
    },
    {
      'title': 'ベクトルの大きさ',
      'problem': 'a = (3, 4) のとき、|a| を求めよ。',
      'answer': '|a| = 5',
      'explanation': '【大きさ】√(3² + 4²) = √25 = 5',
    },
    {
      'title': 'ベクトルの平行条件',
      'problem': 'a = (2, 3), b = (4, k) が平行であるとき、kを求めよ。',
      'answer': 'k = 6',
      'explanation': '【平行】2:3 = 4:k より k = 6',
    },
    {
      'title': '位置ベクトル',
      'problem': '△OABで、M は AB を 2:1 に内分する点。OM をOA, OB で表せ。',
      'answer': 'OM = (2OB + OA)/3',
      'explanation': '【内分】m:n に内分 = (na + mb)/(m+n)',
    },
  ],

  // ==================== 数学C ====================
  '数学_数C_ベクトル': [
    {
      'title': '空間ベクトルの内積',
      'problem': 'a = (1, 2, 3), b = (2, -1, 4) のとき、a·b を求めよ。',
      'answer': 'a·b = 12',
      'explanation': '【内積】1×2 + 2×(-1) + 3×4 = 12',
    },
    {
      'title': '空間ベクトルの外積',
      'problem': 'a = (1, 0, 0), b = (0, 1, 0) のとき、a×b を求めよ。',
      'answer': 'a×b = (0, 0, 1)',
      'explanation': '【外積】右手系で垂直なベクトル',
    },
  ],
  '数学_数C_平面上の曲線と複素数平面': [
    {
      'title': '2次曲線（放物線）',
      'problem': 'y² = 8x の焦点の座標を求めよ。',
      'answer': '焦点: (2, 0)',
      'explanation': '【放物線】y² = 4px の焦点は (p, 0)',
    },
    {
      'title': '2次曲線（楕円）',
      'problem': 'x²/25 + y²/9 = 1 の焦点の座標を求めよ。',
      'answer': '焦点: (±4, 0)',
      'explanation': '【楕円】c = √(a² - b²) = √16 = 4',
    },
    {
      'title': '複素数平面',
      'problem': '複素数 z = 1 + i を極形式で表せ。',
      'answer': 'z = √2(cos 45° + i sin 45°)',
      'explanation': '【極形式】|z| = √2, arg z = 45°',
    },
  ],
  '数学_数C_数学的な表現の工夫': [
    {
      'title': '帰納法',
      'problem': '1 + 2 + ... + n = n(n+1)/2 を数学的帰納法で証明する手順を述べよ。',
      'answer': '(1) n=1で成立を確認\n(2) n=kで成立と仮定\n(3) n=k+1で成立を示す',
      'explanation': '【数学的帰納法】の3ステップ',
    },
  ],

  // ==================== 英語 ====================
  '英語_英文法_時制': [
    {
      'title': '現在完了形',
      'problem': 'I lost my key yesterday. を現在完了形に書き換えよ。',
      'answer': 'I have lost my key.',
      'explanation': '※yesterdayは現在完了形と使えないので省略',
    },
    {
      'title': '過去完了形',
      'problem': '「駅に着いたとき、電車は出発していた」を英訳せよ。',
      'answer': 'When I arrived at the station, the train had left.',
      'explanation': '【過去完了】had + 過去分詞',
    },
    {
      'title': '未来完了形',
      'problem': '「明日の今頃には読み終えているでしょう」を英訳せよ。',
      'answer': 'By this time tomorrow, I will have finished reading.',
      'explanation': '【未来完了】will have + 過去分詞',
    },
  ],
  '英語_英文法_受動態': [
    {
      'title': '受動態の基本',
      'problem': 'Mary wrote this letter. を受動態に書き換えよ。',
      'answer': 'This letter was written by Mary.',
      'explanation': '【受動態】be動詞 + 過去分詞',
    },
    {
      'title': '助動詞を含む受動態',
      'problem': 'You must finish this work. を受動態に書き換えよ。',
      'answer': 'This work must be finished.',
      'explanation': '【助動詞+受動態】助動詞 + be + 過去分詞',
    },
    {
      'title': 'by以外の前置詞',
      'problem': '「その知らせに驚いた」を英訳せよ。',
      'answer': 'I was surprised at the news.',
      'explanation': '【前置詞】be surprised at',
    },
  ],
  '英語_英文法_不定詞': [
    {
      'title': '不定詞の名詞的用法',
      'problem': '「英語を学ぶことは楽しい」を英訳せよ。',
      'answer': 'To learn English is fun.',
      'explanation': '【名詞的用法】to + 動詞 = 〜すること',
    },
    {
      'title': '不定詞の形容詞的用法',
      'problem': '「読む本が欲しい」を英訳せよ。',
      'answer': 'I want a book to read.',
      'explanation': '【形容詞的用法】名詞を後ろから修飾',
    },
    {
      'title': '不定詞の副詞的用法',
      'problem': '「英語を学ぶために来た」を英訳せよ。',
      'answer': 'I came to study English.',
      'explanation': '【副詞的用法】目的: 〜するために',
    },
  ],

  // ==================== 国語 ====================
  '国語_現代文_評論': [
    {
      'title': '接続詞',
      'problem': '「努力は大切だ。（　）、才能も必要である。」の空欄に入る接続詞は？',
      'answer': 'しかし / だが / けれども',
      'explanation': '【逆接】の接続詞',
    },
  ],
  '国語_古文_文法': [
    {
      'title': '助動詞「けり」',
      'problem': '「けり」の意味と活用を答えよ。',
      'answer': '【意味】過去・詠嘆\n【活用】ラ行変格活用',
      'explanation': '【接続】連用形',
    },
  ],

  // ==================== 理科 ====================
  '理科_物理_力学': [
    {
      'title': '等加速度運動',
      'problem': '静止していた物体が 2.0 m/s² で 5.0秒間運動した。\n(1) 速度 (2) 距離',
      'answer': '(1) v = 10 m/s\n(2) x = 25 m',
      'explanation': '【公式】v = at, x = (1/2)at²',
    },
  ],
  '理科_化学_理論化学': [
    {
      'title': 'モル濃度',
      'problem': 'NaOH 4.0g を 500mL に溶かした。モル濃度は？（分子量40）',
      'answer': 'C = 0.20 mol/L',
      'explanation': '【モル濃度】C = n/V',
    },
  ],

  // ==================== 社会 ====================
  '社会_日本史_近代': [
    {
      'title': '明治維新',
      'problem': '五箇条の御誓文の内容を3つ答えよ。',
      'answer': '1. 広く会議を開く\n2. 上下心を一にする\n3. 智識を世界に求める',
      'explanation': '【明治新政府の基本方針】',
    },
  ],
  '社会_世界史_近代革命': [
    {
      'title': 'フランス革命',
      'problem': '人権宣言の内容を答えよ。',
      'answer': '自由・平等・国民主権・所有権の不可侵',
      'explanation': '1789年発布',
    },
  ],
  '社会_地理_地形': [
    {
      'title': '地形図の読み取り',
      'problem': '2万5千分の1の地形図で4cmは実際何mか？',
      'answer': '1000m = 1km',
      'explanation': '4cm × 25000 = 100000cm',
    },
  ],
  '社会_政治経済_政治制度': [
    {
      'title': '三権分立',
      'problem': '三権とそれを担当する機関を答えよ。',
      'answer': '立法権→国会\n行政権→内閣\n司法権→裁判所',
      'explanation': '【三権分立】権力の分散',
    },
  ],
};

class ProblemListScreen extends StatelessWidget {
  final String subject;
  final String subSubject;
  final String unit;

  const ProblemListScreen({
    super.key,
    required this.subject,
    required this.subSubject,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final key = '${subject}_${subSubject}_${unit}';
    final problems = _problemsData[key] ?? [];

    if (problems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('$unit - 問題一覧'),
          backgroundColor: Colors.purple[400],
        ),
        body: const Center(
          child: Text(
            'この単元の問題はまだ登録されていません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$unit - 問題一覧'),
        backgroundColor: Colors.purple[400],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: problems.length,
        itemBuilder: (context, index) {
          final problem = problems[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple[400],
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                problem['title']!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                problem['problem']!.split('\n')[0],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProblemDetailScreen(
                      title: problem['title']!,
                      problem: problem['problem']!,
                      answer: problem['answer']!,
                      explanation: problem['explanation']!,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ProblemDetailScreen extends StatelessWidget {
  final String title;
  final String problem;
  final String answer;
  final String explanation;

  const ProblemDetailScreen({
    super.key,
    required this.title,
    required this.problem,
    required this.answer,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題詳細'),
        backgroundColor: Colors.purple[400],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 20),
            _buildSection('問題', problem, Icons.question_answer, Colors.blue),
            const SizedBox(height: 20),
            _buildSection('解答', answer, Icons.check_circle, Colors.green),
            const SizedBox(height: 20),
            _buildSection('解説', explanation, Icons.lightbulb, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      String sectionTitle, String content, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
