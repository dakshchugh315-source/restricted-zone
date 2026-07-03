import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NAYA PACKAGE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
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
  int diamonds = 0;

  List<GameLevel> levels = [];
  late List<List<int>> playerState;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  String tutorialMessage =
      "Welcome! 🐫 Tap any empty box to place your first camel.";

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
    _initializeApp();
  }

  // NAYA: Shuru mein data load karne ka setup
  Future<void> _initializeApp() async {
    await _loadGameData(); // Pehle saved data lao
    await _loadLevelsData(); // Phir JSON se levels lao
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  // NAYA: Data Load karne ka function
  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLevelIndex = prefs.getInt('saved_level') ?? 0;
      diamonds = prefs.getInt('saved_diamonds') ?? 0;
    });
  }

  // NAYA: Data Save karne ka function
  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', currentLevelIndex);
    await prefs.setInt('saved_diamonds', diamonds);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (err) {},
      ),
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          print('Interstitial Failed: ${err.message}');
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          setState(() {
            lives = 1;
            gameOver = false;
          });
        },
      );
      _rewardedAd = null;
      _loadRewardedAd();
    } else {
      setState(() {
        lives = 1;
        gameOver = false;
      });
      _loadRewardedAd();
    }
  }

  void _goToNextLevelWithAdCheck() {
    if ((currentLevelIndex + 1) % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _startNextLevel();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
          _startNextLevel();
        },
      );
      _interstitialAd!.show();
    } else {
      _startNextLevel();
    }
  }

  void _startNextLevel() {
    setState(() {
      currentLevelIndex++;
      _saveGameData(); // NAYA: Level badhte hi save karo
      _loadLevel();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
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
      if (currentLevelIndex == 0) {
        tutorialMessage =
            "Welcome! 🐫 Tap any empty box to place your first camel.";
      }
    });
  }

  int _countPlacedCamels() {
    int count = 0;
    for (var row in playerState) {
      for (var cell in row) {
        if (cell == 1) count++;
      }
    }
    return count;
  }

  void _handleTap(int row, int col) {
    if (gameOver || isLoading) return;
    setState(() {
      if (playerState[row][col] == 0) {
        playerState[row][col] = 2;
      } else if (playerState[row][col] == 2) {
        if (levels[currentLevelIndex].solution[row][col]) {
          playerState[row][col] = 1;

          if (currentLevelIndex == 0) {
            int totalCamels = _countPlacedCamels();
            if (totalCamels == 1) {
              tutorialMessage =
                  "Awesome! 🌟 Rule 1: Only ONE camel allowed per color region!";
            } else if (totalCamels == 2) {
              tutorialMessage =
                  "Great! 🛑 Rule 2: Camels CANNOT touch each other, not even diagonally.";
            } else if (totalCamels == 3) {
              tutorialMessage =
                  "You're a natural! 🔥 Rule 3: Only 1 camel per Row & Column.";
            } else {
              tutorialMessage = "Keep going! Fill the board! 🧠";
            }
          }

          _checkWinCondition();
        } else {
          lives--;
          playerState[row][col] = 0;

          if (currentLevelIndex == 0) {
            tutorialMessage =
                "Oops! ❌ That breaks a rule. Try a different spot.";
          }

          if (lives <= 0) {
            gameOver = true;
            _showDialog("Game Over", "The camels died of thirst! 🐪💀", false);
          }
        }
      } else if (playerState[row][col] == 1) {
        playerState[row][col] = 0;
      }
    });
  }

  void _checkWinCondition() {
    int n = levels[currentLevelIndex].size;
    int camelsPlaced = _countPlacedCamels();

    if (camelsPlaced == n) {
      gameOver = true;
      setState(() {
        diamonds += 7;
      });
      _saveGameData(); // NAYA: Diamonds badhne par turant save karo

      if (currentLevelIndex < levels.length - 1) {
        _showDialog(
          "Level Cleared! 🎉",
          "You earned 7 💎! Ready for the next one?",
          true,
        );
      } else {
        _showDialog(
          "You Win! 🏆",
          "You beat all levels and earned 7 💎! 🐫👑",
          false,
        );
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
            if (lives <= 0) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadLevel();
                },
                child: const Text(
                  "Restart Level",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRewardedAd();
                },
                child: const Text(
                  "📺 Watch Ad (+1 Life)",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (diamonds >= 20)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        diamonds -= 20;
                        lives = 1;
                        gameOver = false;
                      });
                      _saveGameData(); // NAYA: Diamonds cut hone par save karo
                    },
                    child: const Text(
                      "💎 Pay 20 for +1 Life",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
            if (hasNextLevel && lives > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _goToNextLevelWithAdCheck();
                },
                child: const Text("Next Level ➡️"),
              ),
            if (!hasNextLevel && lives > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    currentLevelIndex = 0;
                    _saveGameData(); // NAYA: Reset hone par save karo
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
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
          image: AssetImage('assets/desert.jpg'),
          fit: BoxFit.cover,
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
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '💎 $diamonds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadLevelsData,
            ),
          ],
        ),
        body: Column(
          children: [
            if (currentLevelIndex == 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade400, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.blue, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tutorialMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (currentLevelIndex != 0)
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

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Icon(
                  index < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 42,
                );
              }),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
                                style: const TextStyle(fontSize: 34),
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

            if (_isBannerAdLoaded)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              )
            else
              const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
