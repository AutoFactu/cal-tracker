import '../../../l10n/generated/app_localizations.dart';

String dashboardGreeting(DateTime dateTime, [AppLocalizations? l10n]) {
  final hour = dateTime.hour;
  if (hour >= 5 && hour < 12) {
    return l10n?.dashboardGreetingMorning ?? 'Good morning!';
  }
  if (hour >= 12 && hour < 18) {
    return l10n?.dashboardGreetingAfternoon ?? 'Good afternoon!';
  }
  return l10n?.dashboardGreetingNight ?? 'Good night!';
}

String dashboardDayMonthLabel(DateTime dateTime, [AppLocalizations? l10n]) {
  final months = [
    l10n?.monthJan ?? 'Jan',
    l10n?.monthFeb ?? 'Feb',
    l10n?.monthMar ?? 'Mar',
    l10n?.monthApr ?? 'Apr',
    l10n?.monthMay ?? 'May',
    l10n?.monthJun ?? 'Jun',
    l10n?.monthJul ?? 'Jul',
    l10n?.monthAug ?? 'Aug',
    l10n?.monthSep ?? 'Sep',
    l10n?.monthOct ?? 'Oct',
    l10n?.monthNov ?? 'Nov',
    l10n?.monthDec ?? 'Dec',
  ];
  return '${dateTime.day} ${months[dateTime.month - 1]}';
}
