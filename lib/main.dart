import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

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

class GameLevel {
  final int size;
  final List<List<int>> regions;
  final List<List<bool>> solution;

  GameLevel(this.size, this.regions, this.solution);
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
  bool isLoading = true;

  List<GameLevel> levels = [];
  late List<List<int>> playerState;

  final List<Color> regionColors = [
    Colors.blue.shade200,
    Colors.green.shade200,
    Colors.orange.shade200,
    Colors.purple.shade200,
    Colors.pink.shade200,
    Colors.teal.shade200,
    Colors.red.shade200,
  ];

  @override
  void initState() {
    super.initState();
    _loadLevelsData();
  }

  Future<void> _loadLevelsData() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/levels.json',
      );
      final List<dynamic> jsonResponse = json.decode(jsonString);

      setState(() {
        levels = jsonResponse.map((level) {
          return GameLevel(
            level['size'] as int,
            (level['regions'] as List)
                .map((row) => List<int>.from(row))
                .toList(),
            (level['solution'] as List)
                .map((row) => List<bool>.from(row))
                .toList(),
          );
        }).toList();

        isLoading = false;
        _loadLevel();
      });
    } catch (e) {
      print("Error loading JSON: $e");
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
    if (gameOver || isLoading) return;

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
          "Level Cleared!",
          "Big brain energy. Ready for the next one?",
          true,
        );
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
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    int n = levels[currentLevelIndex].size;
    var currentLevelData = levels[currentLevelIndex];

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/desert.jpg'), // Teri image ka path
          fit: BoxFit.cover, // Poori screen par failane ke liye
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Level ${currentLevelIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.amber.shade400.withOpacity(0.85),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadLevelsData,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildRuleCard("🐫 1 per color"),
                  _buildRuleCard("🐫 1 per row & col"),
                  _buildRuleCard("🛑 Camels cannot touch"),
                ],
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Icon(
                  index < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 32,
                );
              }),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                              color: regionColors[regionId].withOpacity(0.85),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.black45,
                                width: 1,
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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
