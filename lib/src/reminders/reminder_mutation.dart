import 'dart:convert';

import 'reminders_platform_interface.dart';

/// A projection of one app account lifetime onto the native EventKit owner.
class ReminderMutationSession {
  ReminderMutationSession(this.generation)
      : _platform = RemindersPlatform.instance {
    _ready = _platform.invokeReminderMutation(
      'beginReminderMutations',
      {'generation': generation},
    );
  }

  static Future<String> storeIdentity() async =>
      await RemindersPlatform.instance.invokeReminderMutation(
        'getReminderStoreIdentity',
        const {},
      ) as String;

  final String generation;
  final RemindersPlatform _platform;
  late final Future<Object?> _ready;
  bool _ended = false;

  Future<ReminderMutationAttempt> register({
    required String attempt,
    required String entity,
    required int revision,
    required Set<String> fields,
  }) async {
    final owned = Set<String>.unmodifiable(fields);
    await _ready;
    _requireActive();
    await _platform.invokeReminderMutation('registerReminderMutation', {
      'generation': generation,
      'attempt': attempt,
      'entity': entity,
      'revision': revision,
      'fields': owned.toList(),
    });
    return ReminderMutationAttempt._(this, attempt, owned);
  }

  Future<void> end() async {
    _ended = true;
    await _ready;
    await _platform.invokeReminderMutation(
      'endReminderMutations',
      {'generation': generation},
    );
  }

  void _requireActive() {
    if (_ended) throw StateError('Reminder account lifetime has ended.');
  }
}

/// Only the actual acknowledged source receipt may accept a registered attempt.
class ReminderMutationAttempt {
  ReminderMutationAttempt._(this._session, this.id, this.fields);
  final ReminderMutationSession _session;
  final String id;
  final Set<String> fields;
  bool _finished = false;

  Future<Object?> _invoke(String operation,
      [Map<String, Object?> extra = const {}]) {
    _session._requireActive();
    if (_finished) throw StateError('Reminder attempt has finished.');
    return _session._platform.invokeReminderMutation(operation, {
      'generation': _session.generation,
      'attempt': id,
      ...extra,
    });
  }

  Future<void> accept({Set<String>? fields}) async {
    final mask = fields == null ? null : Set<String>.unmodifiable(fields);
    if (mask != null && (mask.isEmpty || !this.fields.containsAll(mask))) {
      throw StateError('Accepted fields exceed the reserved native intent.');
    }
    await _invoke('acceptReminderMutation', {
      if (mask != null) 'fields': mask.toList(),
    });
  }

  Future<bool> update({
    required String reminderId,
    required String listId,
    required Map<String, Object?> values,
    String? lifetime,
  }) async {
    // Freeze nested date components before any method-channel suspension.
    final ownedValues = jsonDecode(jsonEncode(values)) as Map<String, dynamic>;
    return await _invoke('updateReminderFields', {
          'id': reminderId,
          'list': listId,
          'values': ownedValues,
          if (lifetime != null) 'lifetime': lifetime,
        }) ==
        true;
  }

  Future<bool> delete({
    required String reminderId,
    required String listId,
    String? lifetime,
  }) async =>
      await _invoke('deleteReminderForTask', {
        'id': reminderId,
        'list': listId,
        if (lifetime != null) 'lifetime': lifetime,
      }) ==
      true;

  Future<String?> create({
    required String listId,
    required String marker,
    required Map<String, Object?> baseline,
    Map<String, Object?> adoptValues = const {},
    String? existingId,
    String? lifetime,
  }) async {
    final frozen = jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
    return await _invoke('createReminderForTask', {
      'list': listId,
      'marker': marker,
      'values': frozen,
      'adoptValues': jsonDecode(jsonEncode(adoptValues)),
      if (existingId != null) 'existingId': existingId,
      if (lifetime != null) 'lifetime': lifetime,
    }) as String?;
  }

  Future<void> finish() async {
    if (_finished) return;
    _finished = true;
    await _session._platform.invokeReminderMutation('finishReminderMutation', {
      'generation': _session.generation,
      'attempt': id,
    });
  }
}
