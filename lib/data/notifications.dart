import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Aylık kart hatırlatıcısı.
///
/// **Yerel bildirim, uzaktan itme değil.** Sunucu kimin ne zaman
/// bildirileceğini bilmiyor; hatırlatma cihazda planlanıyor. Üç sebep:
/// APNs sertifikası Apple Developer üyeliğine bağlı (bkz. yol haritası),
/// sunucuda cihaz jetonu tutmak fişten fazla veri saklamak olurdu, ve
/// tarih zaten sabit — kişiye göre değişen bir şey yok.
///
/// Testlerin platform kanalına düşmemesi için arayüz; [AuthStore] ile aynı
/// gerekçe.
abstract class MonthlyReminder {
  /// Kullanıcı açık dedi mi. Yalnızca tercih — işletim sistemi izni ayrı,
  /// [enable] onu ayrıca soruyor.
  Future<bool> isOn();

  /// İzni ister ve planlar. İzin verilmezse tercih açık yazılmıyor.
  Future<ReminderResult> enable();

  Future<void> disable();

  /// Açılışta çağrılıyor: tercih açıksa planı tazeler, izin geri alınmışsa
  /// tercihi kapatır. Plan tekrar yazılabilir — aynı kimlikle yazıldığı için
  /// birikmiyor.
  Future<void> restore();

  /// Bildirime dokunulup dokunulmadığı. Bir kez okunuyor, sonra sıfırlanıyor:
  /// aynı dokunuş iki ekran açmasın.
  bool takePendingCard();

  /// Uygulama açıkken gelen dokunuşlar.
  Stream<void> get cardTaps;
}

enum ReminderResult {
  /// Planlandı.
  on,

  /// Kullanıcı izni reddetti. Ayarlar'a yönlendirmek çağıranın işi — bu
  /// noktadan sonra uygulama içinden yeniden sorulamıyor.
  denied,
}

/// Bildirimin metninde **sayı yok.** Kilit ekranı, telefonun sahibi olmayan
/// birinin de gördüğü yer; enflasyon oranı orada durmasın. Sayıyı görmek için
/// uygulamayı açmak gerekiyor.
const _title = 'Aylık kartın hazır';
const _body = 'Geçen ayın sepeti ve resmî ölçüm yan yana.';

/// Ayın kaçında ve saat kaçta. TÜİK TÜFE'yi ayın 3'ünde 10.00'da açıklıyor;
/// yarım saat pay bırakıldı ki bildirim gelen veriyi göstersin, boş kartı
/// değil.
const _day = 3;
const _hour = 10;
const _minute = 30;

class LocalMonthlyReminder implements MonthlyReminder {
  LocalMonthlyReminder([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<void>.broadcast();

  static const _prefKey = 'sepet_monthly_reminder';
  static const _id = 1;

  bool _pending = false;
  bool _ready = false;

  @override
  Stream<void> get cardTaps => _taps.stream;

  @override
  bool takePendingCard() {
    final v = _pending;
    _pending = false;
    return v;
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;

    tzdata.initializeTimeZones();
    // Uygulama tek yerelli (tr_TR) ve karşılaştırdığı seriler TÜİK'in;
    // saat dilimini cihazdan okumak için ayrı bir paket eklemek yerine
    // sabitlendi. Türkiye 2016'dan beri yaz saati uygulamıyor, yani bu
    // sabit yılın her günü UTC+3.
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // İzin açılışta değil, kullanıcı anahtarı çevirince isteniyor.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) {
        _pending = true;
        _taps.add(null);
      },
    );

    // Uygulama kapalıyken dokunulduysa açılış sebebi bu.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _pending = true;
  }

  @override
  Future<bool> isOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  @override
  Future<ReminderResult> enable() async {
    await _init();
    if (!await _requestPermission()) return ReminderResult.denied;

    await _schedule();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    return ReminderResult.on;
  }

  @override
  Future<void> disable() async {
    await _init();
    await _plugin.cancel(id: _id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
  }

  @override
  Future<void> restore() async {
    await _init();
    if (!await isOn()) return;

    // İzin Ayarlar'dan geri alınmış olabilir. O durumda anahtarın açık
    // durması yalan olurdu — tercih de kapanıyor.
    if (!await _hasPermission()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, false);
      return;
    }
    await _schedule();
  }

  Future<bool> _requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> _hasPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) return await ios.checkPermissions().then(_granted);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? false;
  }

  static bool _granted(NotificationsEnabledOptions? o) => o?.isEnabled ?? false;

  Future<void> _schedule() async {
    await _plugin.zonedSchedule(
      id: _id,
      title: _title,
      body: _body,
      scheduledDate: nextOccurrence(tz.TZDateTime.now(tz.local)),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'monthly_card',
          'Aylık kart',
          channelDescription: "Her ayın 3'ünde aylık kart hatırlatması",
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Ayda bir, aynı gün ve saatte. Tek tek ay planlamak yerine bu:
      // plan bir kez yazılıyor, uygulama hiç açılmasa da sürüyor.
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// [now]'dan sonraki ilk "ayın 3'ü, 10.30".
  ///
  /// Ayrı ve saf: takvim aritmetiği bildirim eklentisi olmadan test
  /// edilebilsin diye.
  @visibleForTesting
  static tz.TZDateTime nextOccurrence(tz.TZDateTime now) {
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      _day,
      _hour,
      _minute,
    );
    // Ayın 3'ü geçtiyse gelecek ay. DateTime ay taşmasını kendisi çeviriyor
    // (13. ay → gelecek yılın ocağı), o yüzden ayrıca yıl hesabı yok.
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        _day,
        _hour,
        _minute,
      );
    }
    return next;
  }
}

/// Yalnızca testler için — hiçbir şey planlamaz, tercihi bellekte tutar.
class MemoryMonthlyReminder implements MonthlyReminder {
  MemoryMonthlyReminder({this.permission = true, this.on = false});

  /// Tercih açık mı. Test doğrudan okuyabilsin diye alan.
  bool on;

  /// İşletim sistemi izin verecek mi. `false` ise [enable] reddediyor.
  bool permission;

  final _taps = StreamController<void>.broadcast();

  @override
  Stream<void> get cardTaps => _taps.stream;

  @override
  bool takePendingCard() => false;

  @override
  Future<bool> isOn() async => on;

  @override
  Future<ReminderResult> enable() async {
    if (!permission) return ReminderResult.denied;
    on = true;
    return ReminderResult.on;
  }

  @override
  Future<void> disable() async => on = false;

  @override
  Future<void> restore() async {}
}
