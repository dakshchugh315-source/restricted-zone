import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle (loading JSON)

void main() {
  runApp(const MeowdokuApp());
}

class MeowdokuApp extends StatelessWidget {
  const MeowdokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cameloku 🐫',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      home: const GameBoard(),
    );
  }
}

// --- LEVEL DATA STRUCTURE ---
class GameLevel {
  final int size;
  final List<List<int>> regions;
  final List<List<bool>> solution;

  GameLevel(this.size, this.regions, this.solution);

  // JSON se parse karne ke liye Factory method
  factory GameLevel.fromJson(Map<String, dynamic> json) {
    int size = json['size'];

    // Parse Regions
    var regions = (json['regions'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();

    // Parse Solution
    var solution = (json['solution'] as List)
        .map((row) => (row as List).map((e) => e as bool).toList())
        .toList();

    return GameLevel(size, regions, solution);
  }
}

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  int lives = 3;
  bool gameOver = false;
  int currentLevelIndex = 0;
  bool isLoading = true; // Loading state flag

  List<GameLevel> levels = []; // Ab ye khali rahegi, JSON se bharegi
  late List<List<int>> playerState;

  // Added extra colors in case bigger levels have more regions
  final List<Color> regionColors = [
    Colors.blue.shade200,
    Colors.green.shade200,
    Colors.orange.shade200,
    Colors.purple.shade200,
    Colors.pink.shade200,
    Colors.teal.shade200,
    Colors.yellow.shade400,
    Colors.cyan.shade200,
    Colors.indigo.shade200,
  ];

  @override
  void initState() {
    super.initState();
    _loadLevelsData();
  }

  // --- JSON LOADING LOGIC ---
  Future<void> _loadLevelsData() async {
    try {
      // JSON file ko assets se read karna
      final String response = await rootBundle.loadString('assets/level.json');
      final List<dynamic> data = json.decode(response);

      setState(() {
        // Data ko GameLevel objects mein convert karna
        levels = data.map((json) => GameLevel.fromJson(json)).toList();
        isLoading = false;
        _loadLevel(); // Pehla level start karo
      });
    } catch (e) {
      print("Error loading levels: $e");
    }
  }

  void _loadLevel() {
    if (levels.isEmpty) return;
    
    int n = levels[currentLevelIndex].size;
    setState(() {
      playerState = List.generate(n, (_) => List.filled(n, 0));
      lives = 3;
      gameOver = false;
    });
  }

  void _handleTap(int row, int col) {
    if (gameOver) return;

    setState(() {
      if (playerState[row][col] == 0) {
        playerState[row][col] = 2; // Cross
      } else if (playerState[row][col] == 2) {
        // Try placing Camel
        if (levels[currentLevelIndex].solution[row][col]) {
          playerState[row][col] = 1;
          _checkWinCondition();
        } else {
          lives--;
          playerState[row][col] = 0;

          if (lives <= 0) {
            gameOver = true;
            _showDialog("Game Over", "The camels died of thirst! 🐪💀", false);
          }
        }
      } else if (playerState[row][col] == 1) {
        playerState[row][col] = 0; // Remove Camel
      }
    });
  }

  void _checkWinCondition() {
    int n = levels[currentLevelIndex].size;
    int camelsPlaced = 0;
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (playerState[r][c] == 1) camelsPlaced++;
      }
    }
    if (camelsPlaced == n) {
      gameOver = true;
      if (currentLevelIndex < levels.length - 1) {
        _showDialog(
            "Level Cleared!", "Big brain energy. Ready for the next one?", true);
      } else {
        _showDialog("You Win!", "You beat all levels! 🐫👑", false);
      }
    }
  }

  void _showDialog(String title, String message, bool hasNextLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            if (!hasNextLevel && lives <= 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadLevel(); // Retry current level
                },
                child: const Text("Retry Level"),
              ),
            if (hasNextLevel)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    currentLevelIndex++;
                    _loadLevel();
                  });
                },
                child: const Text("Next Level ➡️"),
              ),
            if (!hasNextLevel && lives > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    currentLevelIndex = 0; // Back to start
                    _loadLevel();
                  });
                },
                child: const Text("Play Again"),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRuleCard(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85), // Thoda transparent desert vibe
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade300, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 13,
            color: Colors.brown.shade900,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agar data fetch ho raha hai, toh loader show karo
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.amber,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    int n = levels[currentLevelIndex].size;
    var currentLevelData = levels[currentLevelIndex];

    return Scaffold(
      extendBodyBehindAppBar: true, // Transparent AppBar ke peeche background jaane do
      appBar: AppBar(
        title: Text('Level ${currentLevelIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.4), // Semi-transparent AppBar
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadLevel,
          )
        ],
      ),
      // --- DESERT BACKGROUND THEME ---
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/desert.jpg'), // Yahan image add ho gayi
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black26, // Background ko slight dark kiya hai taaki board clear dikhe
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // THE RULES UI
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildRuleCard("🐫 1 per color"),
                    _buildRuleCard("🐫 1 per row & col"),
                    _buildRuleCard("🛑 No touching"),
                  ],
                ),
              ),

              // LIVES COUNTER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Icon(
                    index < lives ? Icons.favorite : Icons.favorite_border,
                    color: Colors.redAccent,
                    size: 32,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 4)
                    ],
                  );
                }),
              ),

              const SizedBox(height: 10),

              // THE BOARD
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4), // Board backdrop
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: n,
                            crossAxisSpacing: 3,
                            mainAxisSpacing: 3,
                          ),
                          itemCount: n * n,
                          itemBuilder: (context, index) {
                            int row = index ~/ n;
                            int col = index % n;
                            int regionId = currentLevelData.regions[row][col];
                            int cellState = playerState[row][col];

                            String cellContent = '';
                            if (cellState == 1) cellContent = '🐫';
                            if (cellState == 2) cellContent = '❌';

                            return GestureDetector(
                              onTap: () => _handleTap(row, col),
                              child: Container(
                                decoration: BoxDecoration(
                                  // Use modulo operation just in case regions exceed colors length
                                  color: regionColors[regionId % regionColors.length],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cellContent,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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
}