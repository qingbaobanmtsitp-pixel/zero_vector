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

const String OPENAI_API_KEY =
    '';
// ← ここにAPIキーを入力！

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
  final ProblemRecordManager _recordManager =
      ProblemRecordManager(); // ← 1つだけ宣言

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      PomodoroScreen(dataManager: _dataManager),
      StudyRecordScreen(dataManager: _dataManager),
      const MemoScreen(),
      SubjectListScreen(recordManager: _recordManager), // ← _recordManagerを使う
      ReviewMainScreen(recordManager: _recordManager), // ← 同じ_recordManagerを使う
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
        // ⭐ ここを変更！
        index: _selectedIndex, // ⭐ indexを指定
        children: _screens, // ⭐ childrenに全画面を渡す
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'ポモドーロ'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '記録'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'メモ'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '問題集'),
          BottomNavigationBarItem(icon: Icon(Icons.refresh), label: '復習'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[700],
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

// ==========================================
// 問題記録システム
// ==========================================

class ProblemAttempt {
  final String problemId;
  final String subject;
  final String subSubject;
  final String unit;
  final String problemTitle;
  final bool isCorrect;
  final DateTime attemptDate;

  ProblemAttempt({
    required this.problemId,
    required this.subject,
    required this.subSubject,
    required this.unit,
    required this.problemTitle,
    required this.isCorrect,
    required this.attemptDate,
  });
}

class ProblemRecordManager {
  final List<ProblemAttempt> _attempts = [];

  void recordAttempt({
    required String problemId,
    required String subject,
    required String subSubject,
    required String unit,
    required String problemTitle,
    required bool isCorrect,
  }) {
    _attempts.add(ProblemAttempt(
      problemId: problemId,
      subject: subject,
      subSubject: subSubject,
      unit: unit,
      problemTitle: problemTitle,
      isCorrect: isCorrect,
      attemptDate: DateTime.now(),
    ));
  }

  int getTotalAttempts() => _attempts.length;

  int getCorrectAttempts() => _attempts.where((a) => a.isCorrect).length;

  double getOverallAccuracy() {
    if (_attempts.isEmpty) return 0.0;
    return getCorrectAttempts() / getTotalAttempts();
  }

  Map<String, int> getIncorrectCount() {
    Map<String, int> counts = {};
    for (var attempt in _attempts) {
      if (!attempt.isCorrect) {
        counts[attempt.problemId] = (counts[attempt.problemId] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<ProblemAttempt> getReviewPriority() {
    Map<String, List<ProblemAttempt>> incorrectAttempts = {};
    for (var attempt in _attempts) {
      if (!attempt.isCorrect) {
        incorrectAttempts.putIfAbsent(attempt.problemId, () => []).add(attempt);
      }
    }
    var sorted = incorrectAttempts.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return sorted.map((e) => e.value.last).toList();
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

class _PomodoroScreenState extends State<PomodoroScreen>
    with AutomaticKeepAliveClientMixin {
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
  bool get wantKeepAlive => true;

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
    super.build(context); // ⭐ この行を追加
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
  final ProblemRecordManager recordManager; // ← 追加
  const SubjectListScreen({super.key, required this.recordManager}); // ← 変更

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
          recordManager: widget.recordManager,
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
// 問題データを格納するMapを定義
final Map<String, List<Map<String, String>>> _problemsData = {
  // ==================== 数学I ====================
  '数学_数I_数と式': [
    {
      'title': '因数分解の基本',
      'problem': '次の式を因数分解せよ。\nx² + 5x + 6',
      'answer': 'x² + 5x + 6 = (x + 2)(x + 3)',
      'explanation': '【解法】和が5、積が6になる2数を探す\n2 + 3 = 5, 2 × 3 = 6'
    },
    {
      'title': '因数分解（たすきがけ）',
      'problem': '次の式を因数分解せよ。\n2x² + 7x + 3',
      'answer': '2x² + 7x + 3 = (2x + 1)(x + 3)',
      'explanation': '【たすきがけ】\n2 × 3 = 6, 1 × 1 = 1\n6 + 1 = 7 ✓'
    },
    {
      'title': '平方根の計算',
      'problem': '√72 を簡単にせよ。',
      'answer': '√72 = √(36×2) = 6√2',
      'explanation': '【平方根の簡単化】\n素因数分解して平方数を見つける'
    },
    {
      'title': '式の展開',
      'problem': '(x + 3)(x - 5) を展開せよ。',
      'answer': 'x² - 2x - 15',
      'explanation': '【展開】\nx² - 5x + 3x - 15 = x² - 2x - 15'
    },
    {
      'title': '絶対値を含む方程式',
      'problem': '|x - 2| = 5 を解け。',
      'answer': 'x = 7 または x = -3',
      'explanation': '【絶対値】\nx - 2 = 5 または x - 2 = -5'
    },
    {
      'title': '有理化',
      'problem': '1/√3 を有理化せよ。',
      'answer': '√3/3',
      'explanation': '【有理化】\n分子分母に√3をかける'
    },
    {
      'title': '乗法公式',
      'problem': '(x + 2)² を展開せよ。',
      'answer': 'x² + 4x + 4',
      'explanation': '【公式】(a + b)² = a² + 2ab + b²'
    },
    {
      'title': '因数分解（差の平方）',
      'problem': 'x² - 9 を因数分解せよ。',
      'answer': '(x + 3)(x - 3)',
      'explanation': '【公式】a² - b² = (a + b)(a - b)'
    },
    {
      'title': '循環小数',
      'problem': '0.3̇ を分数で表せ。',
      'answer': '1/3',
      'explanation': '【循環小数】x = 0.333..., 10x = 3.333..., 9x = 3'
    },
    {
      'title': '連立方程式',
      'problem': 'x + y = 5, 2x - y = 1 を解け。',
      'answer': 'x = 2, y = 3',
      'explanation': '【加減法】2式を足して3x = 6'
    },
  ],

  '数学_数I_二次関数': [
    {
      'title': '二次関数の頂点',
      'problem': 'y = x² - 4x + 3 の頂点を求めよ。',
      'answer': '頂点: (2, -1)',
      'explanation': '【平方完成】\ny = (x - 2)² - 1'
    },
    {
      'title': '二次関数の最大値・最小値',
      'problem': 'y = -x² + 4x - 3 (-1 ≤ x ≤ 3) の最大値と最小値を求めよ。',
      'answer': '最大値: 1 (x=2)\n最小値: -8 (x=-1)',
      'explanation': '【解法】\ny = -(x-2)² + 1\n頂点(2,1)は定義域内'
    },
    {
      'title': '二次方程式の解の公式',
      'problem': '2x² - 3x - 2 = 0 を解け。',
      'answer': 'x = 2 または x = -1/2',
      'explanation': '【解の公式】\nx = (3 ± √25) / 4'
    },
    {
      'title': '判別式',
      'problem': 'x² + kx + 4 = 0 が実数解をもつkの範囲を求めよ。',
      'answer': 'k ≤ -4 または k ≥ 4',
      'explanation': '【判別式】\nD = k² - 16 ≥ 0'
    },
    {
      'title': '二次不等式',
      'problem': 'x² - 5x + 6 > 0 を解け。',
      'answer': 'x < 2 または x > 3',
      'explanation': '【因数分解】\n(x-2)(x-3) > 0'
    },
    {
      'title': '平方完成',
      'problem': 'y = x² + 6x + 5 を平方完成せよ。',
      'answer': 'y = (x + 3)² - 4',
      'explanation': '【平方完成】\nx² + 6x = (x + 3)² - 9'
    },
    {
      'title': 'グラフの平行移動',
      'problem': 'y = x² を x軸方向に2、y軸方向に-3 移動した式は？',
      'answer': 'y = (x - 2)² - 3',
      'explanation': '【平行移動】\ny = (x - p)² + q'
    },
    {
      'title': '二次関数と直線の共有点',
      'problem': 'y = x² と y = 2x - 1 の共有点の座標を求めよ。',
      'answer': '(1, 1)',
      'explanation': 'x² = 2x - 1\nx² - 2x + 1 = 0\n(x - 1)² = 0'
    },
    {
      'title': '軸と頂点',
      'problem': 'y = 2x² - 8x + 3 の軸と頂点を求めよ。',
      'answer': '軸: x = 2\n頂点: (2, -5)',
      'explanation': 'y = 2(x - 2)² - 5'
    },
    {
      'title': '二次方程式の解と係数',
      'problem': 'x² - 5x + 6 = 0 の2つの解をα, βとするとき、α + β, αβを求めよ。',
      'answer': 'α + β = 5, αβ = 6',
      'explanation': '【解と係数の関係】'
    },
  ],

  '数学_数I_図形と計量': [
    {
      'title': '正弦定理',
      'problem': '△ABC で a=8, B=60°, C=45° のとき、bを求めよ。',
      'answer': 'b = 4√6',
      'explanation': '【正弦定理】\na/sinA = b/sinB'
    },
    {
      'title': '余弦定理',
      'problem': '△ABC で a=5, b=7, c=8 のとき、cosAを求めよ。',
      'answer': 'cosA = 11/14',
      'explanation': '【余弦定理】\na² = b² + c² - 2bc cosA'
    },
    {
      'title': '三角形の面積',
      'problem': '△ABC で b=6, c=8, A=60° のとき、面積を求めよ。',
      'answer': 'S = 12√3',
      'explanation': '【面積公式】\nS = (1/2)bc sinA'
    },
    {
      'title': '三角比の値',
      'problem': 'sin 30°, cos 30°, tan 30° の値を求めよ。',
      'answer': 'sin 30° = 1/2\ncos 30° = √3/2\ntan 30° = 1/√3',
      'explanation': '【特別な角】30°-60°-90°'
    },
    {
      'title': '三角比の相互関係',
      'problem': 'sin θ = 3/5 のとき、cos θ を求めよ（0° < θ < 90°）。',
      'answer': 'cos θ = 4/5',
      'explanation': 'sin² θ + cos² θ = 1'
    },
    {
      'title': '内接円の半径',
      'problem': '△ABC で a=5, b=6, c=7 のとき、内接円の半径を求めよ。',
      'answer': 'r = √6',
      'explanation': 'S = rs (s = (a+b+c)/2)'
    },
    {
      'title': 'ヘロンの公式',
      'problem': '3辺が5, 6, 7の三角形の面積を求めよ。',
      'answer': 'S = 6√6',
      'explanation': '【ヘロン】s = 9\nS = √(s(s-a)(s-b)(s-c))'
    },
    {
      'title': '外接円の半径',
      'problem': '△ABC で a=6, A=60° のとき、外接円の半径を求めよ。',
      'answer': 'R = 2√3',
      'explanation': '【正弦定理】\na/sinA = 2R'
    },
    {
      'title': '三角形の成立条件',
      'problem': '3辺が2, 5, xの三角形が存在するxの範囲を求めよ。',
      'answer': '3 < x < 7',
      'explanation': '|a - b| < c < a + b'
    },
    {
      'title': '仰角・俯角',
      'problem': '地上から10m離れた地点から、高さhの建物の頂上を仰角30°で見た。hを求めよ。',
      'answer': 'h = 10√3/3 m',
      'explanation': 'tan 30° = h/10'
    },
  ],

  '数学_数I_データの分析': [
    {
      'title': '平均値',
      'problem': 'データ 3, 5, 7, 8, 10, 12 の平均値を求めよ。',
      'answer': '平均値 = 7.5',
      'explanation': '合計45 ÷ 6 = 7.5'
    },
    {
      'title': '中央値',
      'problem': 'データ 3, 5, 7, 8, 10, 12 の中央値を求めよ。',
      'answer': '中央値 = 7.5',
      'explanation': '(7 + 8) / 2 = 7.5'
    },
    {
      'title': '分散と標準偏差',
      'problem': 'データ 2, 4, 6, 8, 10 の分散を求めよ。',
      'answer': '分散 = 8',
      'explanation': '平均6、偏差の2乗の平均'
    },
    {
      'title': '最頻値',
      'problem': 'データ 1, 2, 2, 3, 3, 3, 4, 5 の最頻値を求めよ。',
      'answer': '最頻値 = 3',
      'explanation': '最も多く出現する値'
    },
    {
      'title': '範囲',
      'problem': 'データ 3, 7, 2, 9, 5 の範囲を求めよ。',
      'answer': '範囲 = 7',
      'explanation': '最大値 - 最小値 = 9 - 2'
    },
    {
      'title': '四分位数',
      'problem': 'データ 1, 3, 4, 6, 7, 8, 9 の第1四分位数を求めよ。',
      'answer': 'Q₁ = 3.5',
      'explanation': '下位25%の位置'
    },
    {
      'title': '標準偏差',
      'problem': 'データ 2, 4, 6, 8, 10 の標準偏差を求めよ。',
      'answer': '標準偏差 = 2√2',
      'explanation': '√分散 = √8'
    },
    {
      'title': '相関係数',
      'problem': '2つのデータの相関が完全に正の場合、相関係数は？',
      'answer': 'r = 1',
      'explanation': '相関係数は-1から1の範囲'
    },
    {
      'title': '箱ひげ図',
      'problem': '最小値2、Q₁=4、中央値6、Q₃=8、最大値10のとき、四分位範囲を求めよ。',
      'answer': '四分位範囲 = 4',
      'explanation': 'IQR = Q₃ - Q₁ = 8 - 4'
    },
    {
      'title': '外れ値',
      'problem': 'Q₁=10, Q₃=20のとき、外れ値の基準となる値を求めよ。',
      'answer': '下限: -5\n上限: 35',
      'explanation': 'Q₁ - 1.5×IQR, Q₃ + 1.5×IQR'
    },
  ],

  // ==================== 数学II ====================
  '数学_数II_式と証明': [
    {
      'title': '二項定理',
      'problem': '(2x + 1)⁴ を展開せよ。',
      'answer': '16x⁴ + 32x³ + 24x² + 8x + 1',
      'explanation': '【二項定理】\n₄C₀, ₄C₁, ₄C₂, ₄C₃, ₄C₄を使用'
    },
    {
      'title': '恒等式',
      'problem': 'ax² + bx + c = 2x² - 3x + 1 が恒等式のとき、a, b, cを求めよ。',
      'answer': 'a = 2, b = -3, c = 1',
      'explanation': '【恒等式】係数を比較'
    },
    {
      'title': '剰余の定理',
      'problem': 'P(x) = x³ - 2x² + 3x - 4 を x - 2 で割った余りを求めよ。',
      'answer': '余り = 2',
      'explanation': '【剰余の定理】P(2) = 8 - 8 + 6 - 4 = 2'
    },
    {
      'title': '因数定理',
      'problem': 'x³ - 3x² + 2x が x - 1 で割り切れることを示せ。',
      'answer': 'P(1) = 1 - 3 + 2 = 0より割り切れる',
      'explanation': '【因数定理】P(a) = 0 なら (x - a) で割り切れる'
    },
    {
      'title': '組立除法',
      'problem': 'x³ + 2x² - 5x + 2 を x - 1 で割ったときの商と余りを求めよ。',
      'answer': '商: x² + 3x - 2\n余り: 0',
      'explanation': '【組立除法】'
    },
    {
      'title': '等式の証明',
      'problem': 'a + b + c = 0 のとき、a³ + b³ + c³ = 3abc を証明せよ。',
      'answer': 'a³ + b³ + c³ - 3abc = (a+b+c)(a²+b²+c²-ab-bc-ca) = 0',
      'explanation': '【因数分解】'
    },
    {
      'title': '不等式の証明',
      'problem': 'a > 0, b > 0 のとき、(a + b)/2 ≥ √(ab) を証明せよ。',
      'answer': '(a + b)/2 - √(ab) = (√a - √b)²/2 ≥ 0',
      'explanation': '【相加相乗平均】'
    },
    {
      'title': '整式の割り算',
      'problem': '2x³ - 3x² + x - 5 を x² - 1 で割った商と余りを求めよ。',
      'answer': '商: 2x - 3\n余り: 3x - 8',
      'explanation': '【整式の除法】'
    },
    {
      'title': '分数式の計算',
      'problem': '1/(x-1) + 1/(x+1) を計算せよ。',
      'answer': '2x/(x² - 1)',
      'explanation': '通分して計算'
    },
    {
      'title': '二項係数',
      'problem': '₅C₂ の値を求めよ。',
      'answer': '₅C₂ = 10',
      'explanation': '5!/(2!3!) = 10'
    },
  ],

  '数学_数II_複素数と方程式': [
    {
      'title': '複素数の計算',
      'problem': '(2 + 3i)(1 - 2i) を計算せよ。',
      'answer': '8 - i',
      'explanation': '【展開】2 - 4i + 3i - 6i² = 2 - i + 6 = 8 - i'
    },
    {
      'title': '2次方程式の解',
      'problem': 'x² + 2x + 5 = 0 を解け。',
      'answer': 'x = -1 ± 2i',
      'explanation': '【解の公式】判別式 D = -16'
    },
    {
      'title': '解と係数の関係',
      'problem': '2次方程式 x² - 3x + 2 = 0 の2つの解をα, βとするとき、α + β, αβを求めよ。',
      'answer': 'α + β = 3, αβ = 2',
      'explanation': '【解と係数】α + β = -b/a, αβ = c/a'
    },
    {
      'title': '虚数単位',
      'problem': 'i⁴ の値を求めよ。',
      'answer': 'i⁴ = 1',
      'explanation': 'i² = -1, i⁴ = (i²)² = 1'
    },
    {
      'title': '複素数の共役',
      'problem': 'z = 3 + 4i のとき、z̄ と z·z̄ を求めよ。',
      'answer': 'z̄ = 3 - 4i\nz·z̄ = 25',
      'explanation': '|z|² = 9 + 16 = 25'
    },
    {
      'title': '複素数の絶対値',
      'problem': '|3 + 4i| を求めよ。',
      'answer': '|3 + 4i| = 5',
      'explanation': '√(3² + 4²) = √25 = 5'
    },
    {
      'title': '複素数の除法',
      'problem': '(3 + 2i)/(1 + i) を計算せよ。',
      'answer': '(5 + i)/2',
      'explanation': '分母を実数化：(3+2i)(1-i)/2'
    },
    {
      'title': '判別式と解の種類',
      'problem': 'x² + 2x + k = 0 が重解をもつkの値を求めよ。',
      'answer': 'k = 1',
      'explanation': 'D = 4 - 4k = 0'
    },
    {
      'title': '解と係数の応用',
      'problem': 'α, βが x² - 5x + 3 = 0 の解のとき、α² + β² を求めよ。',
      'answer': 'α² + β² = 19',
      'explanation': '(α + β)² - 2αβ = 25 - 6'
    },
    {
      'title': '高次方程式',
      'problem': 'x³ - 1 = 0 を解け。',
      'answer': 'x = 1, ω, ω²\n(ω = -1/2 + (√3/2)i)',
      'explanation': '【因数分解】(x-1)(x²+x+1)=0'
    },
  ],

  '数学_数II_図形と方程式': [
    {
      'title': '2点間の距離',
      'problem': '2点 A(1, 2), B(4, 6) 間の距離を求めよ。',
      'answer': '距離 = 5',
      'explanation': '√[(4-1)² + (6-2)²] = √25 = 5'
    },
    {
      'title': '円の方程式',
      'problem': '中心が (2, -3) で半径が 5 の円の方程式を求めよ。',
      'answer': '(x - 2)² + (y + 3)² = 25',
      'explanation': '【円の方程式】(x - a)² + (y - b)² = r²'
    },
    {
      'title': '直線の方程式',
      'problem': '2点 (1, 2), (3, 6) を通る直線の方程式を求めよ。',
      'answer': 'y = 2x',
      'explanation': '【傾き】m = (6-2)/(3-1) = 2'
    },
    {
      'title': '内分点',
      'problem': '線分ABをm:nに内分する点の座標公式を書け（A(x₁, y₁), B(x₂, y₂)）。',
      'answer': '((nx₁+mx₂)/(m+n), (ny₁+my₂)/(m+n))',
      'explanation': '【内分点の公式】'
    },
    {
      'title': '外分点',
      'problem': '2点A(1, 3), B(4, 9)をAB:BP = 2:1に外分する点Pを求めよ。',
      'answer': 'P(7, 15)',
      'explanation': '【外分点】x = (1×4-2×1)/(1-2)'
    },
    {
      'title': '点と直線の距離',
      'problem': '点(1, 2)と直線2x + y - 5 = 0 の距離を求めよ。',
      'answer': '距離 = √5/5',
      'explanation': '|2·1 + 2 - 5|/√(4+1) = 1/√5'
    },
    {
      'title': '円と直線の位置関係',
      'problem': '円x² + y² = 5と直線y = x + 1の位置関係を調べよ。',
      'answer': '接する',
      'explanation': '中心(0,0)と直線の距離 = √5/2 = √5'
    },
    {
      'title': '2円の位置関係',
      'problem': 'x² + y² = 4とx² + y² - 6x = 0の位置関係を調べよ。',
      'answer': '外接する',
      'explanation': '中心間距離 = 3 = r₁ + r₂'
    },
    {
      'title': '軌跡の方程式',
      'problem': '2点A(-1, 0), B(1, 0)からの距離の比が2:1である点の軌跡を求めよ。',
      'answer': '(x - 3)² + y² = 8',
      'explanation': '【アポロニウスの円】'
    },
    {
      'title': '領域',
      'problem': 'x + y ≤ 2, x ≥ 0, y ≥ 0 で囲まれた領域の面積を求めよ。',
      'answer': '面積 = 2',
      'explanation': '三角形の面積 = (1/2)×2×2'
    },
  ],

  '数学_数II_三角関数': [
    {
      'title': '三角関数の値',
      'problem': 'sin 150° の値を求めよ。',
      'answer': 'sin 150° = 1/2',
      'explanation': '【単位円】150° = 180° - 30°'
    },
    {
      'title': '三角関数の合成',
      'problem': 'y = sin x + √3 cos x を合成せよ。',
      'answer': 'y = 2 sin(x + 60°)',
      'explanation': '【合成】r = √(1² + (√3)²) = 2'
    },
    {
      'title': '三角方程式',
      'problem': '2 sin x = √3 (0° ≤ x < 360°) を解け。',
      'answer': 'x = 60°, 120°',
      'explanation': 'sin x = √3/2'
    },
    {
      'title': '加法定理',
      'problem': 'sin(α + β) の加法定理を書け。',
      'answer': 'sin(α + β) = sinα cosβ + cosα sinβ',
      'explanation': '【加法定理】'
    },
    {
      'title': '2倍角の公式',
      'problem': 'sin 2θ を sinθ, cosθ で表せ。',
      'answer': 'sin 2θ = 2 sinθ cosθ',
      'explanation': '【2倍角】'
    },
    {
      'title': '半角の公式',
      'problem': 'cos² θ を cos 2θ で表せ。',
      'answer': 'cos² θ = (1 + cos 2θ)/2',
      'explanation': '【半角の公式】'
    },
    {
      'title': '三角不等式',
      'problem': 'sin x > 1/2 (0° ≤ x < 360°) を解け。',
      'answer': '30° < x < 150°',
      'explanation': '【単位円】'
    },
    {
      'title': '三角関数の周期',
      'problem': 'y = sin 2x の周期を求めよ。',
      'answer': '周期 = π',
      'explanation': 'T = 2π/2 = π'
    },
    {
      'title': '三角関数の最大・最小',
      'problem': 'y = 3 sin x + 4 cos x の最大値と最小値を求めよ。',
      'answer': '最大値: 5\n最小値: -5',
      'explanation': '√(3² + 4²) = 5'
    },
    {
      'title': '逆三角関数',
      'problem': 'arcsin(1/2) の主値を求めよ。',
      'answer': 'π/6 (30°)',
      'explanation': '【逆三角関数】'
    },
  ],

  '数学_数II_指数関数・対数関数': [
    {
      'title': '指数法則',
      'problem': '2³ × 2⁵ を計算せよ。',
      'answer': '2⁸ = 256',
      'explanation': '【指数法則】a^m × a^n = a^(m+n)'
    },
    {
      'title': '対数の計算',
      'problem': 'log₂ 8 + log₂ 4 を計算せよ。',
      'answer': 'log₂ 32 = 5',
      'explanation': '【対数法則】log a + log b = log(ab)'
    },
    {
      'title': '常用対数',
      'problem': 'log₁₀ 1000 を求めよ。',
      'answer': 'log₁₀ 1000 = 3',
      'explanation': '10³ = 1000'
    },
    {
      'title': '指数方程式',
      'problem': '2ˣ = 8 を解け。',
      'answer': 'x = 3',
      'explanation': '2³ = 8'
    },
    {
      'title': '対数方程式',
      'problem': 'log₂ x = 3 を解け。',
      'answer': 'x = 8',
      'explanation': 'x = 2³ = 8'
    },
    {
      'title': '底の変換公式',
      'problem': 'log₂ 8 を log₁₀ で表せ。',
      'answer': 'log₂ 8 = log₁₀ 8 / log₁₀ 2',
      'explanation': '【底の変換】'
    },
    {
      'title': '指数不等式',
      'problem': '2ˣ > 16 を解け。',
      'answer': 'x > 4',
      'explanation': '2ˣ > 2⁴'
    },
    {
      'title': '対数不等式',
      'problem': 'log₂ x < 3 を解け。',
      'answer': '0 < x < 8',
      'explanation': 'x < 2³'
    },
    {
      'title': '対数の性質',
      'problem': 'log_a 1 の値を求めよ。',
      'answer': 'log_a 1 = 0',
      'explanation': 'a⁰ = 1'
    },
    {
      'title': '指数関数のグラフ',
      'problem': 'y = 2ˣ と y = (1/2)ˣ の関係は？',
      'answer': 'y軸に関して対称',
      'explanation': '(1/2)ˣ = 2⁻ˣ'
    },
  ],

  '数学_数II_微分法・積分法': [
    {
      'title': '導関数の計算',
      'problem': 'f(x) = x³ - 2x² + 3x のとき、f\'(x)を求めよ。',
      'answer': 'f\'(x) = 3x² - 4x + 3',
      'explanation': '【微分】(x^n)\' = nx^(n-1)'
    },
    {
      'title': '接線の方程式',
      'problem': 'y = x² 上の点 (2, 4) における接線の方程式を求めよ。',
      'answer': 'y = 4x - 4',
      'explanation': '【導関数】y\' = 2x, (2,4)で傾き4'
    },
    {
      'title': '不定積分',
      'problem': '∫(3x² + 2x) dx を計算せよ。',
      'answer': 'x³ + x² + C',
      'explanation': '【積分】∫x^n dx = x^(n+1)/(n+1) + C'
    },
    {
      'title': '定積分',
      'problem': '∫[0,2] x² dx を計算せよ。',
      'answer': '8/3',
      'explanation': '[x³/3]₀² = 8/3'
    },
    {
      'title': '接線の傾き',
      'problem': 'f(x) = x³ のとき、x = 2 における接線の傾きを求めよ。',
      'answer': '傾き = 12',
      'explanation': 'f\'(2) = 3×2² = 12'
    },
    {
      'title': '極値',
      'problem': 'y = x³ - 3x の極値を求めよ。',
      'answer': '極大値: 2 (x=-1)\n極小値: -2 (x=1)',
      'explanation': 'y\' = 3x² - 3 = 0'
    },
    {
      'title': '面積',
      'problem': 'y = x², x軸、x=0, x=2 で囲まれた図形の面積を求めよ。',
      'answer': '面積 = 8/3',
      'explanation': '∫[0,2] x² dx'
    },
    {
      'title': '増減表',
      'problem': 'y = x³ - 3x + 2 の増減を調べよ。',
      'answer': '減少: -1 < x < 1\n増加: x < -1, 1 < x',
      'explanation': 'y\' = 3x² - 3'
    },
    {
      'title': '最大・最小',
      'problem': 'y = x³ - 3x (-2 ≤ x ≤ 2) の最大値を求めよ。',
      'answer': '最大値: 4 (x=2)',
      'explanation': '端点と極値を比較'
    },
    {
      'title': '平均変化率',
      'problem': 'f(x) = x² の x=1 から x=3 までの平均変化率を求めよ。',
      'answer': '平均変化率 = 4',
      'explanation': '(f(3)-f(1))/(3-1) = 8/2'
    },
  ],

  // ==================== 数学III ====================
  '数学_数III_極限': [
    {
      'title': '数列の極限',
      'problem': 'lim[n→∞] (2n + 1)/(3n - 2) を求めよ。',
      'answer': '2/3',
      'explanation': '【極限】分子分母をnで割る'
    },
    {
      'title': '関数の極限',
      'problem': 'lim[x→2] (x² - 4)/(x - 2) を求めよ。',
      'answer': '4',
      'explanation': '【因数分解】(x+2)(x-2)/(x-2) = x+2'
    },
    {
      'title': '無限級数',
      'problem': '1 + 1/2 + 1/4 + 1/8 + ... の和を求めよ。',
      'answer': '2',
      'explanation': '【等比級数】初項1、公比1/2'
    },
    {
      'title': '極限の計算',
      'problem': 'lim[x→0] sin x / x を求めよ。',
      'answer': '1',
      'explanation': '【重要極限】'
    },
    {
      'title': '無限大の極限',
      'problem': 'lim[x→∞] (x² + 2x) / x² を求めよ。',
      'answer': '1',
      'explanation': 'x²で割って lim = 1 + 0'
    },
    {
      'title': '不定形の極限',
      'problem': 'lim[x→1] (x² - 1)/(x - 1) を求めよ。',
      'answer': '2',
      'explanation': '(x+1)(x-1)/(x-1) = x+1'
    },
    {
      'title': '右側極限と左側極限',
      'problem': 'lim[x→0+] 1/x と lim[x→0-] 1/x を求めよ。',
      'answer': '+∞, -∞',
      'explanation': '【片側極限】'
    },
    {
      'title': '無限等比級数',
      'problem': '∞Σ(n=1) (1/3)ⁿ を求めよ。',
      'answer': '1/2',
      'explanation': 'a/(1-r) = (1/3)/(1-1/3)'
    },
    {
      'title': 'はさみうちの原理',
      'problem': '-1/n ≤ sin n/n ≤ 1/n のとき、lim[n→∞] sin n/n を求めよ。',
      'answer': '0',
      'explanation': '【はさみうち】'
    },
    {
      'title': '連続性',
      'problem': 'f(x) = x² が x=2 で連続であることを示せ。',
      'answer': 'lim[x→2] f(x) = f(2) = 4',
      'explanation': '【連続の定義】'
    },
  ],

  '数学_数III_微分法': [
    {
      'title': '合成関数の微分',
      'problem': 'y = (2x + 1)³ のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 6(2x + 1)²',
      'explanation': '【合成関数】(f(g(x)))\' = f\'(g(x))g\'(x)'
    },
    {
      'title': '積の微分',
      'problem': 'y = x² sin x のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 2x sin x + x² cos x',
      'explanation': '【積の微分】(uv)\' = u\'v + uv\''
    },
    {
      'title': 'e^xの微分',
      'problem': 'y = e^(2x) のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 2e^(2x)',
      'explanation': '【指数関数】(e^(ax))\' = ae^(ax)'
    },
    {
      'title': '商の微分',
      'problem': 'y = (x² + 1)/(x - 1) のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = (x² - 2x - 1)/(x - 1)²',
      'explanation': '【商の微分】(u/v)\' = (u\'v - uv\')/v²'
    },
    {
      'title': '対数微分法',
      'problem': 'y = x^x のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = x^x (ln x + 1)',
      'explanation': '【対数微分】ln y = x ln x'
    },
    {
      'title': '逆関数の微分',
      'problem': 'y = arcsin x のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 1/√(1 - x²)',
      'explanation': '【逆三角関数】'
    },
    {
      'title': '高階導関数',
      'problem': 'f(x) = x³ のとき、f\'\'(x) を求めよ。',
      'answer': 'f\'\'(x) = 6x',
      'explanation': 'f\'(x) = 3x², f\'\'(x) = 6x'
    },
    {
      'title': '媒介変数表示の微分',
      'problem': 'x = t², y = t³ のとき、dy/dx を求めよ。',
      'answer': 'dy/dx = 3t/2',
      'explanation': 'dy/dx = (dy/dt)/(dx/dt)'
    },
    {
      'title': 'ロピタルの定理',
      'problem': 'lim[x→0] (e^x - 1)/x を求めよ。',
      'answer': '1',
      'explanation': '【ロピタル】分子分母を微分'
    },
    {
      'title': 'テイラー展開',
      'problem': 'e^x をx=0の周りでマクローリン展開せよ（3次まで）。',
      'answer': '1 + x + x²/2 + x³/6 + ...',
      'explanation': '【マクローリン展開】'
    },
  ],

  '数学_数III_積分法': [
    {
      'title': '置換積分',
      'problem': '∫x(x² + 1)³ dx を計算せよ。',
      'answer': '(x² + 1)⁴/8 + C',
      'explanation': '【置換】u = x² + 1'
    },
    {
      'title': '部分積分',
      'problem': '∫x e^x dx を計算せよ。',
      'answer': 'xe^x - e^x + C',
      'explanation': '【部分積分】∫udv = uv - ∫vdu'
    },
    {
      'title': '定積分',
      'problem': '∫[0,1] x² dx を計算せよ。',
      'answer': '1/3',
      'explanation': '[x³/3]₀¹ = 1/3'
    },
    {
      'title': '三角関数の積分',
      'problem': '∫sin x dx を計算せよ。',
      'answer': '-cos x + C',
      'explanation': '【積分】'
    },
    {
      'title': '分数関数の積分',
      'problem': '∫1/(x² + 1) dx を計算せよ。',
      'answer': 'arctan x + C',
      'explanation': '【逆三角関数】'
    },
    {
      'title': '区分求積法',
      'problem': 'lim[n→∞] (1/n)Σ(k=1,n) k²/n² を求めよ。',
      'answer': '1/3',
      'explanation': '∫[0,1] x² dx = 1/3'
    },
    {
      'title': '回転体の体積',
      'problem': 'y = x² (0 ≤ x ≤ 1) をx軸の周りに回転した立体の体積を求めよ。',
      'answer': 'V = π/5',
      'explanation': 'V = π∫[0,1] x⁴ dx'
    },
    {
      'title': '曲線の長さ',
      'problem': 'y = x² (0 ≤ x ≤ 1) の曲線の長さを求める積分式を書け。',
      'answer': 'L = ∫[0,1] √(1 + 4x²) dx',
      'explanation': '【弧長】L = ∫√(1 + (dy/dx)²) dx'
    },
    {
      'title': '広義積分',
      'problem': '∫[1,∞] 1/x² dx を計算せよ。',
      'answer': '1',
      'explanation': 'lim[t→∞] [-1/x]₁ᵗ = 1'
    },
    {
      'title': '面積（交点）',
      'problem': 'y = x² と y = 2x で囲まれた図形の面積を求めよ。',
      'answer': '4/3',
      'explanation': '∫[0,2] (2x - x²) dx'
    },
  ],

  // ==================== 数学A ====================
  '数学_数A_場合の数と確率': [
    {
      'title': '順列',
      'problem': '5人から3人を選んで1列に並べる方法は何通りか。',
      'answer': '60通り',
      'explanation': '【順列】₅P₃ = 5×4×3 = 60'
    },
    {
      'title': '組合せ',
      'problem': '7個から4個を選ぶ組合せは何通りか。',
      'answer': '35通り',
      'explanation': '【組合せ】₇C₄ = 7!/(4!3!) = 35'
    },
    {
      'title': '確率の基本',
      'problem': 'サイコロを1回投げて、偶数の目が出る確率を求めよ。',
      'answer': '1/2',
      'explanation': '偶数は2,4,6の3通り。3/6 = 1/2'
    },
    {
      'title': '独立試行',
      'problem': 'コインを3回投げて、表が2回出る確率を求めよ。',
      'answer': '3/8',
      'explanation': '₃C₂ × (1/2)³ = 3/8'
    },
    {
      'title': '円順列',
      'problem': '5人が円形のテーブルに座る座り方は何通りか。',
      'answer': '24通り',
      'explanation': '【円順列】(n-1)! = 4! = 24'
    },
    {
      'title': '重複順列',
      'problem': '3つの数字1,2,3から重複を許して3桁の数を作る方法は何通りか。',
      'answer': '27通り',
      'explanation': '3³ = 27'
    },
    {
      'title': '同じものを含む順列',
      'problem': 'BOOK の文字を並べる方法は何通りか。',
      'answer': '12通り',
      'explanation': '4!/2! = 12'
    },
    {
      'title': '条件付き確率',
      'problem': 'P(A∩B) = 0.3, P(A) = 0.5 のとき、P(B|A) を求めよ。',
      'answer': 'P(B|A) = 0.6',
      'explanation': 'P(B|A) = P(A∩B)/P(A)'
    },
    {
      'title': '余事象',
      'problem': 'サイコロを2回投げて、少なくとも1回は6が出る確率を求めよ。',
      'answer': '11/36',
      'explanation': '1 - (5/6)² = 11/36'
    },
    {
      'title': '反復試行',
      'problem': 'コインを5回投げて、表が3回出る確率を求めよ。',
      'answer': '5/16',
      'explanation': '₅C₃ × (1/2)⁵ = 10/32'
    },
  ],

  '数学_数A_整数の性質': [
    {
      'title': '最大公約数',
      'problem': '48と72の最大公約数を求めよ。',
      'answer': '24',
      'explanation': '【ユークリッドの互除法】'
    },
    {
      'title': '素因数分解',
      'problem': '360を素因数分解せよ。',
      'answer': '360 = 2³ × 3² × 5',
      'explanation': '360 = 8 × 9 × 5'
    },
    {
      'title': '1次不定方程式',
      'problem': '3x + 5y = 1 の整数解を求めよ。',
      'answer': 'x = 2, y = -1 (一例)',
      'explanation': '【拡張ユークリッド】'
    },
    {
      'title': '最小公倍数',
      'problem': '12と18の最小公倍数を求めよ。',
      'answer': '36',
      'explanation': 'lcm = 12×18/gcd = 216/6'
    },
    {
      'title': '約数の個数',
      'problem': '36の正の約数の個数を求めよ。',
      'answer': '9個',
      'explanation': '36 = 2²×3², (2+1)(2+1) = 9'
    },
    {
      'title': '合同式',
      'problem': '7 ≡ ? (mod 5) の?に入る最小の自然数は？',
      'answer': '2',
      'explanation': '7 = 5×1 + 2'
    },
    {
      'title': '剰余',
      'problem': '2¹⁰⁰ を 7 で割った余りを求めよ。',
      'answer': '2',
      'explanation': '2³ ≡ 1 (mod 7), 2¹⁰⁰ = (2³)³³×2'
    },
    {
      'title': 'n進法',
      'problem': '10進数の25を2進数で表せ。',
      'answer': '11001₍₂₎',
      'explanation': '25 = 16 + 8 + 1'
    },
    {
      'title': '倍数の判定',
      'problem': '123456は3で割り切れるか？',
      'answer': '割り切れる',
      'explanation': '各位の和 = 21, 3の倍数'
    },
    {
      'title': 'ベズーの等式',
      'problem': 'gcd(12, 18) = 6 のとき、12x + 18y = 6 を満たす整数x, yを求めよ。',
      'answer': 'x = 2, y = -1 (一例)',
      'explanation': '【ベズーの等式】'
    },
  ],

  '数学_数A_図形の性質': [
    {
      'title': '三角形の角の二等分線',
      'problem': '△ABC で AB=6, AC=9, BC=12 のとき、角Aの二等分線がBCを分ける比を求めよ。',
      'answer': '2:3',
      'explanation': '【角の二等分線定理】AB:AC = 6:9 = 2:3'
    },
    {
      'title': '円周角の定理',
      'problem': '円周上の点A,B,Cがあり、中心角∠AOB=80°のとき、円周角∠ACBを求めよ。',
      'answer': '40°',
      'explanation': '【円周角】中心角の半分'
    },
    {
      'title': 'メネラウスの定理',
      'problem': '△ABCで辺BC,CA,ABまたはその延長がそれぞれ点P,Q,Rと交わるとき、成り立つ関係式を書け。',
      'answer': '(BP/PC) × (CQ/QA) × (AR/RB) = 1',
      'explanation': '【メネラウスの定理】3辺の分点比の積'
    },
    {
      'title': 'チェバの定理',
      'problem': '△ABCで3つの線分AD, BE, CFが1点で交わるとき、成り立つ関係式を書け。',
      'answer': '(AF/FB) × (BD/DC) × (CE/EA) = 1',
      'explanation': '【チェバの定理】'
    },
    {
      'title': '方べきの定理',
      'problem': '円の外部の点Pから引いた2つの割線について、PA·PB = PC·PD が成り立つことを何というか。',
      'answer': '方べきの定理',
      'explanation': '【方べきの定理】'
    },
    {
      'title': '接弦定理',
      'problem': '円の接線と弦のなす角は何に等しいか。',
      'answer': 'その角に対する円周角に等しい',
      'explanation': '【接弦定理】'
    },
    {
      'title': '中線定理',
      'problem': '△ABCの辺BCの中点をMとするとき、AB² + AC² = 2(AM² + BM²) を何というか。',
      'answer': '中線定理（パップスの定理）',
      'explanation': '【中線定理】'
    },
    {
      'title': '内心',
      'problem': '三角形の内心から各辺までの距離は等しいか。',
      'answer': '等しい（内接円の半径）',
      'explanation': '【内心の性質】'
    },
    {
      'title': '外心',
      'problem': '三角形の外心から各頂点までの距離は等しいか。',
      'answer': '等しい（外接円の半径）',
      'explanation': '【外心の性質】'
    },
    {
      'title': '重心',
      'problem': '三角形の重心は各中線を何対何に内分するか。',
      'answer': '2:1に内分する',
      'explanation': '【重心の性質】'
    },
  ],

  // ==================== 数学B ====================
  '数学_数B_数列': [
    {
      'title': '等差数列',
      'problem': '初項3、公差4の等差数列の第10項を求めよ。',
      'answer': '39',
      'explanation': '【一般項】aₙ = a₁ + (n-1)d = 3 + 9×4 = 39'
    },
    {
      'title': '等比数列',
      'problem': '初項2、公比3の等比数列の第5項を求めよ。',
      'answer': '162',
      'explanation': '【一般項】aₙ = a₁ × r^(n-1) = 2 × 3⁴ = 162'
    },
    {
      'title': '等差数列の和',
      'problem': '1 + 3 + 5 + ... + 99 の和を求めよ。',
      'answer': '2500',
      'explanation': '【和】項数50、S = 50×(1+99)/2 = 2500'
    },
    {
      'title': '階差数列',
      'problem': '数列 1, 3, 6, 10, 15, ... の一般項を求めよ。',
      'answer': 'aₙ = n(n+1)/2',
      'explanation': '【階差数列】差が1,2,3,4,...'
    },
    {
      'title': '等比数列の和',
      'problem': '初項2、公比3の等比数列の初項から第5項までの和を求めよ。',
      'answer': '242',
      'explanation': 'S = 2(3⁵-1)/(3-1) = 242'
    },
    {
      'title': '漸化式',
      'problem': 'a₁ = 1, aₙ₊₁ = 2aₙ + 1 のとき、一般項を求めよ。',
      'answer': 'aₙ = 2ⁿ - 1',
      'explanation': '【特性方程式】'
    },
    {
      'title': '数列の極限',
      'problem': 'lim[n→∞] (3n + 2)/(n - 1) を求めよ。',
      'answer': '3',
      'explanation': '分子分母をnで割る'
    },
    {
      'title': '和の記号Σ',
      'problem': 'Σ(k=1,10) k² を計算せよ。',
      'answer': '385',
      'explanation': 'n(n+1)(2n+1)/6 = 10×11×21/6'
    },
    {
      'title': '群数列',
      'problem': '1|(2,3)|(4,5,6)|... で、20は第何群の何番目か。',
      'answer': '第6群の5番目',
      'explanation': '第n群の最後は n(n+1)/2'
    },
    {
      'title': '調和数列',
      'problem': '1, 1/2, 1/3, 1/4, ... の一般項を書け。',
      'answer': 'aₙ = 1/n',
      'explanation': '【調和数列】'
    },
  ],

  '数学_数B_ベクトル': [
    {
      'title': 'ベクトルの内積',
      'problem': 'a = (2, 3), b = (4, -1) のとき、a·b を求めよ。',
      'answer': 'a·b = 5',
      'explanation': '【内積】2×4 + 3×(-1) = 8 - 3 = 5'
    },
    {
      'title': 'ベクトルの大きさ',
      'problem': 'a = (3, 4) のとき、|a| を求めよ。',
      'answer': '|a| = 5',
      'explanation': '【大きさ】√(3² + 4²) = √25 = 5'
    },
    {
      'title': 'ベクトルの平行条件',
      'problem': 'a = (2, 3), b = (4, k) が平行であるとき、kを求めよ。',
      'answer': 'k = 6',
      'explanation': '【平行】2:3 = 4:k より k = 6'
    },
    {
      'title': '位置ベクトル',
      'problem': '△OABで、M は AB を 2:1 に内分する点。OM をOA, OB で表せ。',
      'answer': 'OM = (OA + 2OB)/3',
      'explanation': '【内分】m:n に内分 = (nb + ma)/(m+n)'
    },
    {
      'title': 'ベクトルの成分',
      'problem': 'a = (1, 2), b = (3, 4) のとき、2a - b を求めよ。',
      'answer': '2a - b = (-1, 0)',
      'explanation': '2(1,2) - (3,4) = (2,4) - (3,4)'
    },
    {
      'title': 'ベクトルの垂直条件',
      'problem': 'a = (2, 3), b = (k, -2) が垂直のとき、kを求めよ。',
      'answer': 'k = 3',
      'explanation': 'a·b = 0, 2k - 6 = 0'
    },
    {
      'title': '単位ベクトル',
      'problem': 'a = (3, 4) と同じ向きの単位ベクトルを求めよ。',
      'answer': '(3/5, 4/5)',
      'explanation': 'a/|a| = (3,4)/5'
    },
    {
      'title': 'ベクトルの分解',
      'problem': 'c = (5, 7) を a = (1, 0), b = (0, 1) で表せ。',
      'answer': 'c = 5a + 7b',
      'explanation': '【基本ベクトル】'
    },
    {
      'title': '内積と角度',
      'problem': 'a = (1, √3), b = (√3, 1) のなす角θを求めよ。',
      'answer': 'θ = 30°',
      'explanation': 'cos θ = (a·b)/(|a||b|) = √3/2'
    },
    {
      'title': '重心の位置ベクトル',
      'problem': '△ABCの重心Gを位置ベクトルで表せ。',
      'answer': 'OG = (OA + OB + OC)/3',
      'explanation': '【重心】'
    },
  ],

  // ==================== 数学C ====================
  '数学_数C_ベクトル': [
    {
      'title': '空間ベクトルの内積',
      'problem': 'a = (1, 2, 3), b = (2, -1, 4) のとき、a·b を求めよ。',
      'answer': 'a·b = 12',
      'explanation': '【内積】1×2 + 2×(-1) + 3×4 = 12'
    },
    {
      'title': '空間ベクトルの大きさ',
      'problem': 'a = (2, 3, 6) のとき、|a| を求めよ。',
      'answer': '|a| = 7',
      'explanation': '√(4 + 9 + 36) = √49 = 7'
    },
    {
      'title': '空間ベクトルの外積',
      'problem': 'a = (1, 0, 0), b = (0, 1, 0) のとき、a×b を求めよ。',
      'answer': 'a×b = (0, 0, 1)',
      'explanation': '【外積】右手系で垂直なベクトル'
    },
    {
      'title': '平面の方程式',
      'problem': '点(1,2,3)を通り、法線ベクトルが(2,3,4)の平面の方程式を求めよ。',
      'answer': '2x + 3y + 4z = 20',
      'explanation': '2(x-1) + 3(y-2) + 4(z-3) = 0'
    },
    {
      'title': '直線の方程式',
      'problem': '点(1,2,3)を通り、方向ベクトルが(1,1,1)の直線を媒介変数表示せよ。',
      'answer': 'x = 1+t, y = 2+t, z = 3+t',
      'explanation': '【媒介変数表示】'
    },
    {
      'title': '点と平面の距離',
      'problem': '点(1,1,1)と平面x + y + z = 6 の距離を求めよ。',
      'answer': '距離 = √3',
      'explanation': '|1+1+1-6|/√3 = 3/√3'
    },
    {
      'title': '空間の内分点',
      'problem': '2点A(1,2,3), B(4,5,6)を2:1に内分する点を求めよ。',
      'answer': '(3, 4, 5)',
      'explanation': '((2×4+1×1)/3, ...)'
    },
    {
      'title': '四面体の体積',
      'problem': 'OA=(1,0,0), OB=(0,1,0), OC=(0,0,1)のとき、四面体OABCの体積を求めよ。',
      'answer': 'V = 1/6',
      'explanation': 'V = |OA·(OB×OC)|/6'
    },
    {
      'title': '球面の方程式',
      'problem': '中心(1,2,3)、半径2の球面の方程式を求めよ。',
      'answer': '(x-1)² + (y-2)² + (z-3)² = 4',
      'explanation': '【球面の方程式】'
    },
    {
      'title': '空間での垂直条件',
      'problem': 'a = (1,2,3), b = (2,k,1)が垂直のとき、kを求めよ。',
      'answer': 'k = -5/2',
      'explanation': 'a·b = 0, 2 + 2k + 3 = 0'
    },
  ],

  '数学_数C_平面上の曲線と複素数平面': [
    {
      'title': '2次曲線（放物線）',
      'problem': 'y² = 8x の焦点の座標を求めよ。',
      'answer': '焦点: (2, 0)',
      'explanation': '【放物線】y² = 4px の焦点は (p, 0)'
    },
    {
      'title': '2次曲線（楕円）',
      'problem': 'x²/25 + y²/9 = 1 の焦点の座標を求めよ。',
      'answer': '焦点: (±4, 0)',
      'explanation': '【楕円】c = √(a² - b²) = √16 = 4'
    },
    {
      'title': '2次曲線（双曲線）',
      'problem': 'x²/9 - y²/16 = 1 の焦点を求めよ。',
      'answer': '焦点: (±5, 0)',
      'explanation': 'c = √(a² + b²) = √25 = 5'
    },
    {
      'title': '複素数平面',
      'problem': '複素数 z = 1 + i を極形式で表せ。',
      'answer': 'z = √2(cos 45° + i sin 45°)',
      'explanation': '【極形式】|z| = √2, arg z = 45°'
    },
    {
      'title': '複素数の積',
      'problem':
          'z₁ = 2(cos 30° + i sin 30°), z₂ = 3(cos 60° + i sin 60°) のとき、z₁z₂ を求めよ。',
      'answer': 'z₁z₂ = 6(cos 90° + i sin 90°) = 6i',
      'explanation': '【極形式の積】'
    },
    {
      'title': 'ド・モアブルの定理',
      'problem': '(cos 20° + i sin 20°)³ を計算せよ。',
      'answer': 'cos 60° + i sin 60° = 1/2 + (√3/2)i',
      'explanation': '【ド・モアブル】'
    },
    {
      'title': '複素数の回転',
      'problem': 'z = 1 + i を原点の周りに90°回転した点を求めよ。',
      'answer': 'iz = -1 + i',
      'explanation': 'iをかけると90°回転'
    },
    {
      'title': '媒介変数表示',
      'problem': 'x = 2cos t, y = 3sin t が表す曲線の方程式を求めよ。',
      'answer': 'x²/4 + y²/9 = 1',
      'explanation': '【楕円】cos²t + sin²t = 1'
    },
    {
      'title': '極座標',
      'problem': '直交座標(1, √3)を極座標で表せ。',
      'answer': '(2, 60°)',
      'explanation': 'r = 2, θ = 60°'
    },
    {
      'title': '複素数の絶対値と偏角',
      'problem': 'z = -1 + √3i の絶対値と偏角を求めよ。',
      'answer': '|z| = 2, arg z = 120°',
      'explanation': '【極形式】'
    },
  ],

  '数学_数C_数学的な表現の工夫': [
    {
      'title': '帰納法の手順',
      'problem': '1 + 2 + ... + n = n(n+1)/2 を数学的帰納法で証明する手順を述べよ。',
      'answer': '(1) n=1で成立を確認\n(2) n=kで成立と仮定\n(3) n=k+1で成立を示す',
      'explanation': '【数学的帰納法】の3ステップ'
    },
    {
      'title': '背理法',
      'problem': '√2が無理数であることを証明する方法は？',
      'answer': '背理法：√2が有理数と仮定して矛盾を導く',
      'explanation': '【背理法】'
    },
    {
      'title': '対偶による証明',
      'problem': '「n²が偶数ならnは偶数」の対偶を書け。',
      'answer': '「nが奇数ならn²は奇数」',
      'explanation': '【対偶】p→q の対偶は ¬q→¬p'
    },
    {
      'title': '必要条件・十分条件',
      'problem': '「x = 2」は「x² = 4」の何条件か。',
      'answer': '十分条件',
      'explanation': 'x=2 ⇒ x²=4 は真'
    },
    {
      'title': '同値変形',
      'problem': 'x² = 4 ⇔ x = ±2 は正しいか。',
      'answer': '正しい',
      'explanation': '【同値】両方向に成立'
    },
    {
      'title': '場合分け',
      'problem': '|x| = 2 を場合分けして解け。',
      'answer': 'x = 2 または x = -2',
      'explanation': 'x≥0とx<0で場合分け'
    },
    {
      'title': '存在と全称',
      'problem': '「すべてのxについてP(x)が成り立つ」の否定を書け。',
      'answer': '「あるxについてP(x)が成り立たない」',
      'explanation': '【量化子】∀の否定は∃'
    },
    {
      'title': '論理記号',
      'problem': '「AかつB」を記号で書け。',
      'answer': 'A ∧ B',
      'explanation': '【論理積】'
    },
    {
      'title': '逆・裏・対偶',
      'problem': '「p→q」の逆を書け。',
      'answer': 'q→p',
      'explanation': '【逆命題】'
    },
    {
      'title': '命題の真偽',
      'problem': '「x²>0ならx>0」は真か偽か。',
      'answer': '偽（反例：x=-1）',
      'explanation': '【反例】'
    },
  ],

  // ==================== 英語 ====================
  '英語_英文法_時制': [
    {
      'title': '現在完了形',
      'problem': 'I lost my key yesterday. を現在完了形に書き換えよ（yesterdayは削除）。',
      'answer': 'I have lost my key.',
      'explanation': '※yesterdayは現在完了形と使えないので省略'
    },
    {
      'title': '過去完了形',
      'problem': '「駅に着いたとき、電車は出発していた」を英訳せよ。',
      'answer': 'When I arrived at the station, the train had left.',
      'explanation': '【過去完了】had + 過去分詞'
    },
    {
      'title': '未来完了形',
      'problem': '「明日の今頃には読み終えているでしょう」を英訳せよ。',
      'answer': 'By this time tomorrow, I will have finished reading.',
      'explanation': '【未来完了】will have + 過去分詞'
    },
    {
      'title': '現在進行形',
      'problem': '「私は今勉強しています」を英訳せよ。',
      'answer': 'I am studying now.',
      'explanation': 'be + -ing形'
    },
    {
      'title': '過去進行形',
      'problem': '「そのとき私はテレビを見ていた」を英訳せよ。',
      'answer': 'I was watching TV then.',
      'explanation': 'was/were + -ing形'
    },
    {
      'title': '未来形（will）',
      'problem': '「明日雨が降るでしょう」を英訳せよ。',
      'answer': 'It will rain tomorrow.',
      'explanation': '【未来】will + 動詞原形'
    },
    {
      'title': '未来形（be going to）',
      'problem': '「私は明日買い物に行く予定です」を英訳せよ。',
      'answer': 'I am going to go shopping tomorrow.',
      'explanation': '【予定】be going to + 動詞原形'
    },
    {
      'title': '現在完了進行形',
      'problem': '「私は3時間ずっと勉強しています」を英訳せよ。',
      'answer': 'I have been studying for three hours.',
      'explanation': 'have been + -ing形'
    },
    {
      'title': '過去形と現在完了形の違い',
      'problem': '「昨日」を含む文は現在完了形を使えるか。',
      'answer': '使えない（過去形を使う）',
      'explanation': '明確な過去の時点→過去形'
    },
    {
      'title': '時制の一致',
      'problem': 'He said he (is/was) tired. の正しい形は？',
      'answer': 'was',
      'explanation': '【時制の一致】主節が過去→従属節も過去'
    },
  ],

  '英語_英文法_受動態': [
    {
      'title': '受動態の基本',
      'problem': 'Mary wrote this letter. を受動態に書き換えよ。',
      'answer': 'This letter was written by Mary.',
      'explanation': '【受動態】be動詞 + 過去分詞'
    },
    {
      'title': '助動詞を含む受動態',
      'problem': 'You must finish this work. を受動態に書き換えよ。',
      'answer': 'This work must be finished.',
      'explanation': '【助動詞+受動態】助動詞 + be + 過去分詞'
    },
    {
      'title': 'by以外の前置詞',
      'problem': '「その知らせに驚いた」を英訳せよ。',
      'answer': 'I was surprised at the news.',
      'explanation': '【前置詞】be surprised at'
    },
    {
      'title': 'SVOO型の受動態',
      'problem': 'He gave me a book. を2通りの受動態に書き換えよ。',
      'answer': 'I was given a book by him.\nA book was given to me by him.',
      'explanation': '【SVOO】2通りの受動態'
    },
    {
      'title': 'SVOC型の受動態',
      'problem': 'They call him Bob. を受動態に書き換えよ。',
      'answer': 'He is called Bob.',
      'explanation': '【SVOC】C(補語)はそのまま'
    },
    {
      'title': '進行形の受動態',
      'problem': 'They are building a new bridge. を受動態に書き換えよ。',
      'answer': 'A new bridge is being built.',
      'explanation': 'be being + 過去分詞'
    },
    {
      'title': '完了形の受動態',
      'problem': 'Someone has stolen my bike. を受動態に書き換えよ。',
      'answer': 'My bike has been stolen.',
      'explanation': 'have been + 過去分詞'
    },
    {
      'title': '群動詞の受動態',
      'problem': 'We must take care of the baby. を受動態に書き換えよ。',
      'answer': 'The baby must be taken care of.',
      'explanation': '【群動詞】まとめて受動態に'
    },
    {
      'title': 'by以外の前置詞（前置詞+動名詞）',
      'problem': '「私は彼に興味があります」を英訳せよ。',
      'answer': 'I am interested in him.',
      'explanation': 'be interested in'
    },
    {
      'title': '受動態の否定文',
      'problem': 'The letter was not written by him. を和訳せよ。',
      'answer': 'その手紙は彼によって書かれなかった',
      'explanation': '【否定】not を be動詞の後に'
    },
  ],

  '英語_英文法_不定詞': [
    {
      'title': '不定詞の名詞的用法',
      'problem': '「英語を学ぶことは楽しい」を英訳せよ。',
      'answer': 'To learn English is fun.',
      'explanation': '【名詞的用法】to + 動詞 = 〜すること'
    },
    {
      'title': '不定詞の形容詞的用法',
      'problem': '「読む本が欲しい」を英訳せよ。',
      'answer': 'I want a book to read.',
      'explanation': '【形容詞的用法】名詞を後ろから修飾'
    },
    {
      'title': '不定詞の副詞的用法（目的）',
      'problem': '「英語を学ぶために来た」を英訳せよ。',
      'answer': 'I came to study English.',
      'explanation': '【副詞的用法】目的: 〜するために'
    },
    {
      'title': '不定詞の副詞的用法（原因）',
      'problem': '「会えて嬉しい」を英訳せよ（I am glad ...）',
      'answer': 'I am glad to see you.',
      'explanation': '【副詞的用法】原因・理由'
    },
    {
      'title': '不定詞の副詞的用法（結果）',
      'problem': '「彼は成長して医者になった」を英訳せよ。',
      'answer': 'He grew up to be a doctor.',
      'explanation': '【副詞的用法】結果'
    },
    {
      'title': 'It is ... to do 構文',
      'problem': '「英語を学ぶことは楽しい」を It is で始めて英訳せよ。',
      'answer': 'It is fun to learn English.',
      'explanation': '【形式主語】It = to learn English'
    },
    {
      'title': 'too ... to do',
      'problem': '「あまりにも忙しくて行けない」を英訳せよ。',
      'answer': 'I am too busy to go.',
      'explanation': '【too...to】〜すぎて...できない'
    },
    {
      'title': '疑問詞 + to do',
      'problem': '「何をすべきか分からない」を英訳せよ。',
      'answer': 'I don\'t know what to do.',
      'explanation': '【疑問詞+to】何を〜すべきか'
    },
    {
      'title': 'seem to do',
      'problem': '「彼は忙しいようだ」を英訳せよ。',
      'answer': 'He seems to be busy.',
      'explanation': '【seem to】〜のようだ'
    },
    {
      'title': '原形不定詞',
      'problem': 'make, let, have の後の不定詞の形は？',
      'answer': '原形不定詞（toなし）',
      'explanation': '【使役動詞】to不要'
    },
  ],

  // ==================== 国語 ====================
  '国語_現代文_評論': [
    {
      'title': '接続詞（逆接）',
      'problem': '「努力は大切だ。（　）、才能も必要である。」の空欄に入る接続詞は？',
      'answer': 'しかし / だが / けれども',
      'explanation': '【逆接】の接続詞'
    },
    {
      'title': '接続詞（順接）',
      'problem': '「雨が降った。（　）、試合は中止になった。」の空欄に入る接続詞は？',
      'answer': 'だから / それで / ゆえに',
      'explanation': '【順接】原因→結果'
    },
    {
      'title': '接続詞（並列）',
      'problem': '「彼は頭がいい。（　）、スポーツも得意だ。」の空欄に入る接続詞は？',
      'answer': 'そして / また / さらに',
      'explanation': '【並列・添加】'
    },
    {
      'title': '接続詞（対比）',
      'problem': '「姉は活発だ。（　）、妹は内気だ。」の空欄に入る接続詞は？',
      'answer': '一方 / それに対して / 反対に',
      'explanation': '【対比】'
    },
    {
      'title': '接続詞（転換）',
      'problem': '話題を変えるときに使う接続詞は？',
      'answer': 'ところで / さて / では',
      'explanation': '【転換】話題転換'
    },
    {
      'title': '指示語',
      'problem': '「それ」が指す内容を見つける方法は？',
      'answer': '直前の文や段落を探す',
      'explanation': '【指示語】通常は直前を指す'
    },
    {
      'title': '段落の要旨',
      'problem': '段落の中心となる文を何というか。',
      'answer': '要旨（中心文）',
      'explanation': '【段落構成】'
    },
    {
      'title': '具体と抽象',
      'problem': '「例えば」の後に来るのは具体例か抽象的説明か。',
      'answer': '具体例',
      'explanation': '【具体化】'
    },
    {
      'title': '言い換え表現',
      'problem': '「つまり」の後には何が来るか。',
      'answer': '言い換え・まとめ',
      'explanation': '【言い換え】'
    },
    {
      'title': '筆者の主張',
      'problem': '筆者の主張を読み取るには何に注目すべきか。',
      'answer': '接続詞・文末表現・繰り返し',
      'explanation': '【読解】'
    },
  ],

  '国語_古文_文法': [
    {
      'title': '助動詞「けり」',
      'problem': '「けり」の意味と活用を答えよ。',
      'answer': '【意味】過去・詠嘆\n【活用】ラ行変格活用',
      'explanation': '【接続】連用形'
    },
    {
      'title': '助動詞「き」',
      'problem': '「き」の意味と活用を答えよ。',
      'answer': '【意味】過去\n【活用】特殊型',
      'explanation': '【接続】連用形'
    },
    {
      'title': '助動詞「む」',
      'problem': '「む」の意味を3つ答えよ。',
      'answer': '推量・意志・勧誘',
      'explanation': '【未然形接続】'
    },
    {
      'title': '助動詞「べし」',
      'problem': '「べし」の意味を答えよ（主なもの3つ）。',
      'answer': '推量・当然・可能',
      'explanation': '【終止形接続】'
    },
    {
      'title': '助動詞「らむ」',
      'problem': '「らむ」の意味を答えよ。',
      'answer': '現在推量・原因推量',
      'explanation': '【終止形接続】'
    },
    {
      'title': '助動詞「り」',
      'problem': '「り」の意味と接続を答えよ。',
      'answer': '【意味】完了・存続\n【接続】サ変・四段の已然形',
      'explanation': '【特殊な接続】'
    },
    {
      'title': '助動詞「たり」',
      'problem': '「たり」の意味を答えよ。',
      'answer': '完了・存続',
      'explanation': '【接続】連用形'
    },
    {
      'title': '助動詞「ず」',
      'problem': '「ず」の意味と活用を答えよ。',
      'answer': '【意味】打消\n【活用】特殊型',
      'explanation': '【接続】未然形'
    },
    {
      'title': '助動詞「る・らる」',
      'problem': '「る・らる」の意味を4つ答えよ。',
      'answer': '受身・尊敬・可能・自発',
      'explanation': '【接続】未然形'
    },
    {
      'title': '助動詞「す・さす」',
      'problem': '「す・さす」の意味を2つ答えよ。',
      'answer': '使役・尊敬',
      'explanation': '【接続】未然形'
    },
  ],

  // ==================== 理科 ====================
  '理科_物理_力学': [
    {
      'title': '等加速度運動',
      'problem': '静止していた物体が 2.0 m/s² で 5.0秒間運動した。\n(1) 速度 (2) 距離',
      'answer': '(1) v = 10 m/s\n(2) x = 25 m',
      'explanation': '【公式】v = at, x = (1/2)at²'
    },
    {
      'title': '自由落下',
      'problem': '高さ20mから物体を落とした。地面に達するまでの時間は？（g=10m/s²）',
      'answer': 't = 2秒',
      'explanation': 'h = (1/2)gt², 20 = 5t²'
    },
    {
      'title': '運動方程式',
      'problem': '質量2kgの物体に4Nの力を加えた。加速度は？',
      'answer': 'a = 2 m/s²',
      'explanation': 'F = ma, 4 = 2a'
    },
    {
      'title': '作用反作用の法則',
      'problem': '物体Aが物体Bを5Nで押したとき、Bは Aを何Nで押し返すか。',
      'answer': '5N',
      'explanation': '【ニュートンの第3法則】'
    },
    {
      'title': '摩擦力',
      'problem': '質量5kgの物体が面から受ける垂直抗力が50Nのとき、最大静止摩擦力は？（μ=0.3）',
      'answer': 'f = 15N',
      'explanation': 'f = μN = 0.3×50'
    },
    {
      'title': '力のつり合い',
      'problem': '2つの力がつり合っているとき、合力は？',
      'answer': '0N',
      'explanation': '【つり合い】Σ F = 0'
    },
    {
      'title': '等速円運動',
      'problem': '半径1m、速さ2m/sの等速円運動の向心加速度は？',
      'answer': 'a = 4 m/s²',
      'explanation': 'a = v²/r = 4/1'
    },
    {
      'title': '仕事',
      'problem': '物体を10Nの力で5m動かした。仕事は？',
      'answer': 'W = 50J',
      'explanation': 'W = Fx = 10×5'
    },
    {
      'title': '運動エネルギー',
      'problem': '質量2kg、速さ3m/sの物体の運動エネルギーは？',
      'answer': 'K = 9J',
      'explanation': 'K = (1/2)mv² = (1/2)×2×9'
    },
    {
      'title': '力学的エネルギー保存',
      'problem': '高さ5mの位置から自由落下した物体の地上での速さは？（g=10m/s²）',
      'answer': 'v = 10 m/s',
      'explanation': 'mgh = (1/2)mv², v = √(2gh)'
    },
  ],

  '理科_化学_理論化学': [
    {
      'title': 'モル濃度',
      'problem': 'NaOH 4.0g を 500mL に溶かした。モル濃度は？（分子量40）',
      'answer': 'C = 0.20 mol/L',
      'explanation': '【モル濃度】C = n/V = 0.1/0.5'
    },
    {
      'title': '質量パーセント濃度',
      'problem': '水100gに塩20gを溶かした。質量パーセント濃度は？',
      'answer': '16.7%',
      'explanation': '20/(100+20)×100'
    },
    {
      'title': '化学反応式',
      'problem': '水素と酸素が反応して水ができる化学反応式を書け。',
      'answer': '2H₂ + O₂ → 2H₂O',
      'explanation': '【係数】原子数を合わせる'
    },
    {
      'title': '物質量',
      'problem': 'CO₂ 44g は何molか。（分子量44）',
      'answer': '1 mol',
      'explanation': 'n = m/M = 44/44'
    },
    {
      'title': 'アボガドロ数',
      'problem': '1molの物質に含まれる粒子数は？',
      'answer': '6.02×10²³ 個',
      'explanation': '【アボガドロ定数】'
    },
    {
      'title': '気体の状態方程式',
      'problem': '0℃、1atmで1molの気体の体積は？',
      'answer': '22.4 L',
      'explanation': '【標準状態】PV = nRT'
    },
    {
      'title': '酸と塩基',
      'problem': 'HClは酸か塩基か。',
      'answer': '酸',
      'explanation': 'H⁺を出す物質'
    },
    {
      'title': 'pH',
      'problem': '[H⁺] = 1.0×10⁻⁵ mol/L の溶液のpHは？',
      'answer': 'pH = 5',
      'explanation': 'pH = -log[H⁺]'
    },
    {
      'title': '中和反応',
      'problem': 'HCl + NaOH → ? + H₂O の?に入る物質は？',
      'answer': 'NaCl',
      'explanation': '【中和】酸+塩基→塩+水'
    },
    {
      'title': '酸化還元反応',
      'problem': '電子を失う反応を何というか。',
      'answer': '酸化',
      'explanation': '【酸化】電子を失う'
    },
  ],

  // ==================== 社会 ====================
  '社会_日本史_近代': [
    {
      'title': '明治維新',
      'problem': '五箇条の御誓文の内容を3つ答えよ。',
      'answer': '1. 広く会議を開く\n2. 上下心を一にする\n3. 智識を世界に求める',
      'explanation': '【明治新政府の基本方針】1868年'
    },
    {
      'title': '文明開化',
      'problem': '「文明開化」とは何か簡潔に説明せよ。',
      'answer': '西洋の文化や技術を取り入れて近代化を進めたこと',
      'explanation': '【明治初期】'
    },
    {
      'title': '地租改正',
      'problem': '地租改正で地価の何%を現金で納めることになったか。',
      'answer': '3%（後に2.5%）',
      'explanation': '【1873年】税制改革'
    },
    {
      'title': '自由民権運動',
      'problem': '板垣退助が中心となった運動は？',
      'answer': '自由民権運動',
      'explanation': '【1874年】民選議院設立建白書'
    },
    {
      'title': '大日本帝国憲法',
      'problem': '大日本帝国憲法が発布された年は？',
      'answer': '1889年',
      'explanation': '【明治22年】アジア初の近代憲法'
    },
    {
      'title': '日清戦争',
      'problem': '日清戦争の講和条約は何か。',
      'answer': '下関条約',
      'explanation': '【1895年】清から賠償金と領土'
    },
    {
      'title': '日露戦争',
      'problem': '日露戦争の講和条約は何か。',
      'answer': 'ポーツマス条約',
      'explanation': '【1905年】アメリカの仲介'
    },
    {
      'title': '韓国併合',
      'problem': '日本が韓国を併合した年は？',
      'answer': '1910年',
      'explanation': '【明治43年】朝鮮半島の植民地化'
    },
    {
      'title': '大正デモクラシー',
      'problem': '「憲政の常道」とは何か。',
      'answer': '議会の多数党が政権を担当すること',
      'explanation': '【大正期】政党政治'
    },
    {
      'title': '普通選挙法',
      'problem': '普通選挙法が成立した年と内容を答えよ。',
      'answer': '1925年、満25歳以上の男子に選挙権',
      'explanation': '【大正14年】納税額の制限撤廃'
    },
  ],

  '社会_世界史_近代革命': [
    {
      'title': 'フランス革命',
      'problem': '人権宣言の内容を答えよ。',
      'answer': '自由・平等・国民主権・所有権の不可侵',
      'explanation': '1789年発布'
    },
    {
      'title': 'アメリカ独立革命',
      'problem': 'アメリカ独立宣言が出された年は？',
      'answer': '1776年',
      'explanation': '【7月4日】独立記念日'
    },
    {
      'title': '産業革命',
      'problem': '産業革命が最初に起こった国は？',
      'answer': 'イギリス',
      'explanation': '【18世紀後半】綿工業から'
    },
    {
      'title': 'ナポレオン',
      'problem': 'ナポレオンが皇帝に即位した年は？',
      'answer': '1804年',
      'explanation': '【第一帝政】フランス皇帝'
    },
    {
      'title': 'ウィーン体制',
      'problem': 'ウィーン会議の議長国は？',
      'answer': 'オーストリア',
      'explanation': '【1814-15年】正統主義'
    },
    {
      'title': '七月革命',
      'problem': 'フランスの七月革命が起こった年は？',
      'answer': '1830年',
      'explanation': '【七月王政】ルイ・フィリップ'
    },
    {
      'title': '二月革命',
      'problem': 'フランスの二月革命で成立した政体は？',
      'answer': '第二共和政',
      'explanation': '【1848年】普通選挙実施'
    },
    {
      'title': 'ドイツ統一',
      'problem': 'ドイツ統一を主導したプロイセンの宰相は？',
      'answer': 'ビスマルク',
      'explanation': '【1871年】鉄血政策'
    },
    {
      'title': 'イタリア統一',
      'problem': 'イタリア統一の三傑を答えよ。',
      'answer': 'カヴール、ガリバルディ、マッツィーニ',
      'explanation': '【1861年】イタリア王国成立'
    },
    {
      'title': 'アヘン戦争',
      'problem': 'アヘン戦争の講和条約は？',
      'answer': '南京条約',
      'explanation': '【1842年】香港割譲'
    },
  ],

  '社会_地理_地形': [
    {
      'title': '地形図の読み取り',
      'problem': '2万5千分の1の地形図で4cmは実際何mか？',
      'answer': '1000m = 1km',
      'explanation': '4cm × 25000 = 100000cm'
    },
    {
      'title': '等高線',
      'problem': '等高線の間隔が狭いところは傾斜が急か緩やかか。',
      'answer': '急',
      'explanation': '【等高線】間隔が狭い=急斜面'
    },
    {
      'title': '主曲線と計曲線',
      'problem': '5本に1本の太い等高線を何というか。',
      'answer': '計曲線',
      'explanation': '【地形図】'
    },
    {
      'title': '河川記号',
      'problem': '地形図で1本の青い線は何を表すか。',
      'answer': '河川',
      'explanation': '【地図記号】'
    },
    {
      'title': '扇状地',
      'problem': '山地から平野に出た河川が作る地形は？',
      'answer': '扇状地',
      'explanation': '【堆積地形】扇形の地形'
    },
    {
      'title': '三角州',
      'problem': '河口付近に土砂が堆積した地形は？',
      'answer': '三角州（デルタ）',
      'explanation': '【堆積地形】'
    },
    {
      'title': 'リアス海岸',
      'problem': '山地が沈降してできた複雑な海岸線を何というか。',
      'answer': 'リアス海岸',
      'explanation': '【沈水海岸】三陸海岸など'
    },
    {
      'title': '火山',
      'problem': '溶岩の粘性が高い火山の形は？',
      'answer': '急峻な形（鐘状火山・溶岩円頂丘）',
      'explanation': '粘性高い→急斜面'
    },
    {
      'title': 'カルスト地形',
      'problem': '石灰岩地域に見られる独特の地形を何というか。',
      'answer': 'カルスト地形',
      'explanation': '【溶食地形】鍾乳洞など'
    },
    {
      'title': '海岸段丘',
      'problem': '海岸沿いに階段状に見られる地形は？',
      'answer': '海岸段丘',
      'explanation': '【隆起地形】'
    },
  ],

  '社会_政治経済_政治制度': [
    {
      'title': '三権分立',
      'problem': '三権とそれを担当する機関を答えよ。',
      'answer': '立法権→国会\n行政権→内閣\n司法権→裁判所',
      'explanation': '【三権分立】権力の分散'
    },
    {
      'title': '国会',
      'problem': '日本の国会は何院制か。',
      'answer': '二院制（衆議院と参議院）',
      'explanation': '【両院制】'
    },
    {
      'title': '衆議院の優越',
      'problem': '予算の議決で衆議院と参議院が異なった場合どうなるか。',
      'answer': '衆議院の議決が国会の議決となる',
      'explanation': '【衆議院の優越】'
    },
    {
      'title': '内閣',
      'problem': '内閣総理大臣を指名するのはどこか。',
      'answer': '国会',
      'explanation': '【議院内閣制】'
    },
    {
      'title': '裁判所',
      'problem': '最高裁判所の裁判官は誰が任命するか。',
      'answer': '内閣',
      'explanation': '【三権分立】'
    },
    {
      'title': '憲法改正',
      'problem': '憲法改正に必要な国会の賛成は？',
      'answer': '各議院の総議員の3分の2以上',
      'explanation': '【硬性憲法】+ 国民投票'
    },
    {
      'title': '基本的人権',
      'problem': '日本国憲法が保障する三大基本的人権を答えよ。',
      'answer': '自由権・平等権・社会権',
      'explanation': '【人権】'
    },
    {
      'title': '平和主義',
      'problem': '憲法第9条で放棄されているものは？',
      'answer': '戦争と武力による威嚇・武力の行使',
      'explanation': '【平和主義】'
    },
    {
      'title': '地方自治',
      'problem': '地方自治の長と議会の関係を何というか。',
      'answer': '二元代表制',
      'explanation': '【地方自治】両方とも直接選挙'
    },
    {
      'title': '選挙制度',
      'problem': '衆議院議員選挙の制度は？',
      'answer': '小選挙区比例代表並立制',
      'explanation': '【選挙制度】'
    },
  ],
};

class ProblemListScreen extends StatefulWidget {
  final String subject;
  final String subSubject;
  final String unit;
  final ProblemRecordManager recordManager;

  const ProblemListScreen({
    super.key,
    required this.subject,
    required this.subSubject,
    required this.unit,
    required this.recordManager,
  });

  @override
  State<ProblemListScreen> createState() => _ProblemListScreenState();
}

class _ProblemListScreenState extends State<ProblemListScreen> {
  List<Map<String, String>> _aiGeneratedProblems = [];
  bool _isGenerating = false;

  Future<void> _generateAIProblems() async {
    if (OPENAI_API_KEY.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ APIキーが設定されていません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENAI_API_KEY',
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {
              "role": "user",
              "content": """以下の単元の問題を5問生成してください。

科目: ${widget.subject}
分野: ${widget.subSubject}
単元: ${widget.unit}

以下のJSON形式で回答してください：

{
  "problems": [
    {
      "title": "問題のタイトル",
      "problem": "問題文（複数行可）",
      "answer": "解答",
      "explanation": "詳しい解説"
    }
  ]
}

重要：
- 問題は高校レベルの標準的な難易度で作成
- 解答は詳しく、ステップバイステップで説明
- 日本語で回答
- JSON形式のみを返す（他のテキストは含めない）
- 5問生成してください"""
            }
          ],
          "max_tokens": 3000,
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String text = data['choices'][0]['message']['content'];

        // JSONの抽出
        if (text.contains('```json')) {
          text = text.split('```json')[1].split('```')[0].trim();
        } else if (text.contains('```')) {
          text = text.split('```')[1].split('```')[0].trim();
        }

        final result = jsonDecode(text);
        final problems = (result['problems'] as List)
            .map((p) => {
                  'title': p['title'].toString(),
                  'problem': p['problem'].toString(),
                  'answer': p['answer'].toString(),
                  'explanation': p['explanation'].toString(),
                })
            .toList();

        setState(() {
          _aiGeneratedProblems = problems;
          _isGenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${problems.length}問の問題を生成しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = '${widget.subject}_${widget.subSubject}_${widget.unit}';
    final existingProblems = _problemsData[key] ?? [];
    final allProblems = [...existingProblems];

    // AI生成問題を既存問題の後に追加
    for (int i = 0; i < _aiGeneratedProblems.length; i++) {
      allProblems.add(_aiGeneratedProblems[i]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.unit} - 問題一覧'),
        backgroundColor: Colors.purple[400],
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI問題生成',
            onPressed: _isGenerating ? null : _generateAIProblems,
          ),
        ],
      ),
      body: Column(
        children: [
          // AI生成ボタン
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.purple[50],
            child: Column(
              children: [
                if (_isGenerating)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('AIが問題を生成中...', style: TextStyle(fontSize: 16)),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _generateAIProblems,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                        _aiGeneratedProblems.isEmpty ? 'AIで問題を生成' : 'さらに問題を生成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                if (_aiGeneratedProblems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'AI生成: ${_aiGeneratedProblems.length}問',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 問題リスト
          Expanded(
            child: allProblems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          '上のボタンからAIで問題を生成できます',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: allProblems.length,
                    itemBuilder: (context, index) {
                      final problem = allProblems[index];
                      final isAIGenerated = index >= existingProblems.length;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAIGenerated
                                ? Colors.teal[400]
                                : Colors.purple[400],
                            child: isAIGenerated
                                ? const Icon(Icons.auto_awesome,
                                    color: Colors.white)
                                : Text(
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                problem['problem']!.split('\n')[0],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isAIGenerated)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '🤖 AI生成',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            final problemId = isAIGenerated
                                ? '${key}_ai_${index - existingProblems.length}'
                                : '${key}_$index';

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProblemDetailScreen(
                                  title: problem['title']!,
                                  problem: problem['problem']!,
                                  answer: problem['answer']!,
                                  explanation: problem['explanation']!,
                                  problemId: problemId,
                                  subject: widget.subject,
                                  subSubject: widget.subSubject,
                                  unit: widget.unit,
                                  recordManager: widget.recordManager,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProblemDetailScreen extends StatefulWidget {
  final String title;
  final String problem;
  final String answer;
  final String explanation;
  final String problemId;
  final String subject;
  final String subSubject;
  final String unit;
  final ProblemRecordManager recordManager;

  const ProblemDetailScreen({
    super.key,
    required this.title,
    required this.problem,
    required this.answer,
    required this.explanation,
    required this.problemId,
    required this.subject,
    required this.subSubject,
    required this.unit,
    required this.recordManager,
  });

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> {
  bool _showAnswer = false;

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
              widget.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
                '問題', widget.problem, Icons.question_answer, Colors.blue),
            const SizedBox(height: 20),

            // 解答表示ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAnswer = !_showAnswer;
                  });
                },
                icon:
                    Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _showAnswer ? '解答を隠す' : '解答を表示',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            if (_showAnswer) ...[
              const SizedBox(height: 20),
              _buildSection(
                  '解答', widget.answer, Icons.check_circle, Colors.green),
              const SizedBox(height: 20),
              _buildSection(
                  '解説', widget.explanation, Icons.lightbulb, Colors.orange),
              const SizedBox(height: 30),

              // ⭐ 正解/不正解ボタン
              const Text(
                '解答結果を記録',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.recordManager.recordAttempt(
                          problemId: widget.problemId,
                          subject: widget.subject,
                          subSubject: widget.subSubject,
                          unit: widget.unit,
                          problemTitle: widget.title,
                          isCorrect: true,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ 正解として記録しました'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('正解', style: TextStyle(fontSize: 18)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.recordManager.recordAttempt(
                          problemId: widget.problemId,
                          subject: widget.subject,
                          subSubject: widget.subSubject,
                          unit: widget.unit,
                          problemTitle: widget.title,
                          isCorrect: false,
                        );
                        // デバッグ用
                        print(
                            '総記録数: ${widget.recordManager.getTotalAttempts()}');
                        print(
                            '復習必要数: ${widget.recordManager.getReviewPriority().length}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ 不正解として記録しました'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      icon: const Icon(Icons.cancel, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('不正解', style: TextStyle(fontSize: 18)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
            Text(content, style: const TextStyle(fontSize: 16, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// 復習画面
// ==========================================

class ReviewMainScreen extends StatefulWidget {
  final ProblemRecordManager recordManager;

  const ReviewMainScreen({super.key, required this.recordManager});

  @override
  State<ReviewMainScreen> createState() => _ReviewMainScreenState();
}

class _ReviewMainScreenState extends State<ReviewMainScreen> {
  @override
  Widget build(BuildContext context) {
    final reviewProblems = widget.recordManager.getReviewPriority();
    final totalAttempts = widget.recordManager.getTotalAttempts();
    final accuracy = widget.recordManager.getOverallAccuracy();

    return Scaffold(
      appBar: AppBar(
        title: const Text('復習'),
        backgroundColor: Colors.orange[400],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // 学習統計カード
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('学習統計',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text('解いた問題: $totalAttempts 問',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text('正答率: ${(accuracy * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const SizedBox(height: 10),
                  Text('要復習: ${reviewProblems.length} 問',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 復習問題がない場合
          if (reviewProblems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.celebration, size: 60, color: Colors.green[400]),
                    const SizedBox(height: 20),
                    const Text('復習すべき問題はありません！',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('全問正解です 🎉',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // 復習問題リスト
          if (reviewProblems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('復習すべき問題',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Text('間違えた回数が多い順に表示しています',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            ...reviewProblems.map((attempt) {
              final incorrectCount =
                  widget.recordManager.getIncorrectCount()[attempt.problemId] ??
                      0;
              Color avatarColor;
              if (incorrectCount >= 5) {
                avatarColor = Colors.red[700]!;
              } else if (incorrectCount >= 3) {
                avatarColor = Colors.orange[700]!;
              } else {
                avatarColor = Colors.yellow[700]!;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: avatarColor,
                    child: Text(
                      '×$incorrectCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    attempt.problemTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${attempt.subject} > ${attempt.unit}\n$incorrectCount回間違えました',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('問題集タブから該当問題を開いてください'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}
