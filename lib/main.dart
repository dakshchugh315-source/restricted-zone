import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// Kis cheez ke liye ad dekh raha hai user, usko track karne ke liye
enum RewardAction { oneLife, threeLives, threeHints }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const CamelokuApp()); // Yahan naam badla
}

class CamelokuApp extends StatelessWidget {
  // Yahan naam badla
  const CamelokuApp({super.key});

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
  int hints = 3; // NAYA: Default 3 hints
  int multiAdProgress = 0; // NAYA: 2 ad wale feature ke liye counter

  String tutorialMessage =
      "Welcome! 🐫 Tap any empty box to place your first camel.";

  List<GameLevel> levels = [];
  late List<List<int>> playerState;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

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
      hints = prefs.getInt('saved_hints') ?? 3; // Hint save/load honge
    });
  }

  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', currentLevelIndex);
    await prefs.setInt('saved_diamonds', diamonds);
    await prefs.setInt('saved_hints', hints);
  }

  // YAHAN APNE ASLI IDs DAAL LENA JAB PLAY STORE PE JAYE
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
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
        },
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
          _interstitialAd = null;
        },
      ),
    );
  }

  // --- NAYA LOGIC: HINTS AUR MULTI-REWARD ADS KA ---
  void _giveReward(RewardAction action) {
    setState(() {
      if (action == RewardAction.oneLife) {
        lives = 1;
        gameOver = false;
        multiAdProgress = 0;
      } else if (action == RewardAction.threeLives) {
        multiAdProgress++;
        if (multiAdProgress >= 2) {
          lives += 3;
          gameOver = false;
          multiAdProgress = 0; // Dono ads dekh liye
        } else {
          // Pehla ad dekh liya, ab dusre ka prompt do
          Future.delayed(
            const Duration(milliseconds: 500),
            () => _showGameOverDialog(),
          );
        }
      } else if (action == RewardAction.threeHints) {
        hints += 3;
        _saveGameData();
      }
    });
  }

  void _triggerRewardedAd(RewardAction action) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          _giveReward(action);
        },
      );
      _rewardedAd = null;
      _loadRewardedAd();
    } else {
      // Fallback: Agar ad Google ki taraf se load nahi hua (Limited serving ki wajah se),
      // toh player ko atakne na dein, direct reward de dein testing ke liye.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ad server busy. Free reward given! 🎁")),
      );
      _giveReward(action);
      _loadRewardedAd();
    }
  }

  void _useHint() {
    if (gameOver || isLoading) return;

    if (hints > 0) {
      int n = levels[currentLevelIndex].size;
      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          if (levels[currentLevelIndex].solution[r][c] &&
              playerState[r][c] != 1) {
            setState(() {
              playerState[r][c] = 1; // Camel place kar diya
              hints--;
            });
            _playCamelSound();
            _saveGameData();
            _checkWinCondition();
            return;
          }
        }
      }
    } else {
      // Hint khatam ho gaye, Ad dikhao
      _showNeedHintsDialog();
    }
  }

  void _showNeedHintsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Out of Hints! 💡",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Watch a quick ad to get 3 more hints?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerRewardedAd(RewardAction.threeHints);
            },
            child: const Text("Watch Ad (+3 Hints)"),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------------

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
    final String jsonString = await rootBundle.loadString('assets/levels.json');
    final List<dynamic> jsonResponse = json.decode(jsonString);
    setState(() {
      levels = jsonResponse
          .map(
            (level) => GameLevel(
              level['size'] as int,
              (level['regions'] as List)
                  .map((row) => List<int>.from(row))
                  .toList(),
              (level['solution'] as List)
                  .map((row) => List<bool>.from(row))
                  .toList(),
            ),
          )
          .toList();
      isLoading = false;
      _loadLevel();
    });
  }

  void _loadLevel() {
    if (levels.isEmpty) return;
    int n = levels[currentLevelIndex].size;
    setState(() {
      playerState = List.generate(n, (_) => List.filled(n, 0));
      lives = 3;
      gameOver = false;
      multiAdProgress = 0; // Naye level par reset
      if (currentLevelIndex == 0)
        tutorialMessage =
            "Welcome! 🐫 Tap any empty box to place your first camel.";
    });
  }

  int _countPlacedCamels() {
    int count = 0;
    for (int r = 0; r < playerState.length; r++) {
      for (int c = 0; c < playerState[r].length; c++) {
        if (playerState[r][c] == 1) count++;
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
            if (total == 1)
              tutorialMessage =
                  "Awesome! 🌟 Rule 1: Only ONE camel allowed per color region!";
            else if (total == 2)
              tutorialMessage =
                  "Great! 🛑 Rule 2: Camels CANNOT touch each other.";
            else if (total == 3) {
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
              _showGameOverDialog();
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

      // Level win dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text(
            "Level Cleared! 🎉",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          content: const Text(
            "You earned 7 💎!",
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goToNextLevelWithAdCheck();
              },
              child: const Text("Next Level", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Game Over",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          content: Text(
            multiAdProgress == 1
                ? "1 Ad watched! Watch one more to get 3 full lives. 🐪"
                : "The camels died of thirst! 🐪💀",
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadLevel();
              },
              child: const Text("Restart", style: TextStyle(fontSize: 16)),
            ),

            // Ad Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (multiAdProgress == 0)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _triggerRewardedAd(RewardAction.oneLife);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade200,
                    ),
                    child: const Text(
                      "Watch 1 Ad (+1 Life)",
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _triggerRewardedAd(RewardAction.threeLives);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade300,
                  ),
                  child: Text(
                    multiAdProgress == 1
                        ? "Watch 2nd Ad (+3 Lives) ▶️"
                        : "Watch 2 Ads (+3 Lives) 🎁",
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 8),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade200,
                    ),
                    child: const Text(
                      "Pay 20💎 for Life",
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
              ],
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
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            // NAYA: Hint Button AppBar mein
            TextButton.icon(
              onPressed: _useHint,
              icon: const Icon(Icons.lightbulb, color: Colors.white, size: 28),
              label: Text(
                '$hints',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
