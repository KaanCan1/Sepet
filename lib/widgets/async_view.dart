import 'package:flutter/material.dart';

import '../data/api.dart';
import '../theme/tokens.dart';
import 'screen_frame.dart';

/// Bir Future'ın üç hâlini tek yerde toplar: yükleniyor, hata, veri.
///
/// Hata metni sunucudan geliyor ve kullanıcıya gösterilebilir olacak şekilde
/// yazılmış; burada yeniden yorumlamıyoruz.
/// Yeniden yükleme tetikleyicisi. GlobalKey üzerinden `currentState.reload()`
/// çağırmak sessizce başarısız olabiliyordu; bu yol açık ve test edilebilir.
class Reloader extends ChangeNotifier {
  void reload() => notifyListeners();
}

/// Veri değişti — fiş eklendi ya da bir eşleşme onaylandı. Bunu dinleyen her
/// ekran kendini tazeliyor; aksi hâlde sekme değiştirmeden eski sayı kalıyordu.
final dataChanged = Reloader();

class AsyncView<D> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.empty,
    this.isEmpty,
    this.reloadOn,
  });

  final Future<D> Function() load;

  /// Bu tetiklendiğinde [load] yeniden çalışır.
  final Listenable? reloadOn;
  final Widget Function(BuildContext context, D data) builder;

  /// Veri geldi ama gösterecek bir şey yok — örneğin hiç fiş eklenmemiş.
  final Widget? empty;
  final bool Function(D data)? isEmpty;

  @override
  State<AsyncView<D>> createState() => AsyncViewState<D>();
}

class AsyncViewState<D> extends State<AsyncView<D>> {
  late Future<D> _future = widget.load();

  @override
  void initState() {
    super.initState();
    widget.reloadOn?.addListener(reload);
  }

  @override
  void didUpdateWidget(AsyncView<D> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadOn != widget.reloadOn) {
      oldWidget.reloadOn?.removeListener(reload);
      widget.reloadOn?.addListener(reload);
    }
  }

  @override
  void dispose() {
    widget.reloadOn?.removeListener(reload);
    super.dispose();
  }

  /// Bir değişiklikten sonra yeniden yükler.
  void reload() {
    if (mounted) setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<D>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Centered(child: CupertinoLikeSpinner());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _Centered(
            child: _ErrorBody(
              message: error is ApiException
                  ? error.message
                  : 'Beklenmeyen bir hata oldu',
              onRetry: reload,
            ),
          );
        }
        final data = snapshot.data as D;
        if (widget.isEmpty?.call(data) == true && widget.empty != null) {
          return _Centered(child: widget.empty!);
        }
        return widget.builder(context, data);
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
    child: Center(child: child),
  );
}

class CupertinoLikeSpinner extends StatelessWidget {
  const CupertinoLikeSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2, color: C.muted),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.5, color: C.muted),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: 160,
        child: PrimaryButton(
          label: 'Yeniden dene',
          dark: false,
          onTap: onRetry,
        ),
      ),
    ],
  );
}

/// Boş durum: başlık + açıklama, aynı ölçülerde.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: T.display.copyWith(fontSize: 20),
      ),
      const SizedBox(height: 8),
      Text(
        body,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, height: 1.55, color: C.muted),
      ),
      if (action != null) ...[const SizedBox(height: 18), action!],
    ],
  );
}
