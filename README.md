# Cameloku 🐫

A brain-teasing, grid-based logic puzzle built purely in Flutter. Think of it as Sudoku meets Star Battle, but with 100% more camels and absolutely zero diagonal touching. 

## 🧠 The Rules
The objective is simple, but the logic is ruthless. You must place exactly one camel (🐫) in specific cells based on the following constraints:
1. **1 per color:** Every colored region must contain exactly one camel.
2. **1 per row and column:** No two camels can share the same row or column.
3. **No touching:** Camels are highly anti-social. They cannot touch each other horizontally, vertically, or diagonally.

**Beware:** You only have 3 lives (❤️). Three wrong guesses, and the camels die of thirst!

## 🎮 Features
* **Multi-Level Progression:** Starts with 4x4 warmup grids and scales up to standard 5x5 (and beyond) boss levels.
* **Instant Validation:** Built-in backtracking algorithmic checks to validate user moves instantly.
* **Safe Marking:** Allows players to mark cells with an ❌ to eliminate possibilities without losing a life.
* **Responsive UI:** Fully fluid layout using `Expanded` and `GridView.builder` to prevent RenderFlex overflows on any screen size.

## 🛠️ Tech Stack
* **Framework:** Flutter (Dart)
* **Architecture:** Custom State Management with decoupled UI and purely mathematical grid evaluation.

## 🚀 Getting Started

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/codedbygunnaj/cameloku.git](https://github.com/codedbygunnaj/cameloku.git)
2. **Navigate to the directory:**
   Bash
3. **Install dependencies:**
   flutter pub get
4. **Run the app (VS Code / Emulator / Chrome):**
   flutter run

## 👨‍💻 Authors
- Daksh Chugh - @dakshchugh315
- Gunaj Chugh - @codedbygunnaj
