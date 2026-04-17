class AuthApi {
  Future<Map<String, dynamic>> login(String email, String password) async {
    return {'token': 'mock_token', 'userId': '123'};
  }
}
