import 'url_strategy_io.dart' if (dart.library.html) 'url_strategy_html.dart' as impl;

void configureAppUrlStrategy() => impl.configureAppUrlStrategy();
