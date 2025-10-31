import 'dart:convert';
import 'package:http/http.dart' as http;

class NightscoutService
{
  final String nightscoutUrl;

  NightscoutService({required this.nightscoutUrl});

  Future<dynamic> fetchNightscoutData(Uri url) async
  {
    return await http.get(url).then((response) {
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error fetching data from Nightscout');
      }
    });
  }
}