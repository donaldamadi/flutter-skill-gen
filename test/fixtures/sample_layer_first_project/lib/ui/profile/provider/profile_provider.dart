import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfileState {
  const ProfileState({this.name = ''});
  final String name;
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState());

  void setName(String value) => state = ProfileState(name: value);
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(),
);
