import 'package:pushquest/game/storage.dart';

class MemoryGameStorage implements GameStorage {
  MemoryGameStorage([this.data = PersistedData.empty]);

  PersistedData data;

  @override
  Future<PersistedData> load() async => data;

  @override
  Future<void> save(PersistedData data) async {
    this.data = data;
  }
}
