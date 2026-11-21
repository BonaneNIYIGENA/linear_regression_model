import 'package:flutter/material.dart';

import 'prediction_service.dart';

void main() => runApp(const SchoolSpendingApp());

const indigo = Color(0xFF3F51B5);
final faintGrey = Colors.black.withValues(alpha: 0.12);

OutlineInputBorder inputBorder(BorderSide side) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: side);

// every input, typed or chosen from a list: white with a faint border, indigo only when selected
final fieldStyle = InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  border: inputBorder(BorderSide(color: faintGrey)),
  enabledBorder: inputBorder(BorderSide(color: faintGrey)),   // the resting border, Flutter would use a dark default
  focusedBorder: inputBorder(const BorderSide(color: indigo, width: 1.5)),
);

// 340217 becomes 340,217
String withCommas(int number) =>
    number.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');

class SchoolSpendingApp extends StatelessWidget {
  const SchoolSpendingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School spending prediction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
        inputDecorationTheme: fieldStyle,
        // the list of options opens as a rounded white card
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: fieldStyle,   // the dropdown does not use the app-wide style by itself
          menuStyle: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(Colors.white),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

// One input of the model. name is what the API expects. A field without options is typed as a number.
class InputField {
  final String name;
  final String label;
  final List<String>? options;

  const InputField(this.name, this.label, [this.options]);
}

const fields = [
  InputField('age', 'Age (years)'),
  InputField('sex', 'Sex', ['Male', 'Female']),
  InputField('province', 'Province', ['Kigali', 'Southern', 'Western', 'Northern', 'Eastern']),
  InputField('area', 'Area', ['Urban', 'Rural']),
  InputField('school_level', 'School level',
      ['ECD', 'Nursery', 'Primary', 'Lower secondary', 'Upper secondary', 'Tertiary']),
  InputField('school_type', 'School type', ['Public', 'Private', 'Government subsidized']),
  InputField('boarding', 'Boarding', ['Yes', 'No', 'Not applicable']),
  InputField('household_size', 'Household size (people)'),
  InputField('payer', 'Who pays for school',
      ['Father', 'Mother', 'Both parents', 'Other household member', 'Other relative', 'Self', 'Other']),
];

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final controllers = {for (final field in fields) field.name: TextEditingController()};
  final scrollController = ScrollController();
  bool loading = false;
  PredictionResult? result;

  Future<void> predict() async {
    if (loading) return;
    FocusScope.of(context).unfocus();

    // a missing value is caught here, a wrong value is caught by the API
    final missing = fields.where((f) => controllers[f.name]!.text.trim().isEmpty);
    if (missing.isNotEmpty) {
      showResult(PredictionResult(error: 'Please fill in every field.\nMissing: ${missing.map((f) => f.label).join(', ')}'));
      return;
    }

    setState(() {
      loading = true;
      result = null;
    });
    showResult(await predictSpending(
      {for (final f in fields) f.name: controllers[f.name]!.text},
      {for (final f in fields) f.name: f.label},
    ));
  }

  void showResult(PredictionResult answer) {
    setState(() {
      loading = false;
      result = answer;
    });
    // scroll down so the answer is in view, once the box has finished growing
    Future.delayed(const Duration(milliseconds: 350), () {
      scrollController.animateTo(scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Widget buildInput(InputField field) {
    if (field.options == null) {
      return TextField(
        controller: controllers[field.name],
        // decimals and minus signs can be typed on purpose, so a wrong value is refused by the API and shown as an error
        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
        decoration: InputDecoration(labelText: field.label),
      );
    }
    // a box with a list to choose from, so a wrong word cannot be typed
    return DropdownMenu<String>(
      controller: controllers[field.name],
      label: Text(field.label),
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      dropdownMenuEntries: [for (final option in field.options!) DropdownMenuEntry(value: option, label: option)],
    );
  }

  // the coloured box of the display area. The key tells AnimatedSwitcher when the content is new.
  Widget box(Object key, Color color, Widget child) {
    return Container(
      key: ValueKey(key),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: faintGrey)),
      child: child,
    );
  }

  // The display area: a hint, the loading message, the prediction or the error.
  // It fades from one to the next and grows or shrinks smoothly.
  Widget buildResultArea() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: buildResultBox()),
    );
  }

  Widget buildResultBox() {
    final colors = Theme.of(context).colorScheme;

    if (loading) {
      return box('loading', Colors.white,
          const Text('Asking the server... the first request can take up to a minute.'));
    }
    if (result == null) {
      return box('hint', Colors.white, const Text('The estimated yearly school spending will appear here.'));
    }
    if (result!.error != null) {
      return box(
        result!,
        colors.errorContainer,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Could not predict',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onErrorContainer)),
          const SizedBox(height: 6),
          Text(result!.error!, style: TextStyle(fontSize: 16, color: colors.onErrorContainer)),
        ]),
      );
    }
    return box(
      result!,
      colors.primaryContainer,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Estimated yearly school spending', style: TextStyle(color: colors.onPrimaryContainer)),
        const SizedBox(height: 6),
        // the amount counts up from 0 to the prediction
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: result!.spending!),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Text('${withCommas(value)} RWF',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: colors.onPrimaryContainer)),
        ),
        const SizedBox(height: 6),
        Text('Predicted in ${result!.timeMs} ms', style: TextStyle(color: colors.onPrimaryContainer)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School spending prediction')),
      body: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Describe the student to estimate how much school costs for a year.'),
          const SizedBox(height: 16),
          for (final field in fields) ...[buildInput(field), const SizedBox(height: 14)],
          const SizedBox(height: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: predict,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Predicting...', style: TextStyle(fontSize: 18)),
                    ])
                  : const Text('Predict', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 20),
          buildResultArea(),
        ],
      ),
    );
  }
}
