import 'package:flutter_bloc/flutter_bloc.dart';

/// Empty scaffold for `GET /banners` (public). Wired when the home screen
/// gets its real content.
final class BannersCubit extends Cubit<List<Object?>> {
  BannersCubit() : super(const []);
}
