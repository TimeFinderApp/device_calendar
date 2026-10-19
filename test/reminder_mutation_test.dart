import 'dart:async';

import 'package:device_calendar/reminders.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.builttoroam.com/device_calendar');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    RemindersPlatform.instance = MethodChannelReminders();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'updateReminderFields' ? true : null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('registration owns its mask before session preparation completes',
      () async {
    final begin = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'beginReminderMutations') await begin.future;
      return null;
    });
    final session = ReminderMutationSession('account-generation');
    final fields = {'title'};
    final pending = session.register(
      attempt: 'command-attempt',
      entity: 'task-id',
      revision: 1,
      fields: fields,
    );
    fields.add('notes');
    begin.complete();
    final attempt = await pending;
    expect(attempt.fields, {'title'});
    expect((calls.last.arguments as Map)['fields'], ['title']);
    await attempt.finish();
    await session.end();
  });

  test('ACK, exact update and finish retain one immutable native attempt',
      () async {
    final session = ReminderMutationSession('account-generation');
    final attempt = await session.register(
      attempt: 'source-a',
      entity: 'task-id',
      revision: 7,
      fields: {'dueDate'},
    );
    await attempt.accept();
    final date = <String, Object?>{
      'year': 2026,
      'month': 10,
      'day': 19,
      'hasTime': false
    };
    final update = attempt.update(
      reminderId: 'native-id',
      listId: 'native-list',
      values: {'dueDate': date},
    );
    date['day'] = 20;
    expect(await update, isTrue);
    final applied = calls.last.arguments as Map;
    expect(applied['id'], 'native-id');
    expect(applied['list'], 'native-list');
    expect(applied['attempt'], 'source-a');
    expect(((applied['values'] as Map)['dueDate'] as Map)['day'], 19);
    await attempt.finish();
    await attempt.finish();
    expect(calls.where((call) => call.method == 'finishReminderMutation'),
        hasLength(1));
    await expectLater(attempt.accept(), throwsStateError);
    await session.end();
  });

  test('actual accepted mask can narrow reserved fields and never expand them',
      () async {
    final session = ReminderMutationSession('account-mask');
    final attempt = await session.register(
      attempt: 'partial',
      entity: 'task',
      revision: 1,
      fields: {'title', 'notes', r'$create'},
    );
    await expectLater(
        attempt.accept(fields: {'isCompleted'}), throwsStateError);
    await expectLater(attempt.accept(fields: {}), throwsStateError);
    final mask = {'notes', r'$create'};
    final pending = attempt.accept(fields: mask);
    mask.add('title');
    await pending;
    expect((calls.last.arguments as Map)['fields'],
        unorderedEquals(['notes', r'$create']));
    await attempt.finish();
    await session.end();
  });

  test('explicit create freezes its acknowledged baseline and stable marker',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'createReminderForTask' ? 'native-created' : null;
    });
    final session = ReminderMutationSession('account-create');
    final attempt = await session.register(
      attempt: 'create',
      entity: 'task',
      revision: 1,
      fields: {r'$create'},
    );
    await attempt.accept();
    final date = <String, Object?>{'day': 19};
    final pending = attempt.create(
      listId: 'native-list',
      marker: 'timefinder://reminder/stable-marker',
      baseline: {'title': 'Accepted title', 'dueDate': date},
    );
    date['day'] = 20;
    expect(await pending, 'native-created');
    final args = calls.last.arguments as Map;
    expect(args['marker'], 'timefinder://reminder/stable-marker');
    expect(((args['values'] as Map)['dueDate'] as Map)['day'], 19);
    await attempt.finish();
    await session.end();
  });

  test('an ended account refuses queued registration and existing attempt use',
      () async {
    final session = ReminderMutationSession('account-a');
    final attempt = await session.register(
      attempt: 'old',
      entity: 'task-id',
      revision: 1,
      fields: {'title'},
    );
    await session.end();
    await expectLater(attempt.accept(), throwsStateError);
    await expectLater(
        session.register(
          attempt: 'late',
          entity: 'task-id',
          revision: 2,
          fields: {'notes'},
        ),
        throwsStateError);
    await attempt.finish();
    expect(calls.last.method, 'finishReminderMutation');
    expect((calls.last.arguments as Map)['generation'], 'account-a');
  });
}
