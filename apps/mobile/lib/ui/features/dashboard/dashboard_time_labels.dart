String dashboardGreeting(DateTime dateTime) {
  final hour = dateTime.hour;
  if (hour >= 5 && hour < 12) {
    return 'Good morning!';
  }
  if (hour >= 12 && hour < 18) {
    return 'Good afternoon!';
  }
  return 'Good night!';
}

String dashboardDayMonthLabel(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${dateTime.day} ${months[dateTime.month - 1]}';
}
