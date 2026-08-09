import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/livekit_service.dart';

final liveKitProvider = ChangeNotifierProvider<LiveKitService>((ref) {
  return LiveKitService();
});
