import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/router/app_router.dart';

void main() {
  bootstrap(() async {
    final router = AppRouter();
    return MyApp(router: router);
  });
}
