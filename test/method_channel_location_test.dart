// File created by
// Lung Razvan <long1eu>
// on 23/03/2020

import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_platform_interface/location_platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'method_channel_location_test.mocks.dart';

// ignore: always_specify_types
@GenerateMocks([EventChannel])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannel methodChannel;
  MockEventChannel eventChannel;
  MethodChannelLocation location;

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    methodChannel = const MethodChannel('lyokone/location');
    eventChannel = MockEventChannel();
    location = MethodChannelLocation.private(methodChannel, eventChannel);

    methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'getLocation':
          return <String, dynamic>{
            'latitude': 48.8534,
            'longitude': 2.3488,
          };
        case 'changeSettings':
          return 1;
        case 'serviceEnabled':
          return 1;
        case 'requestService':
          return 1;
        default:
          return '';
      }
    });

    log.clear();
  });

  group('getLocation', () {
    test('getLocation should convert results correctly', () async {
      final LocationData receivedLocation = await location.getLocation();
      expect(receivedLocation.latitude, 48.8534);
      expect(receivedLocation.longitude, 2.3488);
    });
  });

  test('changeSettings passes parameters correctly', () async {
    await location.changeSettings();
    expect(log, <Matcher>[
      isMethodCall('changeSettings', arguments: <String, dynamic>{
        'accuracy': LocationAccuracy.high.index,
        'interval': 1000,
        'distanceFilter': 0
      }),
    ]);
  });

  group('Service Status', () {
    test('serviceEnabled should convert results correctly', () async {
      final bool result = await location.serviceEnabled();
      expect(result, true);
    });

    test('requestService should convert to string correctly', () async {
      final bool result = await location.requestService();
      expect(result, true);
    });
  });

  group('Permission Status', () {
    test('Should convert int to correct Permission Status', () async {
      methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
        return 0;
      });
      PermissionStatus receivedPermission = await location.hasPermission();
      expect(receivedPermission, PermissionStatus.denied);
      receivedPermission = await location.requestPermission();
      expect(receivedPermission, PermissionStatus.denied);

      methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
        return 1;
      });
      receivedPermission = await location.hasPermission();
      expect(receivedPermission, PermissionStatus.granted);
      receivedPermission = await location.requestPermission();
      expect(receivedPermission, PermissionStatus.granted);

      methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
        return 2;
      });
      receivedPermission = await location.hasPermission();
      expect(receivedPermission, PermissionStatus.deniedForever);
      receivedPermission = await location.requestPermission();
      expect(receivedPermission, PermissionStatus.deniedForever);

      methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
        return 3;
      });
      receivedPermission = await location.hasPermission();
      expect(receivedPermission, PermissionStatus.grantedLimited);
      receivedPermission = await location.requestPermission();
      expect(receivedPermission, PermissionStatus.grantedLimited);
    });

    test('Should throw if other message is sent', () async {
      methodChannel.setMockMethodCallHandler((MethodCall methodCall) async {
        return 12;
      });
      try {
        await location.hasPermission();
      } on PlatformException catch (err) {
        expect(err.code, 'UNKNOWN_NATIVE_MESSAGE');
      }
      try {
        await location.requestPermission();
      } on PlatformException catch (err) {
        expect(err.code, 'UNKNOWN_NATIVE_MESSAGE');
      }
    });
  });

  group('Location Updates', () {
    StreamController<Map<String, dynamic>> controller;

    setUp(() {
      controller = StreamController<Map<String, dynamic>>();
      when(eventChannel.receiveBroadcastStream())
          .thenAnswer((Invocation invoke) => controller.stream);
    });

    tearDown(() {
      controller.close();
    });

    test('call receiveBrodcastStream once', () {
      location.onLocationChanged;
      location.onLocationChanged;
      location.onLocationChanged;
      verify(eventChannel.receiveBroadcastStream()).called(1);
    });

    test('should receive values', () async {
      final StreamQueue<LocationData> queue =
          StreamQueue<LocationData>(location.onLocationChanged);

      controller.add(<String, dynamic>{
        'latitude': 48.8534,
        'longitude': 2.3488,
      });
      LocationData data = await queue.next;
      expect(data.latitude, 48.8534);
      expect(data.longitude, 2.3488);

      controller.add(<String, dynamic>{
        'latitude': 42.8534,
        'longitude': 23.3488,
      });
      data = await queue.next;
      expect(data.latitude, 42.8534);
      expect(data.longitude, 23.3488);
    });
  });
}
