import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return const Locale('en', 'US');
  }

  void setLocale(Locale locale) {
    state = locale;
  }

  void toggleLanguage() {
    if (state.languageCode == 'en') {
      state = const Locale('fil', 'PH');
    } else {
      state = const Locale('en', 'US');
    }
  }
}

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'dashboard': 'Dashboard',
      'home': 'Home',
      'courses': 'Courses',
      'academy': 'Academy',
      'messages': 'Messages',
      'announce': 'Announce',
      'reports': 'Reports',
      'admin': 'Admin',
      'settings': 'Settings',
      'personal_profile': 'Personal Profile',
      'system_settings': 'System Settings',
      'interface_appearance': 'Interface Appearance',
      'appearance': 'Appearance',
      'push_notifications': 'Push Notifications',
      'language': 'Language',
      'platform_diagnostics': 'Platform Diagnostics',
      'version': 'Version',
      'environment': 'Environment',
      'maintenance_session': 'Maintenance & Session',
      'reset_preferences': 'Reset Preferences',
      'sign_out': 'Sign Out',
      'save_changes': 'Save Changes',
      'welcome_back': 'Welcome back',
      'profile_information': 'Profile Information',
      'instructor': 'Instructor',
      'student': 'Student',
      'created': 'Created',
      'students': 'Students',
      'progress': 'Progress',
      'enrolled': 'Enrolled',
      'finished': 'Finished',
      'invested': 'Invested',
      'create_course': 'Create Course',
      'managed_courses': 'Your Managed Courses',
      'see_all': 'See All',
      'recent_announcements': 'Recent Announcements',
      'no_announcements': 'No recent announcements.',
      'active_enrollments': 'Active Enrollments',
      'continue_learning': 'Continue Learning',
    },
    'fil': {
      'dashboard': 'Dashbord',
      'home': 'Home',
      'courses': 'Mga Kurso',
      'academy': 'Akademya',
      'messages': 'Mga Mensahe',
      'announce': 'Anunsyo',
      'reports': 'Mga Ulat',
      'admin': 'Admin',
      'settings': 'Mga Setting',
      'personal_profile': 'Personal na Profile',
      'system_settings': 'Mga Setting ng System',
      'interface_appearance': 'Itsura ng Interface',
      'appearance': 'Tema',
      'push_notifications': 'Mga Abiso',
      'language': 'Wika',
      'platform_diagnostics': 'Diagnostics ng Platform',
      'version': 'Bersyon',
      'environment': 'Kapaligiran',
      'maintenance_session': 'Maintenance at Session',
      'reset_preferences': 'I-reset ang mga Kagustuhan',
      'sign_out': 'Mag-sign Out',
      'save_changes': 'I-save ang mga Pagbabago',
      'welcome_back': 'Maligayang pagbabalik',
      'profile_information': 'Impormasyon ng Profile',
      'instructor': 'Instruktor',
      'student': 'Estudyante',
      'created': 'Nagawa',
      'students': 'Mga Estudyante',
      'progress': 'Pag-unlad',
      'enrolled': 'Naka-enroll',
      'finished': 'Tapos na',
      'invested': 'Na-invest',
      'create_course': 'Gumawa ng Kurso',
      'managed_courses': 'Ang Iyong mga Kurso',
      'see_all': 'Tingnan Lahat',
      'recent_announcements': 'Mga Bagong Anunsyo',
      'no_announcements': 'Walang bagong anunsyo.',
      'active_enrollments': 'Mga Aktibong Pag-aaral',
      'continue_learning': 'Ituloy ang Pag-aaral',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fil'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
