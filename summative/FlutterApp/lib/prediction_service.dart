import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// The address of the API. It can be changed when running the app, for example
// flutter run --dart-define=API_URL=http://localhost:8000 to use an API on this computer.
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://linear-regression-model-h6i6.onrender.com',
);

// What the page shows after calling the API: either a prediction or an error message.
class PredictionResult {
  final int? spending;
  final int? timeMs;
  final String? error;

  PredictionResult({this.spending, this.timeMs, this.error});
}

// Sends the nine inputs to POST /predict. labels turns the API's field names into the names on the page.
Future<PredictionResult> predictSpending(Map<String, String> inputs, Map<String, String> labels) async {
  // numbers are sent as numbers, everything else as text. A word typed in a number
  // field is sent as it is, so the API can refuse it with its own message.
  final body = <String, dynamic>{};
  inputs.forEach((name, text) {
    final value = text.trim();
    body[name] = (name == 'age' || name == 'household_size') ? (int.tryParse(value) ?? value) : value;
  });

  try {
    final response = await http
        .post(
          Uri.parse('$apiUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90)); // the free server can need a minute to wake up

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PredictionResult(
        spending: data['predicted_expenditure_rwf'],
        timeMs: (data['time_ms'] as num).round(),
      );
    }
    if (response.statusCode == 422) {
      return PredictionResult(error: _readableError(jsonDecode(response.body), labels));
    }
    return PredictionResult(error: 'The server had a problem (code ${response.statusCode}). Please try again.');
  } on TimeoutException {
    return PredictionResult(error: 'The server took too long to answer. It may be waking up, so tap Predict again in a moment.');
  } catch (e) {
    return PredictionResult(error: 'Could not reach the server. Check the internet connection and try again.');
  }
}

// The API answers a wrong value with a list like [{loc: [body, age], msg: ...}].
// This turns it into lines such as "Age (years): Input should be less than or equal to 60".
String _readableError(dynamic data, Map<String, String> labels) {
  if (data is Map && data['detail'] is List) {
    final lines = (data['detail'] as List).map((problem) {
      final field = (problem['loc'] as List).last.toString();
      return '${labels[field] ?? field}: ${problem['msg']}';
    });
    return lines.join('\n');
  }
  return 'Some values are not valid. Please check the form.';
}
