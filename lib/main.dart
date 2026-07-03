import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  // AD VARIABLES
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  RewardedAd? _rewardedAd;

  // NAYA: Full Screen (Interstitial) Ad Variable
  InterstitialAd? _interstitialAd;

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
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd(); // NAYA: Full screen ad load karna
  }

  // --- AD LOADING FUNCTIONS ---

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
      adUnitId:
          'ca-app-pub-3940256099942544/1033173712', // Test Interstitial ID
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

  // --- AD SHOWING FUNCTIONS ---

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

  // NAYA: Logic check karne ke liye ki Ad dikhana hai ya seedha next level
  void _goToNextLevelWithAdCheck() {
    // Har 3 level ke baad ad dikhao (currentLevelIndex 0 se start hota hai, toh 2, 5, 8 par aayega)
    if ((currentLevelIndex + 1) % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // Agle 3 level ke liye naya ad load karo
          _startNextLevel(); // Ad band hone ke baad next level par jao
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
          _startNextLevel(); // Error aane par seedha next level par jao
        },
      );
      _interstitialAd!.show();
    } else {
      _startNextLevel(); // Agar 3rd level nahi hai, toh seedha jao
    }
  }

  void _startNextLevel() {
    setState(() {
      currentLevelIndex++;
      _loadLevel();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose(); // NAYA: Clean up
    super.dispose();
  }

  // --- GAME LOGIC FUNCTIONS ---

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
        playerState[row][col] = 2;
      } else if (playerState[row][col] == 2) {
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
        playerState[row][col] = 0;
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
      setState(() {
        diamonds += 7;
      });

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
                  Navigator.of(context).pop(); // Dialog band karega
                  _goToNextLevelWithAdCheck(); // NAYA: Yahan Ad check hoga
                },
                child: const Text("Next Level ➡️"),
              ),
            if (!hasNextLevel && lives > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    currentLevelIndex = 0;
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

  // --- UI BUILDING ---

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

            const SizedBox(height: 16),

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
