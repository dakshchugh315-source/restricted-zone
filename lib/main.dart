import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

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
  String tutorialMessage =
      "Welcome! 🐫 Tap any empty box to place your first camel.";

  List<GameLevel> levels = [];
  late List<List<int>> playerState;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  // Teeno alag players taki sounds lag na karein
  final AudioPlayer _camelSoundPlayer = AudioPlayer();
  final AudioPlayer _loseHeartPlayer = AudioPlayer();
  final AudioPlayer _levelUpPlayer = AudioPlayer();

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

  Future<void> _initializeApp() async {
    await _loadGameData();
    await _loadLevelsData();
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLevelIndex = prefs.getInt('saved_level') ?? 0;
      diamonds = prefs.getInt('saved_diamonds') ?? 0;
    });
  }

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
        onAdFailedToLoad: (err) {},
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
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
      _saveGameData();
      _loadLevel();
    });
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
    for (int r = 0; r < playerState.length; r++) {
      for (int c = 0; c < playerState[r].length; c++) {
        if (playerState[r][c] == 1) {
          count++;
        }
      }
    }
    return count;
  }

  void _playCamelSound() async {
    await _camelSoundPlayer.play(AssetSource('camel_sound.mp3'));
  }

  void _playLoseHeartSound() async {
    await _loseHeartPlayer.play(AssetSource('lose_heart.mp3'));
  }

  void _playLevelUpSound() async {
    await _levelUpPlayer.play(AssetSource('level_up.mp3'));
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _camelSoundPlayer.dispose();
    _loseHeartPlayer.dispose();
    _levelUpPlayer.dispose();
    super.dispose();
  }

  void _handleTap(int row, int col) {
    if (gameOver || isLoading) return;
    setState(() {
      if (playerState[row][col] == 0) {
        playerState[row][col] = 2; // Cross
      } else if (playerState[row][col] == 2) {
        if (levels[currentLevelIndex].solution[row][col]) {
          playerState[row][col] = 1; // Camel placed
          _playCamelSound();

          if (currentLevelIndex == 0) {
            int total = _countPlacedCamels();
            if (total == 1) {
              tutorialMessage =
                  "Awesome! 🌟 Rule 1: Only ONE camel allowed per color region!";
            } else if (total == 2) {
              tutorialMessage =
                  "Great! 🛑 Rule 2: Camels CANNOT touch each other.";
            } else if (total == 3) {
              tutorialMessage = "Perfect! Now the real game begins! 🚀";
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _goToNextLevelWithAdCheck();
              });
            }
          }
          _checkWinCondition();
        } else {
          if (currentLevelIndex == 0) {
            tutorialMessage =
                "Oops! ❌ That spot is wrong. Look for another one!";
          } else {
            lives--;
            _playLoseHeartSound();
            playerState[row][col] = 0;
            if (lives <= 0) {
              gameOver = true;
              _showDialog(
                "Game Over",
                "The camels died of thirst! 🐪💀",
                false,
              );
            }
          }
        }
      } else if (playerState[row][col] == 1) {
        playerState[row][col] = 0;
      }
    });
  }

  void _checkWinCondition() {
    if (_countPlacedCamels() == levels[currentLevelIndex].size) {
      gameOver = true;
      _playLevelUpSound();
      setState(() {
        diamonds += 7;
      });
      _saveGameData();
      _showDialog(
        "Level Cleared! 🎉",
        "You earned 7 💎!",
        currentLevelIndex < levels.length - 1,
      );
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          content: Text(message, style: const TextStyle(fontSize: 18)),
          actions: [
            if (lives <= 0) ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadLevel();
                },
                child: const Text("Restart", style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRewardedAd();
                },
                child: const Text(
                  "Watch Ad (+1 Life)",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              if (diamonds >= 20)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      diamonds -= 20;
                      lives = 1;
                      gameOver = false;
                    });
                    _saveGameData();
                  },
                  child: const Text(
                    "Pay 20💎 for Life",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
            ],
            if (hasNextLevel && lives > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _goToNextLevelWithAdCheck();
                },
                child: const Text("Next Level", style: TextStyle(fontSize: 16)),
              ),
            if (!hasNextLevel && lives > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    currentLevelIndex = 0;
                    _saveGameData();
                    _loadLevel();
                  });
                },
                child: const Text("Play Again", style: TextStyle(fontSize: 16)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRuleCard(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey.shade900,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    int n = levels[currentLevelIndex].size;

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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            Center(
              child: Text(
                '💎 $diamonds   ',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          backgroundColor: Colors.amber.withOpacity(0.9),
        ),
        body: Column(
          children: [
            if (currentLevelIndex == 0)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 3),
                ),
                child: Text(
                  tutorialMessage,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (currentLevelIndex != 0) ...[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                children: List.generate(
                  3,
                  (i) => Icon(
                    i < lives ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: n,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: n * n,
                      itemBuilder: (_, i) {
                        int r = i ~/ n;
                        int c = i % n;
                        return GestureDetector(
                          onTap: () => _handleTap(r, c),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.black54,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              color:
                                  regionColors[levels[currentLevelIndex]
                                          .regions[r][c]]
                                      .withOpacity(0.9),
                            ),
                            child: Center(
                              child: playerState[r][c] == 1
                                  ? Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Image.asset('assets/camel.png'),
                                    )
                                  : (playerState[r][c] == 2
                                        ? const Text(
                                            '❌',
                                            style: TextStyle(fontSize: 40),
                                          )
                                        : const Text('')),
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
                child: AdWidget(ad: _bannerAd!),
              )
            else
              const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
