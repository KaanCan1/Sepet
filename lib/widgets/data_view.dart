import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/data_cubit.dart';
import '../theme/tokens.dart';
import 'screen_frame.dart';

/// Bir [DataCubit]'in üç hâlini tek yerde toplar: yükleniyor, hata, veri.
///
/// Hata metni sunucudan geliyor ve kullanıcıya gösterilebilir olacak şekilde
/// yazılmış; burada yeniden yorumlanmıyor.
///
/// [B] cubit türü, [D] taşıdığı veri. İkisi de yazılmak zorunda çünkü Dart
/// tür değişkenini tür değişkeninden çıkaramıyor. Harfler bilerek T değil:
/// bu projede T, tipografi belirteçlerinin sınıf adı.
class DataView<B extends DataCubit<D>, D> extends StatelessWidget {
  const DataView({super.key, required this.builder, this.empty, this.isEmpty});

  final Widget Function(BuildContext context, D data) builder;

  /// Veri geldi ama gösterecek bir şey yok — örneğin hiç fiş eklenmemiş.
  final Widget? empty;
  final bool Function(D data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<B, DataState<D>>(
      builder: (context, state) => switch (state) {
        DataLoading<D>() => const _Centered(child: CupertinoLikeSpinner()),
        DataFailure<D>(:final message) => _Centered(
          child: _ErrorBody(
            message: message,
            onRetry: () => context.read<B>().load(),
          ),
        ),
        DataReady<D>(:final value) =>
          isEmpty?.call(value) == true && empty != null
              ? _Centered(child: empty!)
              : builder(context, value),
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
