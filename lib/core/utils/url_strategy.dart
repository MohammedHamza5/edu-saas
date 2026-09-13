import 'package:flutter_web_plugins/url_strategy.dart';

/// Configures clean HTML5 History URL paths (removes '#' fragment from URLs)
void configureUrlStrategy() {
  usePathUrlStrategy();
}

